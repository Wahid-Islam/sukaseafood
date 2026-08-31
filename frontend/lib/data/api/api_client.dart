import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../../core/constants/app_constants.dart';
import '../models/identify_result.dart';
import '../models/price_forecast.dart';

/// A failed API call, carrying the backend's own error code where it sent one.
///
/// The code matters: `MODEL_UNAVAILABLE` and `FORECAST_UNAVAILABLE` are normal
/// product states with their own copy, not crashes. Collapsing them into a
/// generic "something went wrong" would lose the only information the screen
/// needs to explain itself.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  /// The CV model is not loaded or its class map disagrees with the database.
  bool get isModelUnavailable => code == 'MODEL_UNAVAILABLE';

  /// The species exists but the forecasting engine does not cover it. Most
  /// species are in this state — only the fish with enough recent price history
  /// pass the eligibility rules.
  bool get isForecastUnavailable => code == 'FORECAST_UNAVAILABLE';

  /// Nothing answered at all, so the API base URL or the tunnel is wrong.
  bool get isUnreachable => statusCode == null;

  @override
  String toString() => message;
}

/// Read-only client for the SukaSeafood FastAPI backend.
///
/// Auth lives in [AuthService]; this covers the seafood domain endpoints.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 45);

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final Uri base = Uri.parse('${AppConstants.apiBaseUrl}$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: <String, String>{
      ...base.queryParameters,
      ...query,
    });
  }

  /// Identify a fish from one photograph.
  ///
  /// The image is uploaded, inferred against and dropped; the backend stores no
  /// user photographs and does not reuse them as training data.
  Future<IdentifyResult> identify(File image) async {
    final http.MultipartRequest request =
        http.MultipartRequest('POST', _uri('/identify'));

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        image.path,
        contentType: _mediaTypeFor(image.path),
      ),
    );

    try {
      final http.StreamedResponse streamed =
          await _client.send(request).timeout(_timeout);
      final http.Response response =
          await http.Response.fromStream(streamed);
      return IdentifyResult.fromJson(_decode(response));
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  /// The modelled four-week price outlook for one canonical species.
  ///
  /// [fishId] accepts either the `SF001` code or the canonical UUID, which is
  /// what lets a scan result flow straight into this call.
  Future<PriceForecast> forecast(String fishId, {String? locationId}) async {
    try {
      final http.Response response = await _client
          .get(
            _uri(
              '/seafood/$fishId/forecast',
              locationId == null ? null : <String, String>{'location_id': locationId},
            ),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(_timeout);
      return PriceForecast.fromJson(_decode(response));
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  void close() => _client.close();

  // --- internals ------------------------------------------------------------

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFrom(response);
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Unexpected response shape from the API.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  /// Unpack the backend's error envelope.
  ///
  /// FastAPI wraps whatever is passed as `detail`, and this backend puts a
  /// `{error: {code, message}}` object there, so the code sits two levels down.
  ApiException _errorFrom(http.Response response) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final Object? detail = decoded['detail'];
        if (detail is Map<String, dynamic>) {
          final Object? error = detail['error'];
          if (error is Map<String, dynamic>) {
            return ApiException(
              error['message'] as String? ?? 'Request failed.',
              code: error['code'] as String?,
              statusCode: response.statusCode,
            );
          }
        }
        if (detail is String && detail.isNotEmpty) {
          return ApiException(detail, statusCode: response.statusCode);
        }
      }
    } catch (_) {
      // Fall through to the status-only message below.
    }
    return ApiException(
      'Request failed (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  String _unreachableMessage(Object error) {
    if (error is SocketException || error is HttpException) {
      return 'Cannot reach the SukaSeafood API. Is the backend running?';
    }
    return 'Cannot reach the SukaSeafood API ($error).';
  }

  /// The backend accepts JPEG, PNG and WebP only, and rejects anything else
  /// with 415 before the model is touched. Without an explicit part header the
  /// upload would go out as application/octet-stream and always be rejected.
  static MediaType _mediaTypeFor(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    // image_picker re-encodes to JPEG for camera captures on both platforms,
    // and gallery picks arrive with their original extension.
    return MediaType('image', 'jpeg');
  }
}
