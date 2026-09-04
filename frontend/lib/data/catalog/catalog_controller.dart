import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/auth/auth_controller.dart';
import '../api/api_client.dart';
import '../models/price_forecast.dart';
import '../models/seafood.dart';

/// Live catalogue + account favourites. Replaces MockCatalog on user-facing
/// screens so search, detail, cooking and price never disagree.
class CatalogController extends ChangeNotifier {
  CatalogController({required AuthController auth, ApiClient? client})
    : _auth = auth,
      _client = client ?? ApiClient(),
      _useApi = true {
    auth.addListener(_handleAuthChange);
    _authTokenSeen = auth.accessToken;
  }

  CatalogController.forTesting({
    List<SeafoodSummary> items = const <SeafoodSummary>[],
    List<SeafoodSummary> favourites = const <SeafoodSummary>[],
  }) : _auth = null,
       _client = null,
       _useApi = false,
       _items = _uniqueById(items),
       _favourites = _uniqueById(favourites),
       _ready = true;

  final AuthController? _auth;
  final ApiClient? _client;
  final bool _useApi;
  final Map<String, int> _favouriteEpoch = <String, int>{};
  final Map<String, SeafoodProfile> _profiles = <String, SeafoodProfile>{};
  final Map<String, PriceContext> _prices = <String, PriceContext>{};
  final Map<String, PriceForecast> _forecasts = <String, PriceForecast>{};
  final Map<String, Future<SeafoodProfile>> _profileInflight =
      <String, Future<SeafoodProfile>>{};
  final Map<String, Future<PriceContext>> _priceInflight =
      <String, Future<PriceContext>>{};
  final Map<String, Future<PriceForecast>> _forecastInflight =
      <String, Future<PriceForecast>>{};

  List<SeafoodSummary> _items = const <SeafoodSummary>[];
  List<SeafoodSummary> _favourites = const <SeafoodSummary>[];
  PriceContext? _featuredPrice;
  bool _ready = false;
  bool _loading = false;
  String? _error;
  String? _authTokenSeen;

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

  SeafoodSummary? itemById(String fishId) {
    final String id = fishId.toUpperCase();
    for (final SeafoodSummary item in _items) {
      if (item.fishId.toUpperCase() == id) return item;
    }
    for (final SeafoodSummary item in _favourites) {
      if (item.fishId.toUpperCase() == id) return item;
    }
    return null;
  }

  bool isFavourite(String fishId) {
    final String id = fishId.toUpperCase();
    return _favourites.any((SeafoodSummary e) => e.fishId.toUpperCase() == id);
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
      final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
        client.listSeafood(),
        _fetchFavourites(),
      ]);
      _items = _uniqueById(loaded[0] as List<SeafoodSummary>);
      _favourites = _uniqueById(loaded[1] as List<SeafoodSummary>);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      _ready = true;
      notifyListeners();
      final String? featuredId = featured?.fishId;
      if (featuredId != null) {
        unawaited(price(featuredId));
      }
    }
  }

  Future<List<SeafoodSummary>> search(String query) {
    final String q = query.trim().toLowerCase();
    List<SeafoodSummary> localMatches() {
      return _items
          .where(
            (SeafoodSummary e) =>
                e.primaryCommonName.toLowerCase().contains(q) ||
                e.scientificName.toLowerCase().contains(q) ||
                e.fishId.toLowerCase().contains(q),
          )
          .toList();
    }

    if (!_useApi || _items.isNotEmpty) {
      return Future<List<SeafoodSummary>>.value(localMatches());
    }
    return _client!.search(query);
  }

  Future<SeafoodProfile> profile(String fishId) {
    if (!_useApi) {
      return Future<SeafoodProfile>.error(
        ApiException('Catalogue is in test mode.'),
      );
    }
    final String key = fishId.toUpperCase();
    final SeafoodProfile? cached = _profiles[key];
    if (cached != null) return Future<SeafoodProfile>.value(cached);
    return _profileInflight.putIfAbsent(key, () async {
      try {
        final SeafoodProfile loaded = await _client!.profile(fishId);
        _profiles[key] = loaded;
        return loaded;
      } finally {
        _profileInflight.remove(key);
      }
    });
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
    final String key = fishId.toUpperCase();
    final PriceContext? cached = _prices[key];
    if (cached != null) return Future<PriceContext>.value(cached);
    return _priceInflight.putIfAbsent(key, () async {
      try {
        final PriceContext loaded = await _client!.price(fishId);
        _prices[key] = loaded;
        if (featured?.fishId.toUpperCase() == key) {
          _featuredPrice = loaded;
          if (hasListeners) notifyListeners();
        }
        return loaded;
      } finally {
        _priceInflight.remove(key);
      }
    });
  }

  Future<PriceForecast> forecast(String fishId, {String? locationId}) {
    if (!_useApi) {
      return Future<PriceForecast>.error(
        ApiException('Catalogue is in test mode.'),
      );
    }
    final String key = '${fishId.toUpperCase()}|${locationId ?? ''}';
    final PriceForecast? cached = _forecasts[key];
    if (cached != null) return Future<PriceForecast>.value(cached);
    return _forecastInflight.putIfAbsent(key, () async {
      try {
        final PriceForecast loaded = await _client!.forecast(
          fishId,
          locationId: locationId,
        );
        _forecasts[key] = loaded;
        return loaded;
      } finally {
        _forecastInflight.remove(key);
      }
    });
  }

  Future<void> toggleFavourite(String fishId) async {
    final String id = fishId.toUpperCase();
    final bool removing = isFavourite(fishId);
    if (!_useApi) {
      _applyFavourite(fishId, add: !removing);
      notifyListeners();
      return;
    }

    final String? token = _auth?.accessToken;
    if (token == null || token.isEmpty) return;

    final List<SeafoodSummary> snapshot = List<SeafoodSummary>.from(
      _favourites,
    );
    _applyFavourite(fishId, add: !removing);
    notifyListeners();

    final int epoch = (_favouriteEpoch[id] ?? 0) + 1;
    _favouriteEpoch[id] = epoch;
    try {
      if (removing) {
        await _client!.removeFavourite(token: token, fishId: fishId);
      } else {
        final SeafoodSummary added = await _client!.addFavourite(
          token: token,
          fishId: fishId,
        );
        if (_favouriteEpoch[id] != epoch) return;
        _favourites = _uniqueById(<SeafoodSummary>[added, ..._favourites]);
        notifyListeners();
      }
    } on ApiException catch (e) {
      if (_favouriteEpoch[id] != epoch) return;
      _favourites = snapshot;
      _error = e.message;
      notifyListeners();
    }
  }

  void _applyFavourite(String fishId, {required bool add}) {
    final String id = fishId.toUpperCase();
    if (add) {
      final SeafoodSummary? local = itemById(fishId);
      if (local == null) return;
      _favourites = _uniqueById(<SeafoodSummary>[local, ..._favourites]);
      return;
    }
    _favourites = _favourites
        .where((SeafoodSummary e) => e.fishId.toUpperCase() != id)
        .toList();
  }

  Future<void> _handleAuthChange() async {
    if (!_useApi) return;
    final String? token = _auth?.accessToken;
    if (token == _authTokenSeen) return;
    _authTokenSeen = token;
    _favourites = await _fetchFavourites();
    if (hasListeners) notifyListeners();
  }

  Future<List<SeafoodSummary>> _fetchFavourites() async {
    final String? token = _auth?.accessToken;
    if (token == null || token.isEmpty) {
      return const <SeafoodSummary>[];
    }
    try {
      return _uniqueById(await _client!.favourites(token: token));
    } on ApiException {
      return const <SeafoodSummary>[];
    }
  }

  static List<SeafoodSummary> _uniqueById(List<SeafoodSummary> rows) {
    final Set<String> seen = <String>{};
    return <SeafoodSummary>[
      for (final SeafoodSummary row in rows)
        if (seen.add(row.fishId.toUpperCase())) row,
    ];
  }

  @override
  void dispose() {
    _auth?.removeListener(_handleAuthChange);
    _client?.close();
    super.dispose();
  }
}
