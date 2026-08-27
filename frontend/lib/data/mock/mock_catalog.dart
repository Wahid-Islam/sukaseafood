/// Domain models for UI (PocketBase collections later).
class SeafoodItem {
  const SeafoodItem({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.alsoKnownAs,
    required this.fishType,
    required this.commonIn,
    required this.marketAvailability,
    required this.about,
    required this.imageUrl,
    required this.classification,
    required this.classificationBlurb,
    required this.whyGood,
    required this.priceRm,
    required this.priceLow,
    required this.priceHigh,
    required this.priceChangePct,
    required this.cookingMethods,
    required this.aliases,
    this.featured = false,
  });

  final String id;
  final String commonName;
  final String scientificName;
  final String alsoKnownAs;
  final String fishType;
  final String commonIn;
  final String marketAvailability;
  final String about;
  final String imageUrl;
  final String classification;
  final String classificationBlurb;
  final List<String> whyGood;
  final double priceRm;
  final double priceLow;
  final double priceHigh;
  final double priceChangePct;
  final List<String> cookingMethods;
  final List<String> aliases;
  final bool featured;
}

class PricePoint {
  const PricePoint(this.label, this.price);
  final String label;
  final double price;
}

class MockCatalog {
  MockCatalog._();

  static const String heroBoat =
      'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=80';
  static const String cookingDish =
      'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=1200&q=80';
  static const String grilled =
      'https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=800&q=80';

  static final List<SeafoodItem> items = [
    SeafoodItem(
      id: 'tenggiri',
      commonName: 'Tenggiri',
      scientificName: 'Scomberomorus spp.',
      alsoKnownAs: 'Spanish mackerel',
      fishType: 'Pelagic Fish',
      commonIn: 'Malaysia',
      marketAvailability: 'Year-round',
      about:
          'A firm, flavourful mackerel popular across Malaysian markets and coastal kitchens.',
      imageUrl:
          'https://images.unsplash.com/photo-1534766555764-ce878a5e3a2b?auto=format&fit=crop&w=1000&q=80',
      classification: 'GOOD CHOICE',
      classificationBlurb:
          'Tenggiri is a good choice for you and our oceans.',
      whyGood: const [
        'Abundant in local waters',
        'Supports responsible fishing',
        'Good value for everyday meals',
      ],
      priceRm: 28,
      priceLow: 24,
      priceHigh: 32,
      priceChangePct: -3,
      cookingMethods: const ['grilling', 'curry', 'pan-fry'],
      aliases: const ['tenggiri', 'spanish mackerel'],
      featured: true,
    ),
    SeafoodItem(
      id: 'selar',
      commonName: 'Selar',
      scientificName: 'Atule mate',
      alsoKnownAs: 'Scad',
      fishType: 'Pelagic Fish',
      commonIn: 'Malaysia',
      marketAvailability: 'Year-round',
      about:
          'A versatile, mild-flavoured fish that shines in many dishes.',
      imageUrl:
          'https://images.unsplash.com/photo-1510130387422-82bed34b37e9?auto=format&fit=crop&w=1000&q=80',
      classification: 'GOOD CHOICE',
      classificationBlurb: 'Selar is a good choice for you and our oceans.',
      whyGood: const [
        'Abundant in Malaysian waters',
        'Often caught with lower-impact purse seine',
        'Affordable everyday option',
      ],
      priceRm: 21,
      priceLow: 18,
      priceHigh: 24,
      priceChangePct: -5,
      cookingMethods: const ['grilling', 'soup', 'stir-fry', 'curry'],
      aliases: const ['selar', 'scad', 'atule mate'],
    ),
    SeafoodItem(
      id: 'kembung',
      commonName: 'Kembung',
      scientificName: 'Rastrelliger kanagurta',
      alsoKnownAs: 'Indian mackerel',
      fishType: 'Pelagic Fish',
      commonIn: 'Malaysia',
      marketAvailability: 'Year-round',
      about: 'A classic wet-market favourite for goreng and gulai.',
      imageUrl:
          'https://images.unsplash.com/photo-1600699277512-846c1bfa8d2b?auto=format&fit=crop&w=1000&q=80',
      classification: 'GOOD CHOICE',
      classificationBlurb: 'Kembung is a solid everyday sustainable pick.',
      whyGood: const [
        'Widely available',
        'Familiar local favourite',
        'Works across many recipes',
      ],
      priceRm: 18.5,
      priceLow: 15,
      priceHigh: 22,
      priceChangePct: -5,
      cookingMethods: const ['grilling', 'curry', 'pan-fry', 'soup'],
      aliases: const ['kembung', 'pelaling', 'indian mackerel'],
    ),
    SeafoodItem(
      id: 'ikan_merah',
      commonName: 'Ikan Merah',
      scientificName: 'Lutjanus spp.',
      alsoKnownAs: 'Red snapper',
      fishType: 'Reef / demersal',
      commonIn: 'Malaysia',
      marketAvailability: 'Year-round',
      about: 'Premium steamed-fish favourite — choose carefully.',
      imageUrl:
          'https://images.unsplash.com/photo-1498654077810-12c21d47b6dd?auto=format&fit=crop&w=1000&q=80',
      classification: 'AVOID',
      classificationBlurb:
          'Many snapper fisheries face pressure — prefer better-rated swaps.',
      whyGood: const [
        'Ask about origin and method',
        'Consider tilapia or kembung instead',
        'Verify labels when available',
      ],
      priceRm: 38,
      priceLow: 32,
      priceHigh: 45,
      priceChangePct: 8,
      cookingMethods: const ['steaming', 'grilling', 'soup'],
      aliases: const ['ikan merah', 'red snapper', 'merah'],
    ),
    SeafoodItem(
      id: 'tilapia',
      commonName: 'Tilapia',
      scientificName: 'Oreochromis spp.',
      alsoKnownAs: 'Tilapia',
      fishType: 'Farmed freshwater',
      commonIn: 'Malaysia',
      marketAvailability: 'Year-round',
      about: 'Affordable farmed fish — look for responsible farms / MyGAP.',
      imageUrl:
          'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=1000&q=80',
      classification: 'GOOD CHOICE',
      classificationBlurb: 'Responsibly farmed tilapia is a smart everyday choice.',
      whyGood: const [
        'Often more sustainable than pressured wild stocks',
        'Stable supply',
        'Budget-friendly',
      ],
      priceRm: 12.5,
      priceLow: 10,
      priceHigh: 15,
      priceChangePct: 2,
      cookingMethods: const ['pan-fry', 'soup', 'grilling', 'curry'],
      aliases: const ['tilapia', 'ikan tilapia'],
    ),
    SeafoodItem(
      id: 'tongkol',
      commonName: 'Tongkol',
      scientificName: 'Euthynnus affinis',
      alsoKnownAs: 'Kawakawa tuna',
      fishType: 'Pelagic Fish',
      commonIn: 'Malaysia',
      marketAvailability: 'Year-round',
      about: 'Strong flavour, great for sambal and gulai.',
      imageUrl:
          'https://images.unsplash.com/photo-1551244072-5d12893278ab?auto=format&fit=crop&w=1000&q=80',
      classification: 'REDUCE',
      classificationBlurb: 'Enjoy tongkol less often while better options exist.',
      whyGood: const [
        'Check landing pressure',
        'Swap to kembung when possible',
        'Ask about catch method',
      ],
      priceRm: 16,
      priceLow: 13,
      priceHigh: 19,
      priceChangePct: 4,
      cookingMethods: const ['curry', 'grilling', 'stir-fry'],
      aliases: const ['tongkol', 'kawakawa'],
    ),
    SeafoodItem(
      id: 'siakap',
      commonName: 'Siakap',
      scientificName: 'Lates calcarifer',
      alsoKnownAs: 'Barramundi',
      fishType: 'Coastal / farmed',
      commonIn: 'Malaysia',
      marketAvailability: 'Year-round',
      about: 'Restaurant classic — steamed siakap with soy and ginger.',
      imageUrl:
          'https://images.unsplash.com/photo-1615141982883-c7adab2b8ae2?auto=format&fit=crop&w=1000&q=80',
      classification: 'GOOD CHOICE',
      classificationBlurb: 'Farmed siakap can be a responsible celebration dish.',
      whyGood: const [
        'Often aquaculture-sourced',
        'Familiar cooking methods',
        'Good for sharing meals',
      ],
      priceRm: 26,
      priceLow: 22,
      priceHigh: 30,
      priceChangePct: -2,
      cookingMethods: const ['steaming', 'grilling', 'soup'],
      aliases: const ['siakap', 'barramundi'],
    ),
  ];

  static SeafoodItem byId(String id) =>
      items.firstWhere((SeafoodItem e) => e.id == id);

  static SeafoodItem get featured =>
      items.firstWhere((SeafoodItem e) => e.featured);

  static List<SeafoodItem> search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return items
        .where(
          (SeafoodItem e) =>
              e.commonName.toLowerCase().contains(q) ||
              e.scientificName.toLowerCase().contains(q) ||
              e.aliases.any((String a) => a.contains(q)),
        )
        .toList();
  }

  static List<PricePoint> historyFor(SeafoodItem item) {
    final List<double> wave = <double>[
      item.priceLow,
      item.priceLow + 1.2,
      item.priceRm - 1.5,
      item.priceRm - 0.4,
      item.priceHigh - 1.1,
      item.priceRm,
    ];
    final List<String> labels = <String>[
      '24 Feb',
      '17 Mar',
      '7 Apr',
      '28 Apr',
      '12 May',
      '20 May',
    ];
    return List<PricePoint>.generate(
      wave.length,
      (int i) => PricePoint(labels[i], wave[i]),
    );
  }

  static const List<String> recentSearches = <String>[
    'Kembung',
    'Selar',
    'Tongkol',
    'Siakap',
  ];

  static const List<String> suggestions = <String>[
    'kerisi',
    'kembung',
    'ikan kembung',
    'kembung lelaki',
  ];

  static const List<String> cookingMethods = <String>[
    'grilling',
    'soup',
    'curry',
    'stir-fry',
    'rice dish',
    'others',
  ];
}
