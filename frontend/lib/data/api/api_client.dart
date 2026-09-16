import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../../core/constants/app_constants.dart';
import '../models/cooking_intent.dart';
import '../models/identify_result.dart';
import '../models/price_forecast.dart';
import '../models/seafood.dart';

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

  /// The server has no OpenAI key, so recipe generation is switched off.
  bool get isRecipeUnavailable => code == 'RECIPE_UNAVAILABLE';

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
    return base.replace(
      queryParameters: <String, String>{...base.queryParameters, ...query},
    );
  }

  /// Identify a fish from one photograph.
  ///
  /// The image is uploaded, inferred against and dropped; the backend stores no
  /// user photographs and does not reuse them as training data. Bytes rather
  /// than a filesystem path so the same call works on Android and on web.
  Future<IdentifyResult> identify({
    required List<int> bytes,
    required String filename,
  }) async {
    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      _uri('/identify'),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename.isEmpty ? 'capture.jpg' : filename,
        contentType: _mediaTypeFor(filename),
      ),
    );

    try {
      final http.StreamedResponse streamed = await _client
          .send(request)
          .timeout(_timeout);
      final http.Response response = await http.Response.fromStream(streamed);
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
              locationId == null
                  ? null
                  : <String, String>{'location_id': locationId},
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

  /// Compact catalogue cards (`GET /seafood` and `GET /search`).
  Future<List<SeafoodSummary>> listSeafood() async {
    try {
      final http.Response response = await _client
          .get(
            _uri('/seafood'),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(_timeout);
      return _decodeList(
        response,
      ).whereType<Map<String, dynamic>>().map(SeafoodSummary.fromJson).toList();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  Future<List<SeafoodSummary>> search(String query) async {
    try {
      final http.Response response = await _client
          .get(
            _uri('/search', <String, String>{'q': query}),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(_timeout);
      final Map<String, dynamic> body = _decode(response);
      final List<dynamic> results =
          body['results'] as List<dynamic>? ?? const <dynamic>[];
      return results
          .whereType<Map<String, dynamic>>()
          .map(SeafoodSummary.fromJson)
          .toList();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  Future<SeafoodProfile> profile(String fishId) async {
    try {
      final http.Response response = await _client
          .get(
            _uri('/seafood/$fishId'),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(_timeout);
      return SeafoodProfile.fromJson(_decode(response));
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  Future<PriceContext> price(String fishId) async {
    try {
      final http.Response response = await _client
          .get(
            _uri('/seafood/$fishId/price'),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(_timeout);
      return PriceContext.fromJson(_decode(response));
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  Future<List<SeafoodSummary>> favourites({required String token}) async {
    try {
      final http.Response response = await _client
          .get(_uri('/me/favourites'), headers: _authHeaders(token))
          .timeout(_timeout);
      return _decodeList(
        response,
      ).whereType<Map<String, dynamic>>().map(SeafoodSummary.fromJson).toList();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  Future<SeafoodSummary> addFavourite({
    required String token,
    required String fishId,
  }) async {
    try {
      final http.Response response = await _client
          .post(
            _uri('/me/favourites'),
            headers: <String, String>{
              ..._authHeaders(token),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, String>{'fish_id': fishId}),
          )
          .timeout(_timeout);
      return SeafoodSummary.fromJson(_decode(response));
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  Future<void> removeFavourite({
    required String token,
    required String fishId,
  }) async {
    try {
      final http.Response response = await _client
          .delete(_uri('/me/favourites/$fishId'), headers: _authHeaders(token))
          .timeout(_timeout);
      if (response.statusCode == 204) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _errorFrom(response);
      }
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  /// Epic 4 — parse a cooking intent and rank better alternatives.
  ///
  /// Send `query` for free text; send structured keys (`cooking_method`,
  /// `servings`, `fish_id`, …) without a query to re-rank after chip edits.
  /// An empty string clears a field; null leaves it unset.
  Future<SmartSwapResult> smartSwap(Map<String, Object?> body) async {
    return SmartSwapResult.fromJson(await _postJson('/smart-swap', body));
  }

  /// Epic 4 — recipes for the chosen fish, generated server-side (OpenAI).
  /// The OpenAI key never leaves the backend.
  Future<RecipeBatch> generateRecipes({
    required String fishId,
    String? cookingMethod,
    String? dish,
    int servings = 2,
    int count = 3,
    bool kidFriendly = false,
    String? difficulty,
    String? dietary,
    bool includeImages = true,
    List<String> excludeTitles = const <String>[],
  }) async {
    final Map<String, dynamic> json = await _postJson(
      '/recipes/generate',
      <String, Object?>{
        'fish_id': fishId,
        'cooking_method': cookingMethod,
        'dish': dish,
        'servings': servings,
        'count': count,
        'kid_friendly': kidFriendly,
        'difficulty': difficulty,
        'dietary': dietary,
        'include_images': includeImages,
        'exclude_titles': excludeTitles,
      },
      // Three full recipes in one reply can take 20-40 s.
      timeout: const Duration(seconds: 120),
    );
    return RecipeBatch.fromJson(json);
  }

  void close() => _client.close();

  // --- internals ------------------------------------------------------------

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body, {
    Duration? timeout,
  }) async {
    final Map<String, Object?> clean = <String, Object?>{
      for (final MapEntry<String, Object?> e in body.entries)
        if (e.value != null) e.key: e.value,
    };
    try {
      final http.Response response = await _client
          .post(
            _uri(path),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(clean),
          )
          .timeout(timeout ?? _timeout);
      return _decode(response);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_unreachableMessage(error));
    }
  }

  Map<String, String> _authHeaders(String token) {
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  List<dynamic> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFrom(response);
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw ApiException(
        'Unexpected response shape from the API.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

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
