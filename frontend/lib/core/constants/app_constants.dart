import 'package:flutter/foundation.dart';

/// App-wide constants for SukaSeafood mobile.
class AppConstants {
  AppConstants._();

  static const String appName = 'SukaSeafood';
  static const String tagline = 'Saving our seafood, from boat to bowl.';

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// CARTO raster basemap key. Pass at build time with
  /// `--dart-define=CARTO_BASEMAPS_KEY=...` — do not commit the key.
  static const String cartoBasemapsKey = String.fromEnvironment(
    'CARTO_BASEMAPS_KEY',
  );

  /// Production API via Firebase Hosting rewrite to Cloud Run.
  ///
  /// On web the default is same-origin `/api/v1`, so the Iteration 1 freeze
  /// site and the working site each talk to their own Cloud Run service.
  /// Override locally with
  /// `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return '/api/v1';
    return 'https://sukaseafood-654b7.web.app/api/v1';
  }

  static const List<String> cookingMethods = [
    'grilling',
    'soup',
    'curry',
    'pan-fry',
    'stir-fry',
    'steaming',
  ];

  static const List<String> scannerSpeciesLabels = [
    'Kembung / Pelaling (Indian Mackerel)',
    'Bawal Hitam (Black Pomfret)',
    'Ikan Merah (Red Snapper)',
    'Tilapia',
    'Kerapu Bintik (Orange Spotted Grouper)',
    'Cencaru (Hardtail Scad)',
    'Jenahak (John\'s Snapper)',
    'Tenggiri (Spanish Mackerel)',
    'Siakap Putih (Barramundi)',
    'Alaskan Pollock',
    'Atlantic Cod',
    'Atlantic Salmon',
    'Kerapu Harimau (Brown-marble Grouper)',
    'Kerapu Kertang (Giant Grouper)',
    'Kerapu Lumpur (Malabar Grouper)',
    'Kerapu Tikus (Humpback Grouper)',
    'Kunyit-kunyit (Brownstripe Red Snapper)',
    'Mameng (Humphead Wrasse)',
    'Siakap Merah (Mangrove Red Snapper)',
  ];

  /// Iteration 2: the 19-class ConvNeXt scanner is in the chrome.
  static const bool showScanner = true;
}
