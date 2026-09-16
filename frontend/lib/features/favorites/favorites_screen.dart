import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  static const String headerAsset =
      'assets/images/explore/favourites_header.png';

  @override
  Widget build(BuildContext context) {
    final List<SeafoodSummary> items = context
        .watch<CatalogController>()
        .favourites;
    return Scaffold(
      backgroundColor: AppColors.foam,
      body: ContentWidth(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _FavouritesHero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    const _GlanceCard(),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const SoftCard(
                        child: Text(
                          'Nothing saved yet. Open a species and tap the heart — the list is yours, not a shared starter pack.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (int i = 0; i < items.length; i++) ...[
                        _FavouriteRow(item: items[i]),
                        if (i != items.length - 1) const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
    );
  }
}

class _FavouritesHero extends StatelessWidget {
  const _FavouritesHero();

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: SizedBox(
        height: top + 168,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              FavoritesScreen.headerAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0.35, -0.72),
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.navy),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Color(0x99051A28),
                    Color(0x33051A28),
                    Color(0x00051A28),
                  ],
                  stops: <double>[0, 0.42, 0.82],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, top + 18, 18, 28),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Favourites',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      height: 1.05,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your saved seafood choices',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlanceCard extends StatelessWidget {
  const _GlanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6F4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFD4EEEB),
            child: Icon(Icons.favorite, color: AppColors.tealDark, size: 16),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your favourites, at a glance',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Keep track of the seafood you care about.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavouriteRow extends StatelessWidget {
  const _FavouriteRow({required this.item});

  final SeafoodSummary item;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      onTap: () => context.push('/seafood/${item.fishId}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CatalogueFishArt(
            fishId: item.fishId,
            networkUrl: item.imageUrl,
            width: 88,
            height: 88,
            borderRadius: 16,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  item.scientificName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.tealDark,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Fact(
                        icon: Icons.eco_outlined,
                        title: 'Sustainability',
                        value: _choiceLabel(item.classification),
                        color: AppTheme.classificationColor(
                          item.classification ?? '',
                        ),
                      ),
                    ),
                    Expanded(
                      child: _Fact(
                        icon: Icons.restaurant_outlined,
                        title: 'Best for',
                        value: _bestFor(item),
                        color: AppColors.navy,
                      ),
                    ),
                    Expanded(
                      child: _Fact(
                        icon: Icons.place_outlined,
                        title: 'Common in',
                        value: _commonIn(item),
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () =>
                context.read<CatalogController>().toggleFavourite(item.fishId),
            icon: const Icon(Icons.favorite, color: Color(0xFFFF6B81)),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.tealDark),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (value.isNotEmpty)
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
      ],
    );
  }
}

String _choiceLabel(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'GOOD CHOICE':
    case 'BEST CHOICE':
      return 'Better Choice';
    case 'REDUCE':
      return 'Use with Care';
    case 'AVOID':
      return 'Overfished';
    default:
      return 'Unknown';
  }
}

String _bestFor(SeafoodSummary item) {
  return item.suitableMethods
      .take(2)
      .map(_methodLabel)
      .where((String label) => label.isNotEmpty)
      .join(', ');
}

String _methodLabel(String method) {
  return switch (method.toLowerCase()) {
    'grill' => 'Grilling',
    'curry' => 'Curry',
    'steam' => 'Steaming',
    'fry' => 'Frying',
    'soup' => 'Soup',
    'bake' => 'Baking',
    'raw' => 'Raw',
    _ =>
      method.isEmpty ? '' : '${method[0].toUpperCase()}${method.substring(1)}',
  };
}

String _commonIn(SeafoodSummary item) {
  final String raw = item.fishType.trim();
  if (raw.isEmpty) return '';
  return raw
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
