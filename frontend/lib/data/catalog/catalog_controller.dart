import 'package:flutter/foundation.dart';

import '../../core/auth/auth_controller.dart';
import '../api/api_client.dart';
import '../models/seafood.dart';

/// Live catalogue + account favourites. Replaces MockCatalog on user-facing
/// screens so search, detail, cooking and price never disagree.
class CatalogController extends ChangeNotifier {
  CatalogController({
    required AuthController auth,
    ApiClient? client,
  })  : _auth = auth,
        _client = client ?? ApiClient(),
        _useApi = true {
    auth.addListener(_handleAuthChange);
  }

  CatalogController.forTesting({
    List<SeafoodSummary> items = const <SeafoodSummary>[],
    List<SeafoodSummary> favourites = const <SeafoodSummary>[],
  })  : _auth = null,
        _client = null,
        _useApi = false,
        _items = List<SeafoodSummary>.from(items),
        _favourites = List<SeafoodSummary>.from(favourites),
        _ready = true;

  final AuthController? _auth;
  final ApiClient? _client;
  final bool _useApi;

  List<SeafoodSummary> _items = const <SeafoodSummary>[];
  List<SeafoodSummary> _favourites = const <SeafoodSummary>[];
  PriceContext? _featuredPrice;
  bool _ready = false;
  bool _loading = false;
  String? _error;

  List<SeafoodSummary> get items => _items;
  List<SeafoodSummary> get favourites => _favourites;
  PriceContext? get featuredPrice => _featuredPrice;
  bool get isReady => _ready;
  bool get isLoading => _loading;
  String? get error => _error;

  /// Prefer a verified GOOD CHOICE; otherwise the first catalogue row.
  SeafoodSummary? get featured {
    for (final SeafoodSummary item in _items) {
      final String label = (item.classification ?? '').toUpperCase();
      if (label == 'GOOD CHOICE' || label == 'BEST CHOICE') return item;
    }
    return _items.isEmpty ? null : _items.first;
  }

  bool isFavourite(String fishId) {
    return _favourites.any((SeafoodSummary e) => e.fishId == fishId);
  }

  Future<void> bootstrap() async {
    if (!_useApi) {
      _ready = true;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final ApiClient client = _client!;
      _items = await client.listSeafood();
      await _loadFavourites();
      final SeafoodSummary? lead = featured;
      if (lead != null) {
        try {
          _featuredPrice = await client.price(lead.fishId);
        } catch (_) {
          _featuredPrice = null;
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      _ready = true;
      notifyListeners();
    }
  }

  Future<List<SeafoodSummary>> search(String query) {
    if (!_useApi) {
      final String q = query.trim().toLowerCase();
      return Future<List<SeafoodSummary>>.value(
        _items
            .where(
              (SeafoodSummary e) =>
                  e.primaryCommonName.toLowerCase().contains(q) ||
                  e.scientificName.toLowerCase().contains(q) ||
                  e.fishId.toLowerCase().contains(q),
            )
            .toList(),
      );
    }
    return _client!.search(query);
  }

  Future<SeafoodProfile> profile(String fishId) {
    if (!_useApi) {
      throw ApiException('Catalogue is in test mode.');
    }
    return _client!.profile(fishId);
  }

  Future<PriceContext> price(String fishId) {
    if (!_useApi) {
      return Future<PriceContext>.value(
        PriceContext(
          fishId: fishId,
          status: 'Insufficient data',
          disclaimer: '',
        ),
      );
    }
    return _client!.price(fishId);
  }

  Future<void> toggleFavourite(String fishId) async {
    if (!_useApi) return;
    final String? token = _auth?.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      if (isFavourite(fishId)) {
        await _client!.removeFavourite(token: token, fishId: fishId);
        _favourites = _favourites
            .where((SeafoodSummary e) => e.fishId != fishId)
            .toList();
      } else {
        final SeafoodSummary added =
            await _client!.addFavourite(token: token, fishId: fishId);
        _favourites = <SeafoodSummary>[added, ..._favourites];
      }
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> _handleAuthChange() async {
    if (!_useApi) return;
    await _loadFavourites();
    if (hasListeners) notifyListeners();
  }

  Future<void> _loadFavourites() async {
    final String? token = _auth?.accessToken;
    if (token == null || token.isEmpty) {
      _favourites = const <SeafoodSummary>[];
      return;
    }
    try {
      _favourites = await _client!.favourites(token: token);
    } on ApiException {
      _favourites = const <SeafoodSummary>[];
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_handleAuthChange);
    _client?.close();
    super.dispose();
  }
}
