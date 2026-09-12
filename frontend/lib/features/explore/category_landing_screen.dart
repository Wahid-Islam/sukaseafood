import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/discovery_categories.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';

class CategoryLandingScreen extends StatelessWidget {
  const CategoryLandingScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final DiscoveryCategory? category = DiscoveryCatalog.parse(categoryId);
    if (category == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Category'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('This category is not available.')),
      );
    }

    final DiscoveryCategorySpec spec = DiscoveryCatalog.specFor(category);
    final CatalogController catalog = context.watch<CatalogController>();
    final List<SeafoodSummary> items = DiscoveryCatalog.filter(
      catalog.items,
      category,
    );

    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        backgroundColor: AppColors.foam,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/explore');
            }
          },
        ),
        title: Column(
          children: [
            Text(spec.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              spec.subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _CategoryHero(spec: spec),
            const SizedBox(height: 16),
            if (items.isEmpty)
              SoftCard(
                child: Text(
                  'No supported seafood matches ${spec.title.toLowerCase()} yet. '
                  'Try another category or view the full list.',
                ),
              )
            else
              _CategoryGrid(category: category, items: items),
          ],
        ),
      ),
    );
  }
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({required this.spec});

  final DiscoveryCategorySpec spec;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              Color(0xFF0A3A4A),
              Color(0xFF146B7A),
              Color(0xFF1FA3A8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DISCOVER',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              spec.heroTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 26,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              spec.heroBody,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.category, required this.items});

  final DiscoveryCategory category;
  final List<SeafoodSummary> items;

  @override
  Widget build(BuildContext context) {
    final int columns = MediaQuery.sizeOf(context).width >= 700 ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (BuildContext context, int index) {
        return _CategoryFishCard(category: category, item: items[index]);
      },
    );
  }
}

class _CategoryFishCard extends StatelessWidget {
  const _CategoryFishCard({required this.category, required this.item});

  final DiscoveryCategory category;
  final SeafoodSummary item;

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final bool saved = catalog.isFavourite(item.fishId);
    final String blurb = DiscoveryCatalog.blurbFor(item, category);
    final List<String> tags = DiscoveryCatalog.tagsFor(item, category);
    final String subtitle = <String>[
      if (item.displayNameEn.isNotEmpty) item.displayNameEn,
      if (item.scientificName.isNotEmpty) item.scientificName,
    ].join(' · ');

    return SoftCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/seafood/${item.fishId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CatalogueFishArt(
                fishId: item.fishId,
                networkUrl: item.imageUrl,
                width: double.infinity,
                height: 96,
                borderRadius: 14,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => catalog.toggleFavourite(item.fishId),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        saved ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: saved ? AppColors.avoid : AppColors.navy,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              blurb,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final String tag in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tealDark,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
