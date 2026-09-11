import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/mock/mock_catalog.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';
import 'notifications_screen.dart';

const double _featuredOverlap = 64;

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
            child: Column(
              children: [
                DarkHeader(
                  height:
                      MediaQuery.paddingOf(context).top +
                      204 +
                      _featuredOverlap,
                  backgroundUrl: MockCatalog.heroBoat,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const BrandLogo(size: 36),
                            const SizedBox(width: 8),
                            Text(
                              'SukaSeafood',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: Colors.white),
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
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: Colors.white, fontSize: 28),
                            children: [
                              const TextSpan(text: 'Hai, '),
                              TextSpan(text: displayName),
                              const TextSpan(text: '! 👋'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Better choices for you, better for our oceans.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SearchBar(onTap: () => context.go('/explore')),
                        const SizedBox(height: _featuredOverlap),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -_featuredOverlap),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (catalog.isLoading && featured == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (featured != null)
                          _FeaturedCard(item: featured)
                        else if (catalog.error != null)
                          SoftCard(
                            child: Text(
                              'Catalogue is temporarily unavailable. ${catalog.error}',
                            ),
                          ),
                        const SizedBox(height: 20),
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
                            height: 168,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: favourites.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final SeafoodSummary item = favourites[index];
                                return _FavouriteCard(
                                  item: item,
                                  price: item.fishId == catalog.featured?.fishId
                                      ? catalog.featuredPrice
                                      : null,
                                  onTap: () =>
                                      context.push('/seafood/${item.fishId}'),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 20),
                        const _OceanBanner(),
                        const SizedBox(height: 88),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, color: AppColors.muted),
              SizedBox(width: 8),
              Text(
                'Malay, English or scientific name',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item});

  final SeafoodSummary item;

  @override
  Widget build(BuildContext context) {
    final String label = item.classification ?? 'UNDETERMINED';
    final String code = label.toUpperCase();
    final bool good = code == 'GOOD CHOICE' || code == 'BEST CHOICE';

    return SoftCard(
      onTap: () => context.push('/seafood/${item.fishId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.teal, size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'HIGHLIGHTED FISH OF THE WEEK',
                  style: TextStyle(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.shortName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 26, height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.scientificName,
                      style: const TextStyle(
                        color: AppColors.tealDark,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: ClassificationPill(
                            label: label,
                            caption: good ? 'Sustainable option' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.navy,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CatalogueFishArt(
                fishId: item.fishId,
                networkUrl: item.imageUrl,
                width: 132,
                height: 88,
                borderRadius: 16,
                fit: BoxFit.cover,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FavouriteCard extends StatelessWidget {
  const _FavouriteCard({required this.item, required this.onTap, this.price});

  final SeafoodSummary item;
  final PriceContext? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool priced = price?.isDisplayable == true;
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
                CatalogueFishArt(
                  fishId: item.fishId,
                  networkUrl: item.imageUrl,
                  width: 112,
                  height: 72,
                  borderRadius: 12,
                  fit: BoxFit.cover,
                ),
                const Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(Icons.favorite, color: AppColors.teal, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            Text(
              priced
                  ? 'RM ${price!.observedPriceRmPerKg!.toStringAsFixed(2)} /kg'
                  : (item.classification ?? 'UNDETERMINED'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.tealDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OceanBanner extends StatelessWidget {
  const _OceanBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1AA7A0),
            AppColors.tealDark,
            Color(0xFF0B5C62),
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Better choices today, healthier oceans tomorrow.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.3,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Every choice you make helps protect our oceans for future generations.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
