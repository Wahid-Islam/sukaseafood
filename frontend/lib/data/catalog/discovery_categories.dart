import 'package:flutter/material.dart';

import '../models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';

/// Curated Discovery groupings. Filters never invent ratings.
enum DiscoveryCategory {
  all,
  popular,
  sustainable,
  grill,
  curry,
  steam,
  fry,
  soup,
  bake,
  raw;

  /// Canonical cooking-method code used by `suitable_methods`, or null.
  String? get cookingMethod => switch (this) {
    DiscoveryCategory.grill => 'grill',
    DiscoveryCategory.curry => 'curry',
    DiscoveryCategory.steam => 'steam',
    DiscoveryCategory.fry => 'fry',
    DiscoveryCategory.soup => 'soup',
    DiscoveryCategory.bake => 'bake',
    DiscoveryCategory.raw => 'raw',
    DiscoveryCategory.all ||
    DiscoveryCategory.popular ||
    DiscoveryCategory.sustainable => null,
  };
}

class WhyFact {
  const WhyFact({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

class DiscoveryCategorySpec {
  const DiscoveryCategorySpec({
    required this.id,
    required this.title,
    required this.subtitle,
    this.navTitle,
    this.navSubtitle,
    required this.heroTitle,
    this.heroLead = '',
    required this.heroBody,
    required this.scriptLine,
    required this.tileAsset,
    required this.bannerAsset,
    required this.whyTitle,
    required this.whyBody,
    required this.whyFacts,
    required this.picksEyebrow,
    required this.picksSubtitle,
  });

  final DiscoveryCategory id;
  final String title;
  final String subtitle;
  final String? navTitle;
  final String? navSubtitle;
  final String heroTitle;
  final String heroLead;
  final String heroBody;
  final String scriptLine;
  final String tileAsset;
  final String bannerAsset;
  final String whyTitle;
  final String whyBody;
  final List<WhyFact> whyFacts;
  final String picksEyebrow;
  final String picksSubtitle;

  String get pageTitle => navTitle ?? title;
  String get pageSubtitle => navSubtitle ?? subtitle;
}

class PopularCardCopy {
  const PopularCardCopy({required this.blurb, required this.tags});

  final String blurb;
  final List<String> tags;
}

class DiscoveryCatalog {
  DiscoveryCatalog._();

  static const int pageSize = 6;

  static const List<DiscoveryCategory> exploreTiles = <DiscoveryCategory>[
    DiscoveryCategory.popular,
    DiscoveryCategory.sustainable,
    DiscoveryCategory.grill,
    DiscoveryCategory.curry,
    DiscoveryCategory.steam,
    DiscoveryCategory.fry,
  ];

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

  static const Map<String, PopularCardCopy>
  popularCopy = <String, PopularCardCopy>{
    'SF001': PopularCardCopy(
      blurb:
          'An everyday Malaysian favourite — affordable, tasty and versatile.',
      tags: <String>['Affordable', 'Versatile'],
    ),
    'SF003': PopularCardCopy(
      blurb:
          'Firm texture and rich flavour, popular at home and in restaurants.',
      tags: <String>['Rich Flavour', 'Popular'],
    ),
    'SF014': PopularCardCopy(
      blurb:
          'A local favourite with mild flavour and plenty of cooking options.',
      tags: <String>['Mild Taste', 'Family Favourite'],
    ),
    'SF012': PopularCardCopy(
      blurb:
          'Loved for its firm texture and rich taste, especially in local dishes.',
      tags: <String>['Rich Taste', 'Popular in Local Dishes'],
    ),
    'SF007': PopularCardCopy(
      blurb: 'A familiar market fish, especially popular grilled or stuffed.',
      tags: <String>['Great for Grilling', 'Local Favourite'],
    ),
    'SF011': PopularCardCopy(
      blurb:
          'An affordable, everyday fish commonly enjoyed in Malaysian homes.',
      tags: <String>['Affordable', 'Widely Available'],
    ),
    'SF004': PopularCardCopy(
      blurb: 'Widely available, affordable and easy to prepare in many styles.',
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
      heroTitle: "Malaysia's seafood, all in one place",
      heroBody:
          'From familiar favourites to hidden gems, explore all fish species supported in SukaSeafood.',
      scriptLine: 'Same Oceans Brighter Tomorrows',
      tileAsset: 'assets/images/explore/banner_all.jpg',
      bannerAsset: 'assets/images/explore/banner_all.jpg',
      whyTitle: '54 species',
      whyBody: 'Explore every supported fish species in SukaSeafood.',
      whyFacts: <WhyFact>[
        WhyFact(
          icon: Icons.diversity_3_outlined,
          title: 'A diverse range',
          body: '',
        ),
        WhyFact(
          icon: Icons.eco_outlined,
          title: 'Sustainability insights',
          body: '',
        ),
        WhyFact(
          icon: Icons.soup_kitchen_outlined,
          title: 'Cooking inspiration',
          body: '',
        ),
      ],
      picksEyebrow: '',
      picksSubtitle: '',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.popular,
      title: 'Popular in Malaysia',
      subtitle: 'Local favourites, loved across the country.',
      heroTitle: 'A Taste of Malaysia',
      heroBody: 'Seafood loved across Malaysian markets and home kitchens.',
      scriptLine: 'Same Oceans Brighter Futures',
      tileAsset: 'assets/images/explore/category_popular.jpg',
      bannerAsset: 'assets/images/explore/banner_popular.jpg',
      whyTitle: 'Why these fish?',
      whyBody: 'Familiar names. Everyday choices. Real Malaysian favourites.',
      whyFacts: <WhyFact>[
        WhyFact(
          icon: Icons.location_on_outlined,
          title: 'Local favourites',
          body: '',
        ),
        WhyFact(
          icon: Icons.storefront_outlined,
          title: 'Market staples',
          body: '',
        ),
        WhyFact(icon: Icons.eco_outlined, title: 'Commonly found', body: ''),
      ],
      picksEyebrow: '',
      picksSubtitle: '',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.sustainable,
      title: 'Better Choices',
      subtitle: 'More sustainable options for healthier oceans.',
      navTitle: 'For Sustainable Choices',
      navSubtitle: 'Good for our oceans',
      heroTitle: 'Good sustainable choices',
      heroBody: 'Delicious seafood today, healthier oceans tomorrow.',
      scriptLine: 'Choose Seafood Choose a Brighter Future',
      tileAsset: 'assets/images/explore/category_better.jpg',
      bannerAsset: 'assets/images/explore/banner_better.jpg',
      whyTitle: 'Why sustainable seafood?',
      whyBody: 'Better for oceans, communities and future generations.',
      whyFacts: <WhyFact>[
        WhyFact(
          icon: Icons.public,
          title: 'Healthier oceans',
          body: 'Helps protect marine ecosystems',
        ),
        WhyFact(
          icon: Icons.people,
          title: 'Supports local communities',
          body: 'Sustains livelihoods and coastal economies',
        ),
        WhyFact(
          icon: Icons.eco_outlined,
          title: 'A brighter tomorrow',
          body: 'Ensures seafood for future generations',
        ),
      ],
      picksEyebrow: 'sustainable picks',
      picksSubtitle: 'Great choices for you and our oceans.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.grill,
      title: 'For Grilling',
      subtitle: 'Fish that love the flame.',
      heroTitle: 'Fire up the grill',
      heroLead: 'Fish that love the flame.',
      heroBody:
          'Firm, flavourful seafood that holds up beautifully on the grill.',
      scriptLine: 'Great Seafood Greater Moments',
      tileAsset: 'assets/images/explore/category_grill.jpg',
      bannerAsset: 'assets/images/explore/banner_grill.jpg',
      whyTitle: 'Why these fish?',
      whyBody: 'Chosen for their grilling qualities.',
      whyFacts: <WhyFact>[
        WhyFact(
          icon: Icons.whatshot_outlined,
          title: 'Firm flesh',
          body: 'Holds together over high heat',
        ),
        WhyFact(
          icon: Icons.air,
          title: 'Rich flavour',
          body: 'Works beautifully with smoke and char',
        ),
        WhyFact(
          icon: Icons.outdoor_grill_outlined,
          title: 'Whole or fillet',
          body: 'Easy to cook your way',
        ),
      ],
      picksEyebrow: 'seafood picks',
      picksSubtitle: 'Great for the grill. Great on your plate.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.curry,
      title: 'For Curry',
      subtitle: 'Perfect for local dishes.',
      heroTitle: 'Made for curry',
      heroLead: 'Fish that hold their own in the sauce.',
      heroBody:
          'Rich, flavourful seafood that works beautifully with Malaysian curries.',
      scriptLine: 'Same Oceans Richer Flavours',
      tileAsset: 'assets/images/explore/category_curry.jpg',
      bannerAsset: 'assets/images/explore/banner_curry.jpg',
      whyTitle: 'Why these fish?',
      whyBody: 'Chosen for their curry qualities.',
      whyFacts: <WhyFact>[
        WhyFact(
          icon: Icons.set_meal_outlined,
          title: 'Firm texture',
          body: 'Stays together in the sauce',
        ),
        WhyFact(
          icon: Icons.eco_outlined,
          title: 'Flavour friendly',
          body: 'Works with rich spices and herbs',
        ),
        WhyFact(
          icon: Icons.soup_kitchen_outlined,
          title: 'Sauce ready',
          body: 'Absorbs curry without falling apart',
        ),
      ],
      picksEyebrow: 'seafood picks',
      picksSubtitle: 'Perfect for curries. Great on your plate.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.steam,
      title: 'For Steaming',
      subtitle: 'Light and healthy choices.',
      heroTitle: 'Let the fish shine',
      heroBody:
          'Fresh, delicate seafood that stays moist and tender when steamed.',
      scriptLine: 'Simple Cooking Extraordinary Flavour',
      tileAsset: 'assets/images/explore/category_steam.jpg',
      bannerAsset: 'assets/images/explore/banner_steam.jpg',
      whyTitle: 'Why these fish?',
      whyBody: 'Chosen for their steaming qualities.',
      whyFacts: <WhyFact>[
        WhyFact(
          icon: Icons.water_drop_outlined,
          title: 'Delicate & moist',
          body: 'Steaming keeps the flesh tender',
        ),
        WhyFact(
          icon: Icons.eco_outlined,
          title: 'Clean flavour',
          body: "Lets the fish's natural taste shine",
        ),
        WhyFact(
          icon: Icons.rice_bowl_outlined,
          title: 'Whole or fillet',
          body: 'Simple cooking, minimal fuss',
        ),
      ],
      picksEyebrow: 'seafood picks',
      picksSubtitle: 'Perfect for steaming. Great on your plate.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.fry,
      title: 'For Frying',
      subtitle: 'Crispy, flavourful favourites.',
      heroTitle: 'Crisp in the pan',
      heroBody: 'Seafood that fries evenly and stays flavourful in a hot pan.',
      scriptLine: 'Everyday Favourites Golden Moments',
      tileAsset: 'assets/images/explore/category_fry.jpg',
      bannerAsset: 'assets/images/explore/banner_fry.jpg',
      whyTitle: 'Why these fish?',
      whyBody: 'Chosen for their frying qualities.',
      whyFacts: <WhyFact>[
        WhyFact(
          icon: Icons.local_fire_department_outlined,
          title: 'Crispy skin',
          body: 'Takes a hot pan without drying out',
        ),
        WhyFact(
          icon: Icons.restaurant_outlined,
          title: 'Even cooking',
          body: 'Small whole fish and firm cuts fry well',
        ),
        WhyFact(
          icon: Icons.set_meal_outlined,
          title: 'Whole or fillet',
          body: 'Easy weeknight frying',
        ),
      ],
      picksEyebrow: 'seafood picks',
      picksSubtitle: 'Great for frying. Great on your plate.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.soup,
      title: 'For Soup',
      subtitle: 'Broth and stock',
      heroTitle: 'Better for soup',
      heroBody: 'Species with a recorded soup suitability of 4 or more.',
      scriptLine: 'Same Oceans Brighter Futures',
      tileAsset: 'assets/images/explore/banner_all.jpg',
      bannerAsset: 'assets/images/explore/banner_all.jpg',
      whyTitle: 'Why these fish?',
      whyBody: 'Chosen for their soup qualities.',
      whyFacts: <WhyFact>[],
      picksEyebrow: 'seafood picks',
      picksSubtitle: 'Great for soup.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.bake,
      title: 'For Baking',
      subtitle: 'Oven-ready cuts',
      heroTitle: 'Better for baking',
      heroBody: 'Species with a recorded baking suitability of 4 or more.',
      scriptLine: 'Same Oceans Brighter Futures',
      tileAsset: 'assets/images/explore/banner_all.jpg',
      bannerAsset: 'assets/images/explore/banner_all.jpg',
      whyTitle: 'Why these fish?',
      whyBody: 'Chosen for their baking qualities.',
      whyFacts: <WhyFact>[],
      picksEyebrow: 'seafood picks',
      picksSubtitle: 'Great for baking.',
    ),
    DiscoveryCategorySpec(
      id: DiscoveryCategory.raw,
      title: 'For Raw',
      subtitle: 'Sashimi-grade only',
      heroTitle: 'Better served raw',
      heroBody:
          'Species with a recorded raw or cured suitability of 4 or more.',
      scriptLine: 'Same Oceans Brighter Futures',
      tileAsset: 'assets/images/explore/banner_all.jpg',
      bannerAsset: 'assets/images/explore/banner_all.jpg',
      whyTitle: 'Why these fish?',
      whyBody: 'Only species scored for raw or cured service.',
      whyFacts: <WhyFact>[],
      picksEyebrow: 'seafood picks',
      picksSubtitle: 'Sashimi-grade handling required.',
    ),
  ];

  static DiscoveryCategory? parse(String? raw) {
    final String key = (raw ?? '').trim().toLowerCase();
    for (final DiscoveryCategory value in DiscoveryCategory.values) {
      if (value.name == key) return value;
    }
    return null;
  }

  static DiscoveryCategorySpec specFor(DiscoveryCategory category) {
    return categories.firstWhere((DiscoveryCategorySpec e) => e.id == category);
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
        final List<SeafoodSummary> sorted = List<SeafoodSummary>.from(pool)
          ..sort(
            (SeafoodSummary a, SeafoodSummary b) =>
                a.shortName.toLowerCase().compareTo(b.shortName.toLowerCase()),
          );
        return sorted;
      case DiscoveryCategory.popular:
        return <SeafoodSummary>[
          for (final String id in popularIds)
            ...pool.where((SeafoodSummary e) => e.fishId.toUpperCase() == id),
        ];
      case DiscoveryCategory.sustainable:
        return pool.where(_isGoodChoice).toList();
      case DiscoveryCategory.grill:
      case DiscoveryCategory.curry:
      case DiscoveryCategory.steam:
      case DiscoveryCategory.fry:
      case DiscoveryCategory.soup:
      case DiscoveryCategory.bake:
      case DiscoveryCategory.raw:
        final String method = category.cookingMethod!;
        return pool
            .where((SeafoodSummary e) => e.suitableMethods.contains(method))
            .toList();
    }
  }

  static String letterFor(SeafoodSummary item) {
    final String ch = item.shortName.trim().isEmpty
        ? ''
        : item.shortName.trim()[0].toUpperCase();
    final bool az = ch.compareTo('A') >= 0 && ch.compareTo('Z') <= 0;
    return az ? ch : '#';
  }

  static Map<String, List<SeafoodSummary>> groupedByLetter(
    List<SeafoodSummary> items,
  ) {
    final Map<String, List<SeafoodSummary>> groups =
        <String, List<SeafoodSummary>>{};
    for (final SeafoodSummary item in items) {
      groups.putIfAbsent(letterFor(item), () => <SeafoodSummary>[]).add(item);
    }
    for (final List<SeafoodSummary> group in groups.values) {
      group.sort(
        (SeafoodSummary a, SeafoodSummary b) =>
            a.shortName.toLowerCase().compareTo(b.shortName.toLowerCase()),
      );
    }
    return groups;
  }

  static String blurbFor(SeafoodSummary item, DiscoveryCategory category) {
    if (category == DiscoveryCategory.popular) {
      final PopularCardCopy? copy = popularCopy[item.fishId.toUpperCase()];
      if (copy != null) return copy.blurb;
    }
    final String recorded = item.description.trim();
    if (recorded.isNotEmpty) return recorded;
    final String type = item.fishType.trim();
    if (type.isNotEmpty) {
      return '${item.shortName} is a recorded ${type.toLowerCase()}.';
    }
    return '${item.shortName} is a recorded species in the SukaSeafood catalogue.';
  }

  static String? fitLabel(SeafoodSummary item, DiscoveryCategory category) {
    final String? method = category.cookingMethod;
    if (method == null) return null;
    final int? score = item.cookingScores[method];
    if (score == null || score < 1 || score > 5) return null;
    final String name = '${method[0].toUpperCase()}${method.substring(1)}';
    return '$name fit $score/5';
  }

  /// Full-width hero on cooking landings: items 3, 6, 9, …
  static bool isCookingHero(int index) => (index + 1) % 3 == 0;

  static List<String> tagsFor(SeafoodSummary item, DiscoveryCategory category) {
    if (category == DiscoveryCategory.popular) {
      final PopularCardCopy? copy = popularCopy[item.fishId.toUpperCase()];
      if (copy != null) return copy.tags;
    }
    final List<String> tags = <String>[];
    final String label = (item.classification ?? '').toUpperCase();
    if (category != DiscoveryCategory.sustainable &&
        (label == 'GOOD CHOICE' || label == 'BEST CHOICE')) {
      tags.add('WWF Good Choice');
    }
    for (final String method in item.suitableMethods) {
      final String? tag = switch (method) {
        'grill' => 'Great for Grilling',
        'curry' => 'Great for Curry',
        'steam' => 'Great for Steaming',
        'fry' => 'Great for Frying',
        'soup' => 'Great for Soup',
        'bake' => 'Great for Baking',
        'raw' => 'Great served raw',
        _ => null,
      };
      if (tag != null) tags.add(tag);
    }
    if (category == DiscoveryCategory.all && tags.isEmpty) {
      tags.add('Versatile');
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
