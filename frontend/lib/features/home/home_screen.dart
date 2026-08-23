import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/sukaseafood_api.dart';
import '../../data/models/seafood_models.dart';
import '../../shared/widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final SukaseafoodApi api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<SeafoodSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listSeafood();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 16,
                bottom: 14,
              ),
              title: Text(
                AppConstants.appName,
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.navy, AppTheme.deepSea, Color(0xFF1A5A63)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 52),
                    child: Text(
                      'Make informed choices.\nSupport healthy oceans.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                const SectionHeader(
                  title: 'Quick actions',
                  subtitle: 'Point-of-purchase decision support',
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickAction(
                      icon: Icons.search,
                      label: 'Search',
                      onTap: () => context.go('/search'),
                    ),
                    _QuickAction(
                      icon: Icons.photo_camera_outlined,
                      label: 'Scan seafood',
                      onTap: () => context.go('/identify'),
                    ),
                    _QuickAction(
                      icon: Icons.restaurant_menu,
                      label: 'Cooking',
                      onTap: () => context.go('/cooking'),
                    ),
                    _QuickAction(
                      icon: Icons.favorite_border,
                      label: 'Favourites',
                      onTap: () => context.go('/favorites'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SectionHeader(
                  title: 'Supported species (I1)',
                  subtitle: 'Five Malaysian seafood records in scope',
                ),
                FutureBuilder<List<SeafoodSummary>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _ErrorBox(
                        message:
                            'Cannot reach API. Start backend on :8000.\n'
                            '${snapshot.error}',
                        onRetry: () {
                          setState(() {
                            _future = widget.api.listSeafood();
                          });
                        },
                      );
                    }
                    final List<SeafoodSummary> items = snapshot.data ?? [];
                    return Column(
                      children: items
                          .map(
                            (SeafoodSummary s) => SeafoodListTile(
                              title: s.primaryCommonName,
                              subtitle: s.scientificName,
                              classification: s.classification,
                              onTap: () => context.push('/seafood/${s.fishId}'),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.teal.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.deepSea),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.caution.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
