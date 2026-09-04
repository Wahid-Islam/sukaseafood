import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/catalog/catalog_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AuthController authController = AuthController();
  await authController.restoreSession();
  final CatalogController catalogController = CatalogController(
    auth: authController,
  );
  runApp(
    SukaSeafoodApp(
      authController: authController,
      catalogController: catalogController,
    ),
  );
  unawaited(authController.refreshProfile());
  unawaited(catalogController.bootstrap());
}

class SukaSeafoodApp extends StatelessWidget {
  const SukaSeafoodApp({
    super.key,
    required this.authController,
    this.catalogController,
  });

  final AuthController authController;
  final CatalogController? catalogController;

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog =
        catalogController ?? CatalogController.forTesting();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<CatalogController>.value(value: catalog),
      ],
      child: MaterialApp.router(
        title: 'SukaSeafood',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: createRouter(authController),
      ),
    );
  }
}
