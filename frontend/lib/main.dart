import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/api/sukaseafood_api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SukaSeafoodApp());
}

class SukaSeafoodApp extends StatefulWidget {
  const SukaSeafoodApp({super.key});

  @override
  State<SukaSeafoodApp> createState() => _SukaSeafoodAppState();
}

class _SukaSeafoodAppState extends State<SukaSeafoodApp> {
  late final SukaseafoodApi _api = SukaseafoodApi();
  late final router = createRouter(_api);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
