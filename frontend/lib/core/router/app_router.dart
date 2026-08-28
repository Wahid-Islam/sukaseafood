import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/cooking/cooking_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/home/app_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/price/price_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/seafood/seafood_detail_screen.dart';

GoRouter createRouter(AuthController auth) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) {
      if (!auth.isReady) return null;

      final String loc = state.matchedLocation;
      final bool onAuth = loc == '/onboarding' || loc == '/login';

      if (!auth.isSignedIn && !onAuth) return '/onboarding';
      if (auth.isSignedIn && onAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) => const ScanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/seafood/:id',
        builder: (context, state) {
          return SeafoodDetailScreen(seafoodId: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/price/:id',
        builder: (context, state) {
          return PriceScreen(seafoodId: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/cooking/:id',
        builder: (context, state) {
          return CookingScreen(seafoodId: state.pathParameters['id']!);
        },
      ),
    ],
  );
}
