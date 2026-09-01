import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/mock/mock_catalog.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/ui_kit.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _unreadAlerts = NotificationsScreen.noticeCount;

  @override
  Widget build(BuildContext context) {
    final String displayName = context.watch<AuthController>().displayName;
    final CatalogController catalog = context.watch<CatalogController>();
    final SeafoodSummary? featured = catalog.featured;
    final List<SeafoodSummary> favourites = catalog.favourites;

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
                              tooltip: 'Price and landing alerts',
                              onPressed: () async {
                                await context.push('/notifications');
                                if (!mounted) return;
                                setState(() => _unreadAlerts = 0);
                              },
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white,
                              ),
                            ),
                            if (_unreadAlerts > 0)
                              Positioned(
                                right: 10,
                                top: 10,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppColors.avoid,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$_unreadAlerts',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
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
                  if (catalog.isLoading && featured == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (featured != null)
                    _FeaturedCard(
                      item: featured,
                      price: catalog.featuredPrice,
                    )
                  else if (catalog.error != null)
                    SoftCard(
                      child: Text(
                        'Catalogue is temporarily unavailable. ${catalog.error}',
                      ),
                    ),
                  const SizedBox(height: 18),
                  SoftCard(
                    onTap: () => context.push('/price/SF001'),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(
                          title: 'Seafood Pulse',
                          icon: Icons.tsunami,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Selangor outlook',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Live four-week forecasts cover Selangor, the engine’s production scope.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'View Kembung outlook →',
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
                    onTap: () => context.push('/cooking/SF011'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          NetworkFishImage(
                            url: featured?.imageUrl ?? MockCatalog.cookingDish,
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
                  if (favourites.isEmpty)
                    const SoftCard(
                      child: Text(
                        'No saved species yet. Open a fish profile and tap the heart to keep it here.',
                      ),
                    )
                  else
                    SizedBox(
                      height: 176,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: favourites.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final SeafoodSummary item = favourites[index];
                          return _FavouriteCard(
                            item: item,
                            onTap: () => context.push('/seafood/${item.fishId}'),
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
  const _FeaturedCard({required this.item, this.price});

  final SeafoodSummary item;
  final PriceContext? price;

  @override
  Widget build(BuildContext context) {
    final bool priced = price?.isDisplayable == true;
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/seafood/${item.fishId}'),
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
                        item.shortName,
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
                      Text(item.fishType),
                      const SizedBox(height: 10),
                      ClassificationPill(
                        label: item.classification ?? 'UNDETERMINED',
                      ),
                      const SizedBox(height: 10),
                      if (priced)
                        Text(
                          'RM${price!.latestPriceRmPerKg!.toStringAsFixed(2)} /kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: AppColors.ink,
                          ),
                        )
                      else
                        const Text(
                          'Observed PriceCatcher price is not displayable yet.',
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live catalogue',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Names, ratings and prices on this card come from the production API. Open the profile for sustainability, cooking and the four-week outlook.',
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

  final SeafoodSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              item.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            Text(
              item.classification ?? 'UNDETERMINED',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.tealDark,
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
