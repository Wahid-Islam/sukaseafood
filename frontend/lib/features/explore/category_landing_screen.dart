import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
        foregroundColor: AppColors.navy,
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
            Text(
              spec.pageTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              spec.pageSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ContentWidth(
        child: category == DiscoveryCategory.all
            ? _AllSeafoodBody(spec: spec, items: items)
            : _CategoryBody(category: category, spec: spec, items: items),
      ),
    );
  }
}

class _CategoryBody extends StatelessWidget {
  const _CategoryBody({
    required this.category,
    required this.spec,
    required this.items,
  });

  final DiscoveryCategory category;
  final DiscoveryCategorySpec spec;
  final List<SeafoodSummary> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _HeroBanner(spec: spec),
        const SizedBox(height: 14),
        _WhyCard(spec: spec),
        const SizedBox(height: 18),
        if (spec.picksEyebrow.isNotEmpty) ...[
          Text(
            '${items.length} ${spec.picksEyebrow}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.navy,
            ),
          ),
          if (spec.picksSubtitle.isNotEmpty)
            Text(
              spec.picksSubtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          const SizedBox(height: 12),
        ],
        if (items.isEmpty)
          SoftCard(
            child: Text(
              'No supported seafood matches ${spec.title.toLowerCase()} yet. '
              'Try another category or view the full list.',
            ),
          )
        else
          _FishCardRows(
            category: category,
            items: items,
            heroEveryThird: category.cookingMethod != null,
          ),
      ],
    );
  }
}

class _AllSeafoodBody extends StatefulWidget {
  const _AllSeafoodBody({required this.spec, required this.items});

  final DiscoveryCategorySpec spec;
  final List<SeafoodSummary> items;

  @override
  State<_AllSeafoodBody> createState() => _AllSeafoodBodyState();
}

class _AllSeafoodBodyState extends State<_AllSeafoodBody> {
  final Map<String, GlobalKey> _letterKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String letter) {
    return _letterKeys.putIfAbsent(letter, GlobalKey.new);
  }

  Future<void> _jumpTo(String letter) async {
    final BuildContext? target = _keyFor(letter).currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0.05,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<SeafoodSummary>> groups =
        DiscoveryCatalog.groupedByLetter(widget.items);
    final List<String> letters = groups.keys.toList()..sort();
    return SizedBox.expand(
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 28, 32),
            children: [
              _HeroBanner(spec: widget.spec, tall: true),
              const SizedBox(height: 14),
              _CatalogueStats(spec: widget.spec, count: widget.items.length),
              const SizedBox(height: 12),
              if (widget.items.isEmpty)
                const SoftCard(
                  child: Text('No supported seafood is in the catalogue yet.'),
                )
              else
                for (final String letter in letters)
                  KeyedSubtree(
                    key: _keyFor(letter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            letter,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        _FishCardRows(
                          category: DiscoveryCategory.all,
                          items: groups[letter]!,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
          Positioned(
            right: 0,
            top: 220,
            bottom: 24,
            child: _LetterRail(present: letters, onSelect: _jumpTo),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.spec, this.tall = false});

  final DiscoveryCategorySpec spec;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final bool better = spec.id == DiscoveryCategory.sustainable;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: tall ? 248 : (better ? 236 : 228),
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              spec.bannerAsset,
              fit: BoxFit.cover,
              alignment: better
                  ? const Alignment(0.55, 0)
                  : const Alignment(0.35, 0),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: better
                      ? const <Color>[
                          Color(0xF50B3A36),
                          Color(0xCC0E4540),
                          Color(0x880E4540),
                          Color(0x330E4540),
                          Color(0x000E4540),
                        ]
                      : const <Color>[
                          Color(0xF2082433),
                          Color(0xCC082433),
                          Color(0x88082433),
                          Color(0x33082433),
                          Color(0x00082433),
                        ],
                  stops: const <double>[0, 0.32, 0.5, 0.72, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
              child: FractionallySizedBox(
                widthFactor: 0.5,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISCOVER',
                      style: TextStyle(
                        color: better
                            ? const Color(0xFF7EE0D6)
                            : const Color(0xFFFFC14D),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spec.heroTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        height: 1.12,
                      ),
                    ),
                    if (spec.heroLead.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        spec.heroLead,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        spec.heroBody,
                        maxLines: spec.heroLead.isEmpty ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Text(
                      spec.scriptLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dancingScript(
                        color: better
                            ? const Color(0xFFD8F5F1)
                            : const Color(0xFFE8F4F2),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    if (better)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        height: 3,
                        width: 92,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7EE0D6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.spec});

  final DiscoveryCategorySpec spec;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spec.whyTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.navy,
            ),
          ),
          if (spec.whyBody.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              spec.whyBody,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (spec.whyFacts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final WhyFact fact in spec.whyFacts)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE7F6F3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _whyIcon(fact),
                              color: AppColors.tealDark,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fact.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: AppColors.navy,
                            ),
                          ),
                          if (fact.body.isNotEmpty)
                            Text(
                              fact.body,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                                height: 1.25,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Literals here so Flutter web icon tree-shaking keeps the glyphs.
  static IconData _whyIcon(WhyFact fact) {
    return switch (fact.title) {
      'Healthier oceans' => Icons.public,
      'Supports local communities' => Icons.people,
      'A brighter tomorrow' => Icons.eco_outlined,
      'Local favourites' => Icons.location_on_outlined,
      'Market staples' => Icons.storefront_outlined,
      'Commonly found' => Icons.eco_outlined,
      _ => fact.icon,
    };
  }
}

class _CatalogueStats extends StatelessWidget {
  const _CatalogueStats({required this.spec, required this.count});

  final DiscoveryCategorySpec spec;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count species',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.navy,
                  ),
                ),
                const Text(
                  'Explore every supported fish species in SukaSeafood.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          for (final WhyFact fact in spec.whyFacts)
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Icon(fact.icon, color: AppColors.tealDark, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    fact.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: AppColors.navy,
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

class _FishCardRows extends StatelessWidget {
  const _FishCardRows({
    required this.category,
    required this.items,
    this.heroEveryThird = false,
  });

  final DiscoveryCategory category;
  final List<SeafoodSummary> items;
  final bool heroEveryThird;

  @override
  Widget build(BuildContext context) {
    if (!heroEveryThird) {
      return _pairedRows(items, featuredLast: false);
    }

    final List<Widget> children = <Widget>[];
    int i = 0;
    while (i < items.length) {
      final int left = items.length - i;
      if (left >= 3) {
        children.add(_pair(items[i], items[i + 1]));
        children.add(const SizedBox(height: 12));
        children.add(
          _FishPickCard(category: category, item: items[i + 2], featured: true),
        );
        if (i + 3 < items.length) children.add(const SizedBox(height: 12));
        i += 3;
      } else if (left == 2) {
        children.add(_pair(items[i], items[i + 1]));
        i += 2;
      } else {
        children.add(_FishPickCard(category: category, item: items[i]));
        i += 1;
      }
    }
    return Column(children: children);
  }

  Widget _pairedRows(List<SeafoodSummary> rows, {required bool featuredLast}) {
    final bool splitLast = featuredLast && rows.length.isOdd;
    final int pairCount = splitLast ? rows.length - 1 : rows.length;
    return Column(
      children: [
        for (int i = 0; i < pairCount; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < rows.length || splitLast ? 12 : 0,
            ),
            child: _pair(rows[i], i + 1 < pairCount ? rows[i + 1] : null),
          ),
        if (splitLast)
          _FishPickCard(category: category, item: rows.last, featured: true),
      ],
    );
  }

  Widget _pair(SeafoodSummary left, SeafoodSummary? right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _FishPickCard(category: category, item: left),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: right == null
              ? const SizedBox.shrink()
              : _FishPickCard(category: category, item: right),
        ),
      ],
    );
  }
}

class _LetterRail extends StatelessWidget {
  const _LetterRail({required this.present, required this.onSelect});

  final List<String> present;
  final ValueChanged<String> onSelect;

  static const List<String> _index = <String>[
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final String letter in _index)
          Expanded(
            child: _LetterRailButton(
              letter: letter,
              enabled: present.contains(letter),
              onSelect: onSelect,
            ),
          ),
      ],
    );
  }
}

class _LetterRailButton extends StatelessWidget {
  const _LetterRailButton({
    required this.letter,
    required this.enabled,
    required this.onSelect,
  });

  final String letter;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: enabled ? 'Jump to $letter' : '$letter, no seafood',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? () => onSelect(letter) : null,
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? AppColors.tealDark
                  : AppColors.muted.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _FishPickCard extends StatelessWidget {
  const _FishPickCard({
    required this.category,
    required this.item,
    this.featured = false,
  });

  final DiscoveryCategory category;
  final SeafoodSummary item;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final bool saved = catalog.isFavourite(item.fishId);
    final String blurb = DiscoveryCatalog.blurbFor(item, category);
    final List<String> tags = DiscoveryCatalog.tagsFor(item, category);
    final String? fit = DiscoveryCatalog.fitLabel(item, category);
    final bool showFitRow = category.cookingMethod != null;
    final bool showSustainableChoice =
        category == DiscoveryCategory.sustainable;
    final double photoHeight = featured ? 148 : 70;
    final String english = item.displayNameEn.trim();
    final String cardTitle =
        showSustainableChoice &&
            english.isNotEmpty &&
            english.toLowerCase() != item.shortName.toLowerCase()
        ? '${item.shortName} ($english)'
        : item.shortName;

    final Widget blurbText = Text(
      blurb,
      style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.ink),
    );

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            CatalogueFishArt(
              fishId: item.fishId,
              networkUrl: item.imageUrl,
              width: double.infinity,
              height: photoHeight,
              borderRadius: 14,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 6,
              right: 6,
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
          cardTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppColors.navy,
            height: 1.15,
          ),
        ),
        Text(
          item.scientificName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
        if (showSustainableChoice)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(Icons.eco, size: 14, color: AppColors.tealDark),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Sustainable Choice',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (showFitRow && fit != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(
                  _fitIcon(category),
                  size: 14,
                  color: const Color(0xFFE07A2F),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE07A2F),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: blurbText,
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final String tag in tags.take(2)) _TagChip(label: tag),
          ],
        ),
      ],
    );

    final Widget card = SoftCard(
      padding: const EdgeInsets.all(8),
      onTap: () => context.push('/seafood/${item.fishId}'),
      child: body,
    );
    if (!featured) return card;
    return Semantics(
      label: 'Featured pick',
      button: true,
      excludeSemantics: true,
      onTap: () => context.push('/seafood/${item.fishId}'),
      child: card,
    );
  }

  static IconData _fitIcon(DiscoveryCategory category) {
    return switch (category) {
      DiscoveryCategory.grill => Icons.local_fire_department,
      DiscoveryCategory.curry => Icons.soup_kitchen_outlined,
      DiscoveryCategory.steam => Icons.air,
      DiscoveryCategory.fry => Icons.breakfast_dining_outlined,
      DiscoveryCategory.soup => Icons.ramen_dining_outlined,
      DiscoveryCategory.bake => Icons.kitchen_outlined,
      DiscoveryCategory.raw => Icons.set_meal_outlined,
      _ => Icons.restaurant_outlined,
    };
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final String? rating = _wwfRating(label);
    final Color color = rating != null
        ? AppTheme.classificationColor(rating)
        : AppColors.tealDark;
    final Color background = rating != null
        ? AppTheme.classificationSoft(rating)
        : AppColors.tealSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static String? _wwfRating(String label) {
    if (!label.toUpperCase().startsWith('WWF')) return null;
    final String rest = label.substring(3).trim().toUpperCase();
    return rest.isEmpty ? null : rest;
  }
}
