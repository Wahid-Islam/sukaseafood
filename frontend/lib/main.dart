import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(SukaSeafoodApp(authController: AuthController()));
}

class SukaSeafoodApp extends StatelessWidget {
  const SukaSeafoodApp({super.key, required this.authController});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthController>.value(
      value: authController,
      child: MaterialApp.router(
        title: 'SukaSeafood',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: createRouter(authController),
      ),
    );
  }
}
