import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../models/seafood_models.dart';

/// HTTP client for the SukaSeafood Iteration 1 API.
class SukaseafoodApi {
  SukaseafoodApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConstants.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  Future<List<SeafoodSummary>> listSeafood() async {
    final http.Response res = await _client.get(_uri('/seafood'));
    _ensureOk(res);
    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((dynamic e) => SeafoodSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SeafoodSummary>> search(String query) async {
    final http.Response res = await _client.get(
      _uri('/search', <String, String>{'q': query}),
    );
    _ensureOk(res);
    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((dynamic e) => SeafoodSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SeafoodProfile> getProfile(String fishId) async {
    final http.Response res = await _client.get(_uri('/seafood/$fishId'));
    _ensureOk(res);
    return SeafoodProfile.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<PriceContext> getPrice(String fishId) async {
    final http.Response res = await _client.get(_uri('/seafood/$fishId/price'));
    _ensureOk(res);
    return PriceContext.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<SeafoodSummary>> cookingRecommendations(String method) async {
    final http.Response res = await _client.get(_uri('/cooking/$method'));
    _ensureOk(res);
    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = data['recommendations'] as List<dynamic>? ?? [];
    return rows
        .map((dynamic e) => SeafoodSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<IdentifyResult> identify({String? hint}) async {
    final Uri uri = _uri(
      '/identify',
      hint == null ? null : <String, String>{'hint': hint},
    );
    final http.Response res = await _client.post(uri);
    _ensureOk(res);
    return IdentifyResult.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }
  }
}
