import '../models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';

/// Curated Discovery groupings. Filters never invent ratings.
enum DiscoveryCategory { all, popular, sustainable, grill, curry, steam }

class DiscoveryCategorySpec {
  const DiscoveryCategorySpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.heroTitle,
    required this.heroBody,
  });

  final DiscoveryCategory id;
  final String title;
  final String subtitle;
  final int tint;
  final String heroTitle;
  final String heroBody;
}

class PopularCardCopy {
  const PopularCardCopy({required this.blurb, required this.tags});

  final String blurb;
  final List<String> tags;
}

class DiscoveryCatalog {
  DiscoveryCatalog._();

  static const int pageSize = 6;

  static const List<String> popularIds = <String>[
    'SF001',
    'SF003',
    'SF014',
    'SF012',
    'SF007',
    'SF011',
    'SF004',
    'SF015',
  ];

  static const Map<String, PopularCardCopy> popularCopy =
      <String, PopularCardCopy>{
        'SF001': PopularCardCopy(
          blurb:
              'An everyday Malaysian favourite — affordable, tasty and incredibly versatile.',
          tags: <String>['Affordable', 'Versatile'],
        ),
        'SF003': PopularCardCopy(
          blurb:
              'A popular choice for its firm texture and rich flavour.',
          tags: <String>['Rich Flavour', 'Great for Steaming'],
        ),
        'SF014': PopularCardCopy(
          blurb:
              'A local favourite with mild flavour and plenty of cooking options.',
          tags: <String>['Mild Taste', 'Versatile'],
        ),
        'SF012': PopularCardCopy(
          blurb:
              'Loved for its firm texture and rich taste, especially in local dishes.',
          tags: <String>['Rich Taste', 'Popular in Local Dishes'],
        ),
        'SF007': PopularCardCopy(
          blurb:
              'A familiar market fish, especially popular grilled or stuffed.',
          tags: <String>['Great for Grilling', 'Local Favourite'],
        ),
        'SF011': PopularCardCopy(
          blurb:
              'An affordable, everyday fish commonly enjoyed in Malaysian homes.',
          tags: <String>['Affordable', 'Widely Available'],
        ),
        'SF004': PopularCardCopy(
          blurb:
              'Widely available, affordable and easy to prepare in many styles.',
          tags: <String>['Affordable', 'Family Favourite'],
        ),
        'SF015': PopularCardCopy(
          blurb: 'A versatile tuna commonly used in curries.',
          tags: <String>['Versatile', 'Great for Curries'],
        ),
      };

  static const List<DiscoveryCategorySpec> categories = <DiscoveryCategorySpec>[
    DiscoveryCategorySpec(
      id: DiscoveryCategory.all,
      title: 'All Seafood',
      subtitle: 'Explore our full list',
      tint: 0xFFE8F4FF,
      heroTitle: 'The full catalogue',
      heroBody:
          'Every supported species currently in SukaSeafood — search, scan or open a profile.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.popular,
      title: 'Popular in Malaysia',
      subtitle: 'Local favourites, loved across the country',
      tint: 0xFFFFF3D6,
      heroTitle: 'A Taste of Malaysia',
      heroBody:
          'These are seafood most commonly enjoyed across Malaysia — from local markets to home kitchens.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.sustainable,
      title: 'Good Sustainable Choices',
      subtitle: 'Better for our ocean',
      tint: 0xFFE3F6E8,
      heroTitle: 'Better-rated choices',
      heroBody:
          'Species with a recorded WWF Good Choice or Best Choice rating. Unrated species stay out of this list.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.grill,
      title: 'For Grilling',
      subtitle: 'Great for the BBQ',
      tint: 0xFFFFE8E4,
      heroTitle: 'Better for the grill',
      heroBody:
          'Species with a recorded grilling suitability of 4 or more.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.curry,
      title: 'For Curry',
      subtitle: 'Perfect for local dishes',
      tint: 0xFFFFF0E0,
      heroTitle: 'Better for curry',
      heroBody:
          'Species with a recorded curry suitability of 4 or more.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.steam,
      title: 'For Steaming',
      subtitle: 'Light and healthy',
      tint: 0xFFE7F3FF,
      heroTitle: 'Better for steaming',
      heroBody:
          'Species with a recorded steaming suitability of 4 or more.',
    ),
  ];

  static DiscoveryCategory? parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'all':
        return DiscoveryCategory.all;
      case 'popular':
        return DiscoveryCategory.popular;
      case 'sustainable':
        return DiscoveryCategory.sustainable;
      case 'grill':
        return DiscoveryCategory.grill;
      case 'curry':
        return DiscoveryCategory.curry;
      case 'steam':
        return DiscoveryCategory.steam;
      default:
        return null;
    }
  }

  static DiscoveryCategorySpec specFor(DiscoveryCategory category) {
    return categories.firstWhere(
      (DiscoveryCategorySpec e) => e.id == category,
    );
  }

  static bool isBrowseable(SeafoodSummary item) {
    final bool idOk = RegExp(
      r'^SF\d+$',
      caseSensitive: false,
    ).hasMatch(item.fishId.trim());
    final bool nameOk = item.primaryCommonName.trim().isNotEmpty;
    final bool imageOk =
        (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) ||
        CatalogueFishArt.hasLocalPlate(item.fishId);
    return idOk && nameOk && imageOk;
  }

  static List<SeafoodSummary> browseable(List<SeafoodSummary> items) {
    return items.where(isBrowseable).toList();
  }

  static bool _isGoodChoice(SeafoodSummary item) {
    final String label = (item.classification ?? '').toUpperCase();
    return label == 'GOOD CHOICE' || label == 'BEST CHOICE';
  }

  static List<SeafoodSummary> filter(
    List<SeafoodSummary> items,
    DiscoveryCategory category,
  ) {
    final List<SeafoodSummary> pool = browseable(items);
    switch (category) {
      case DiscoveryCategory.all:
        return pool;
      case DiscoveryCategory.popular:
        final List<SeafoodSummary> picked = <SeafoodSummary>[
          for (final String id in popularIds)
            ...pool.where((SeafoodSummary e) => e.fishId.toUpperCase() == id),
        ];
        return picked;
      case DiscoveryCategory.sustainable:
        return pool.where(_isGoodChoice).toList();
      case DiscoveryCategory.grill:
        return pool
            .where((SeafoodSummary e) => e.suitableMethods.contains('grill'))
            .toList();
      case DiscoveryCategory.curry:
        return pool
            .where((SeafoodSummary e) => e.suitableMethods.contains('curry'))
            .toList();
      case DiscoveryCategory.steam:
        return pool
            .where((SeafoodSummary e) => e.suitableMethods.contains('steam'))
            .toList();
    }
  }

  static String blurbFor(SeafoodSummary item, DiscoveryCategory category) {
    if (category == DiscoveryCategory.popular) {
      final PopularCardCopy? copy = popularCopy[item.fishId.toUpperCase()];
      if (copy != null) return copy.blurb;
    }
    final String recorded = item.description.trim();
    if (recorded.isNotEmpty) return recorded;
    return item.namesSubtitle;
  }

  static List<String> tagsFor(
    SeafoodSummary item,
    DiscoveryCategory category,
  ) {
    if (category == DiscoveryCategory.popular) {
      final PopularCardCopy? copy = popularCopy[item.fishId.toUpperCase()];
      if (copy != null) return copy.tags;
    }
    final List<String> tags = <String>[];
    final String label = (item.classification ?? '').toUpperCase();
    if (label == 'GOOD CHOICE' || label == 'BEST CHOICE') {
      tags.add(label == 'BEST CHOICE' ? 'WWF Best Choice' : 'WWF Good Choice');
    }
    for (final String method in item.suitableMethods) {
      final String? tag = switch (method) {
        'grill' => 'Great for Grilling',
        'curry' => 'Great for Curry',
        'steam' => 'Great for Steaming',
        'fry' => 'Great for Frying',
        _ => null,
      };
      if (tag != null) tags.add(tag);
    }
    return tags.take(2).toList();
  }

  static List<SeafoodSummary> page(
    List<SeafoodSummary> items, {
    required int visibleCount,
  }) {
    if (visibleCount >= items.length) return items;
    return items.take(visibleCount).toList();
  }

  static int swapRank(String? classification) {
    switch ((classification ?? 'UNDETERMINED').toUpperCase()) {
      case 'GOOD CHOICE':
      case 'BEST CHOICE':
        return 0;
      case 'REDUCE':
        return 1;
      case 'AVOID':
        return 2;
      default:
        return 9;
    }
  }

  static List<SeafoodSummary> betterSwaps({
    required SeafoodSummary current,
    required List<SeafoodSummary> catalogue,
  }) {
    final int currentRank = swapRank(current.classification);
    if (currentRank == 0) return const <SeafoodSummary>[];
    return browseable(catalogue)
        .where((SeafoodSummary e) => e.fishId != current.fishId)
        .where((SeafoodSummary e) {
          final int rank = swapRank(e.classification);
          return rank < currentRank;
        })
        .toList()
      ..sort(
        (SeafoodSummary a, SeafoodSummary b) =>
            swapRank(a.classification).compareTo(swapRank(b.classification)),
      );
  }
}
