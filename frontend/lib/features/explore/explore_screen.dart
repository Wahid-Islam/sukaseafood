import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/discovery_categories.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<SeafoodSummary> _results = const <SeafoodSummary>[];
  bool _searching = false;
  String? _searchError;
  int _visibleCount = DiscoveryCatalog.pageSize;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final String q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const <SeafoodSummary>[];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final List<SeafoodSummary> found = await context
            .read<CatalogController>()
            .search(q);
        if (!mounted) return;
        setState(() {
          _results = DiscoveryCatalog.browseable(found);
          _searching = false;
          _searchError = null;
          _visibleCount = DiscoveryCatalog.pageSize;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _results = const <SeafoodSummary>[];
          _searching = false;
          _searchError = error.toString();
        });
      }
    });
  }

  void _openCategory(DiscoveryCategory category) {
    context.push('/explore/category/${category.name}');
  }

  void _surprise(List<SeafoodSummary> pool) {
    if (pool.isEmpty) return;
    final SeafoodSummary pick = pool[math.Random().nextInt(pool.length)];
    context.push('/seafood/${pick.fishId}');
  }

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final List<SeafoodSummary> browseable = DiscoveryCatalog.browseable(
      catalog.items,
    );
    final bool searching = _controller.text.trim().isNotEmpty;
    final List<SeafoodSummary> popular = DiscoveryCatalog.filter(
      browseable,
      DiscoveryCategory.popular,
    );

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const _DiscoverHeader(),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search for seafood...',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (searching)
                _SearchResults(
                  searching: _searching,
                  error: _searchError,
                  results: _results,
                  visibleCount: _visibleCount,
                  onClear: () {
                    _controller.clear();
                    _onQueryChanged('');
                  },
                  onLoadMore: () => setState(
                    () => _visibleCount += DiscoveryCatalog.pageSize,
                  ),
                )
              else ...[
                _CategoryGrid(
                  onSelect: _openCategory,
                  onSeeAll: () => _openCategory(DiscoveryCategory.all),
                ),
                const SizedBox(height: 18),
                _HeroBanner(
                  onExplore: () => _openCategory(DiscoveryCategory.all),
                ),
                const SizedBox(height: 22),
                _PopularRow(
                  items: popular,
                  onSeeAll: () => _openCategory(DiscoveryCategory.popular),
                ),
                const SizedBox(height: 22),
                _UndecidedCard(
                  onScan: () => context.go('/scan'),
                  onSurprise: () => _surprise(browseable),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore Seafood',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 28,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Discover new seafood, better choices',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.onSelect, required this.onSeeAll});

  final ValueChanged<DiscoveryCategory> onSelect;
  final VoidCallback onSeeAll;

  static IconData _icon(DiscoveryCategory id) {
    return switch (id) {
      DiscoveryCategory.all => Icons.set_meal_outlined,
      DiscoveryCategory.popular => Icons.star_outline_rounded,
      DiscoveryCategory.sustainable => Icons.eco_outlined,
      DiscoveryCategory.grill => Icons.outdoor_grill_outlined,
      DiscoveryCategory.curry => Icons.soup_kitchen_outlined,
      DiscoveryCategory.steam => Icons.rice_bowl_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Browse by category',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const Spacer(),
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            for (final DiscoveryCategorySpec spec
                in DiscoveryCatalog.categories)
              Material(
                color: Color(spec.tint),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSelect(spec.id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_icon(spec.id), color: AppColors.navy, size: 22),
                        const Spacer(),
                        Text(
                          spec.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          spec.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          const SizedBox(
            height: 200,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Color(0xFF063A46),
                    Color(0xFF0E6B63),
                    Color(0xFF1AA7A0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXPLORE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Malaysia's Incredible Seafood",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Expanded(
                    child: Text(
                      "From familiar favourites to hidden gems, discover seafood that's good for you and our oceans.",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: onExplore,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Start exploring  →'),
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

class _PopularRow extends StatelessWidget {
  const _PopularRow({required this.items, required this.onSeeAll});

  final List<SeafoodSummary> items;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Popular in Malaysia',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const Spacer(),
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              return SizedBox(
                width: 132,
                child: _SeafoodCard(item: items[index], compact: true),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UndecidedCard extends StatelessWidget {
  const _UndecidedCard({required this.onScan, required this.onSurprise});

  final VoidCallback onScan;
  final VoidCallback onSurprise;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not sure what to choose?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Take a photo to identify a fish or browse by category to find the perfect match.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: onScan,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Scan a fish'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: onSurprise,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Surprise me'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.searching,
    required this.error,
    required this.results,
    required this.visibleCount,
    required this.onClear,
    required this.onLoadMore,
  });

  final bool searching;
  final String? error;
  final List<SeafoodSummary> results;
  final int visibleCount;
  final VoidCallback onClear;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return SoftCard(child: Text(error!));
    }
    if (results.isEmpty) {
      return _EmptyDiscovery(
        message: 'No supported seafood matched that name.',
        actionLabel: 'Clear search',
        onAction: onClear,
      );
    }
    return _PagedCardList(
      title: 'Results',
      items: results,
      visibleCount: visibleCount,
      onLoadMore: onLoadMore,
    );
  }
}

class _EmptyDiscovery extends StatelessWidget {
  const _EmptyDiscovery({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _PagedCardList extends StatelessWidget {
  const _PagedCardList({
    required this.title,
    required this.items,
    required this.visibleCount,
    required this.onLoadMore,
  });

  final String title;
  final List<SeafoodSummary> items;
  final int visibleCount;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final List<SeafoodSummary> page = DiscoveryCatalog.page(
      items,
      visibleCount: visibleCount,
    );
    final bool more = visibleCount < items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final SeafoodSummary item in page) ...[
          _SeafoodCard(item: item),
          const SizedBox(height: 10),
        ],
        if (more)
          Center(
            child: TextButton(
              onPressed: onLoadMore,
              child: const Text('Load more'),
            ),
          ),
      ],
    );
  }
}

class _SeafoodCard extends StatelessWidget {
  const _SeafoodCard({required this.item, this.compact = false});

  final SeafoodSummary item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String label = item.classification ?? 'UNDETERMINED';
    return SoftCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/seafood/${item.fishId}'),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CatalogueFishArt(
                  fishId: item.fishId,
                  networkUrl: item.imageUrl,
                  width: 112,
                  height: 78,
                  borderRadius: 12,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 8),
                Text(
                  item.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.classificationColor(label),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                CatalogueFishArt(
                  fishId: item.fishId,
                  networkUrl: item.imageUrl,
                  width: 84,
                  height: 72,
                  borderRadius: 14,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.shortName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        item.namesSubtitle.isEmpty
                            ? item.scientificName
                            : item.namesSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      ClassificationPill(label: label),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
    );
  }
}
