import 'package:flutter/foundation.dart';

/// App-wide constants for SukaSeafood mobile.
class AppConstants {
  AppConstants._();

  static const String appName = 'SukaSeafood';
  static const String tagline = 'Saving our seafood, from boat to bowl.';

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
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

  static const List<String> supportedSpeciesLabels = [
    'Kembung / Pelaling',
    'Bawal Hitam',
    'Ikan Merah',
    'Tilapia',
    'Kerapu Bintik',
  ];

  /// Iteration 1: CV identify exists, but the camera is not in the chrome.
  static const bool showScanner = false;
}
