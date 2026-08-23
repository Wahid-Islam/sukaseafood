import 'package:go_router/go_router.dart';

import '../../data/api/sukaseafood_api.dart';
import '../../features/cooking/cooking_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/home/app_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/identify/identify_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/seafood/seafood_detail_screen.dart';
import '../../features/search/search_screen.dart';

/// Declarative router for the Iteration 1 decision journey.
GoRouter createRouter(SukaseafoodApi api) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => HomeScreen(api: api),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => SearchScreen(api: api),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cooking',
                builder: (context, state) => CookingScreen(api: api),
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
        path: '/identify',
        builder: (context, state) => IdentifyScreen(api: api),
      ),
      GoRoute(
        path: '/seafood/:fishId',
        builder: (context, state) {
          final String fishId = state.pathParameters['fishId']!;
          return SeafoodDetailScreen(api: api, fishId: fishId);
        },
      ),
    ],
  );
}
