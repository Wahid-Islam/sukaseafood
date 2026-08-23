/// App-wide constants for SukaSeafood mobile.
class AppConstants {
  AppConstants._();

  static const String appName = 'SukaSeafood';
  static const String tagline = 'Saving our seafood, from boat to bowl.';

  /// Android emulator reaches host machine localhost via 10.0.2.2.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
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
