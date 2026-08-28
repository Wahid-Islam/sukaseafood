import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mock/mock_catalog.dart';
import '../../shared/widgets/ui_kit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String displayName = context.watch<AuthController>().displayName;
    final SeafoodItem featured = MockCatalog.featured;
    final List<SeafoodItem> favourites = MockCatalog.items.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DarkHeader(
              height: 250,
              backgroundUrl: MockCatalog.heroBoat,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.waves, color: AppColors.teal),
                        const SizedBox(width: 8),
                        Text(
                          'SukaSeafood',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                        const Spacer(),
                        Stack(
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white,
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                width: 16,
                                height: 16,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.avoid,
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  '2',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      'Make informed choices. Support healthy oceans.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                            ),
                        children: [
                          const TextSpan(text: 'Hai, '),
                          TextSpan(
                            text: displayName,
                            style: const TextStyle(color: AppColors.teal),
                          ),
                          const TextSpan(text: '!'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Better choices for you, better for our oceans.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SearchRow(
                      onSearchTap: () => context.go('/explore'),
                      onCameraTap: () => context.go('/scan'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SheetBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FeaturedCard(item: featured),
                  const SizedBox(height: 18),
                  const SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(
                          title: 'Seafood Pulse',
                          icon: Icons.tsunami,
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selangor landings',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '↑ 12%',
                                        style: TextStyle(
                                          color: AppColors.tealDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 28,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('vs last week'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.show_chart,
                              color: AppColors.teal,
                              size: 48,
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'View details →',
                          style: TextStyle(
                            color: AppColors.tealDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    onTap: () => context.push('/cooking/selar'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          NetworkFishImage(
                            url: MockCatalog.cookingDish,
                            height: 130,
                            borderRadius: 0,
                          ),
                          Container(
                            height: 130,
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.navy.withValues(alpha: 0.75),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Fresh ideas for today’s catch',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Match seafood to what you’re cooking.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.teal,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Find your match →',
                                    style: TextStyle(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionLabel(
                    title: 'Your Favourites',
                    trailing: TextButton(
                      onPressed: () => context.go('/favorites'),
                      child: const Text('View all →'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 176,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: favourites.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final SeafoodItem item = favourites[index];
                        return _FavouriteCard(
                          item: item,
                          onTap: () => context.push('/seafood/${item.id}'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 88),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.onSearchTap, required this.onCameraTap});

  final VoidCallback onSearchTap;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppColors.muted),
                    SizedBox(width: 8),
                    Text(
                      'Search seafood by name.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onCameraTap,
            borderRadius: BorderRadius.circular(14),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.photo_camera_outlined, color: AppColors.navy),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item});

  final SeafoodItem item;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/seafood/${item.id}'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.commonName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        item.scientificName,
                        style: const TextStyle(
                          color: AppColors.tealDark,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(item.about, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      ClassificationPill(label: item.classification),
                      const SizedBox(height: 10),
                      Text(
                        'RM${item.priceRm.toStringAsFixed(2)} /kg',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Range: RM${item.priceLow.toStringAsFixed(2)} – RM${item.priceHigh.toStringAsFixed(2)} /kg',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  height: 110,
                  child: NetworkFishImage(url: item.imageUrl, borderRadius: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.goodSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why it’s a good choice',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...item.whyGood.map(
                    (String line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.good,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(line)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavouriteCard extends StatelessWidget {
  const _FavouriteCard({required this.item, required this.onTap});

  final SeafoodItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool down = item.priceChangePct < 0;
    return SizedBox(
      width: 132,
      child: SoftCard(
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                NetworkFishImage(
                  url: item.imageUrl,
                  height: 64,
                  borderRadius: 12,
                ),
                const Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(Icons.favorite, color: AppColors.avoid, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.commonName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            Text(
              'RM ${item.priceRm.toStringAsFixed(2)} /kg',
              style: const TextStyle(
                color: AppColors.tealDark,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            Text(
              '${down ? '↓' : '↑'} ${item.priceChangePct.abs().toStringAsFixed(0)}%',
              style: TextStyle(
                color: down ? AppColors.good : AppColors.avoid,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
