/// App-wide constants for SukaSeafood mobile.
class AppConstants {
  AppConstants._();

  static const String appName = 'SukaSeafood';
  static const String tagline = 'Saving our seafood, from boat to bowl.';

  /// Hosted FastAPI on Cloud Run. Override locally with
  /// `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://sukaseafood-api-147789152548.asia-southeast1.run.app/api/v1',
  );

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
}
