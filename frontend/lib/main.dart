import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SukaSeafoodApp());
}

class SukaSeafoodApp extends StatelessWidget {
  const SukaSeafoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SukaSeafood',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: createRouter(),
    );
  }
}
