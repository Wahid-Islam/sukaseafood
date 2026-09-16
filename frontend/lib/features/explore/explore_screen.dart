import 'dart:async';

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

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final List<SeafoodSummary> browseable = DiscoveryCatalog.browseable(
      catalog.items,
    );
    final bool searching = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const _ExploreHeader(),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search for seafood...',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: AppColors.tealDark,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try kembung, Ikan merah, tenggiri...',
                style: TextStyle(
                  color: AppColors.tealDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
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
                _ScannerPromo(onTap: () => context.go('/scan')),
                const SizedBox(height: 22),
                _CategoryGrid(onSelect: _openCategory),
                const SizedBox(height: 16),
                _FullCatalogueBanner(
                  count: browseable.length,
                  onTap: () => _openCategory(DiscoveryCategory.all),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Seafood',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  color: AppColors.navy,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Discover seafood. Choose better.',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Column(
          children: [
            BrandLogo(size: 46),
            SizedBox(height: 2),
            Text(
              'SukaSeafood',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
            Text(
              'BETTER CHOICES.\nHEALTHIER OCEANS.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.tealDark,
                fontSize: 6.5,
                fontWeight: FontWeight.w700,
                height: 1.15,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScannerPromo extends StatelessWidget {
  const _ScannerPromo({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 176,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/explore/scanner_card.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.28, 0),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        Color(0xF2082A3A),
                        Color(0xCC082A3A),
                        Color(0x66082A3A),
                        Color(0x14082A3A),
                      ],
                      stops: <double>[0, 0.38, 0.62, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.photo_camera_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Not sure what this is?',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1.15,
                          ),
                        ),
                        const Text(
                          'Scan a fish to identify it.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.teal,
                          child: Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.onSelect});

  final ValueChanged<DiscoveryCategory> onSelect;

  static IconData _icon(DiscoveryCategory id) {
    return switch (id) {
      DiscoveryCategory.popular => Icons.star_rounded,
      DiscoveryCategory.sustainable => Icons.eco_outlined,
      DiscoveryCategory.grill => Icons.local_fire_department_outlined,
      DiscoveryCategory.curry => Icons.soup_kitchen_outlined,
      DiscoveryCategory.steam => Icons.air,
      DiscoveryCategory.fry => Icons.breakfast_dining_outlined,
      _ => Icons.set_meal_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final List<DiscoveryCategory> tiles = DiscoveryCatalog.exploreTiles;
    final int columns = MediaQuery.sizeOf(context).width >= 700 ? 3 : 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse by category',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < tiles.length; i += columns)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + columns < tiles.length ? 10 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int j = 0; j < columns; j++) ...[
                  if (j > 0) const SizedBox(width: 10),
                  Expanded(
                    child: i + j < tiles.length
                        ? _PhotoCategoryTile(
                            spec: DiscoveryCatalog.specFor(tiles[i + j]),
                            icon: _icon(tiles[i + j]),
                            onTap: () => onSelect(tiles[i + j]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PhotoCategoryTile extends StatelessWidget {
  const _PhotoCategoryTile({
    required this.spec,
    required this.icon,
    required this.onTap,
  });

  final DiscoveryCategorySpec spec;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 148),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    spec.tileAsset,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.45, 0),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          Color(0xF8F7F1E6),
                          Color(0xE6F7F1E6),
                          Color(0x99F7F1E6),
                          Color(0x33F7F1E6),
                          Color(0x00F7F1E6),
                        ],
                        stops: <double>[0, 0.28, 0.46, 0.68, 1],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: FractionallySizedBox(
                    widthFactor: 0.7,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: AppColors.navy, size: 16),
                        const SizedBox(height: 18),
                        Text(
                          spec.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.navy,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          spec.subtitle,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: AppColors.tealDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullCatalogueBanner extends StatelessWidget {
  const _FullCatalogueBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Explore the full catalogue. $count supported species. Browse A to Z.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ExcludeSemantics(
              child: Image.asset(
                'assets/images/explore/catalogue_cta.jpg',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
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
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No supported seafood matched that name.'),
            const SizedBox(height: 10),
            TextButton(onPressed: onClear, child: const Text('Clear search')),
          ],
        ),
      );
    }
    final List<SeafoodSummary> page = DiscoveryCatalog.page(
      results,
      visibleCount: visibleCount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Results',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 10),
        for (final SeafoodSummary item in page) ...[
          _SearchCard(item: item),
          const SizedBox(height: 10),
        ],
        if (visibleCount < results.length)
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

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.item});

  final SeafoodSummary item;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/seafood/${item.fishId}'),
      child: Row(
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
                  item.scientificName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
