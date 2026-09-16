import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukaseafood/core/auth/auth_controller.dart';
import 'package:sukaseafood/data/catalog/catalog_controller.dart';
import 'package:sukaseafood/data/catalog/discovery_categories.dart';
import 'package:sukaseafood/data/models/seafood.dart';
import 'package:sukaseafood/data/models/user_profile.dart';
import 'package:sukaseafood/main.dart';

SeafoodSummary _item({
  required String id,
  required String name,
  String classification = 'UNDETERMINED',
  List<String> methods = const <String>[],
  Map<String, int>? cookingScores,
  String image = 'https://example.com/fish.jpg',
  String description = '',
}) {
  return SeafoodSummary(
    fishId: id,
    scientificName: 'Sci $id',
    primaryCommonName: name,
    displayNameEn: '$name EN',
    fishType: 'marine pelagic',
    imageUrl: image,
    classification: classification,
    description: description,
    suitableMethods: methods,
    cookingScores:
        cookingScores ??
        <String, int>{for (final String method in methods) method: 5},
  );
}

void main() {
  test('browseable rows need an id, name and image', () {
    expect(
      DiscoveryCatalog.isBrowseable(_item(id: 'SF001', name: 'Kembung')),
      isTrue,
    );
    expect(
      DiscoveryCatalog.isBrowseable(
        const SeafoodSummary(
          fishId: '',
          scientificName: 'x',
          primaryCommonName: 'Kembung',
          fishType: 'pelagic',
          imageUrl: 'https://example.com/a.jpg',
        ),
      ),
      isFalse,
    );
  });

  test('category filters use recorded ratings and cooking scores only', () {
    final List<SeafoodSummary> items = <SeafoodSummary>[
      _item(id: 'SF001', name: 'Kembung', methods: <String>['grill', 'curry']),
      _item(
        id: 'SF003',
        name: 'Ikan Merah',
        classification: 'REDUCE',
        methods: <String>['steam', 'grill'],
      ),
      _item(
        id: 'SF007',
        name: 'Cencaru',
        classification: 'GOOD CHOICE',
        methods: <String>['grill'],
      ),
      _item(id: 'SF002', name: 'Bawal Hitam', methods: <String>['steam']),
      _item(id: 'SF004', name: 'Tilapia', methods: <String>['fry', 'soup']),
      _item(id: 'SF016', name: 'Pollock', methods: <String>['bake']),
    ];

    expect(
      DiscoveryCatalog.filter(
        items,
        DiscoveryCategory.sustainable,
      ).map((SeafoodSummary e) => e.fishId),
      <String>['SF007'],
    );
    expect(
      DiscoveryCatalog.filter(
        items,
        DiscoveryCategory.grill,
      ).map((SeafoodSummary e) => e.fishId),
      <String>['SF001', 'SF003', 'SF007'],
    );
    expect(
      DiscoveryCatalog.filter(
        items,
        DiscoveryCategory.steam,
      ).map((SeafoodSummary e) => e.fishId),
      <String>['SF003', 'SF002'],
    );
    expect(
      DiscoveryCatalog.filter(
        items,
        DiscoveryCategory.fry,
      ).map((SeafoodSummary e) => e.fishId),
      <String>['SF004'],
    );
    expect(
      DiscoveryCatalog.filter(
        items,
        DiscoveryCategory.soup,
      ).map((SeafoodSummary e) => e.fishId),
      <String>['SF004'],
    );
    expect(
      DiscoveryCatalog.filter(
        items,
        DiscoveryCategory.bake,
      ).map((SeafoodSummary e) => e.fishId),
      <String>['SF016'],
    );
    expect(DiscoveryCatalog.filter(items, DiscoveryCategory.raw), isEmpty);
  });

  test('letter groups stay sorted A to Z inside each letter', () {
    final Map<String, List<SeafoodSummary>> groups =
        DiscoveryCatalog.groupedByLetter(<SeafoodSummary>[
          _item(id: 'SF002', name: 'Belanak'),
          _item(id: 'SF003', name: 'Bawal Hitam'),
          _item(id: 'SF001', name: 'Albacore Tuna'),
        ]);
    expect(groups['A']!.map((SeafoodSummary e) => e.shortName), <String>[
      'Albacore Tuna',
    ]);
    expect(groups['B']!.map((SeafoodSummary e) => e.shortName), <String>[
      'Bawal Hitam',
      'Belanak',
    ]);
  });

  test('popular list uses the eight Malaysia favourites in order', () {
    final List<SeafoodSummary> items = <SeafoodSummary>[
      for (final String id in <String>[
        'SF002',
        'SF001',
        'SF015',
        'SF003',
        'SF014',
        'SF012',
        'SF007',
        'SF011',
        'SF004',
      ])
        _item(id: id, name: id),
    ];
    expect(
      DiscoveryCatalog.filter(
        items,
        DiscoveryCategory.popular,
      ).map((SeafoodSummary e) => e.fishId),
      DiscoveryCatalog.popularIds,
    );
    expect(
      DiscoveryCatalog.blurbFor(
        _item(id: 'SF001', name: 'Kembung'),
        DiscoveryCategory.popular,
      ),
      contains('everyday Malaysian favourite'),
    );
  });

  test('non-popular blurbs and tags stay on recorded fields', () {
    final SeafoodSummary item = _item(
      id: 'SF002',
      name: 'Bawal Hitam',
      classification: 'GOOD CHOICE',
      methods: <String>['steam'],
      description: 'Demersal fish prized for steaming.',
    );
    expect(
      DiscoveryCatalog.blurbFor(item, DiscoveryCategory.steam),
      'Demersal fish prized for steaming.',
    );
    expect(DiscoveryCatalog.tagsFor(item, DiscoveryCategory.steam), <String>[
      'WWF Good Choice',
      'Great for Steaming',
    ]);
    expect(
      DiscoveryCatalog.blurbFor(
        _item(id: 'SF016', name: 'Pollock'),
        DiscoveryCategory.all,
      ),
      'Pollock is a recorded marine pelagic.',
    );
    expect(
      DiscoveryCatalog.tagsFor(item, DiscoveryCategory.sustainable),
      <String>['Great for Steaming'],
    );
    expect(
      DiscoveryCatalog.fitLabel(
        _item(
          id: 'SF007',
          name: 'Cencaru',
          methods: <String>['grill'],
          cookingScores: const <String, int>{'grill': 4},
        ),
        DiscoveryCategory.grill,
      ),
      'Grill fit 4/5',
    );
    expect(
      DiscoveryCatalog.fitLabel(
        _item(id: 'SF004', name: 'Tilapia', methods: <String>['fry']),
        DiscoveryCategory.fry,
      ),
      'Fry fit 5/5',
    );
    expect(
      DiscoveryCatalog.fitLabel(
        _item(
          id: 'SF001',
          name: 'Kembung',
          methods: <String>['grill'],
          cookingScores: const <String, int>{},
        ),
        DiscoveryCategory.grill,
      ),
      isNull,
    );
    expect(DiscoveryCatalog.isCookingHero(0), isFalse);
    expect(DiscoveryCatalog.isCookingHero(1), isFalse);
    expect(DiscoveryCatalog.isCookingHero(2), isTrue);
    expect(DiscoveryCatalog.isCookingHero(5), isTrue);
    expect(
      DiscoveryCatalog.fitLabel(
        _item(id: 'SF001', name: 'Kembung'),
        DiscoveryCategory.grill,
      ),
      isNull,
    );
    expect(
      DiscoveryCatalog.specFor(DiscoveryCategory.sustainable).pageTitle,
      'For Sustainable Choices',
    );
    expect(
      DiscoveryCatalog.specFor(DiscoveryCategory.sustainable).title,
      'Better Choices',
    );
  });

  test('load more pages the visible list', () {
    final List<SeafoodSummary> items = List<SeafoodSummary>.generate(
      8,
      (int i) => _item(id: 'SF00$i', name: 'Fish $i'),
    );
    expect(DiscoveryCatalog.page(items, visibleCount: 6), hasLength(6));
    expect(DiscoveryCatalog.page(items, visibleCount: 12), hasLength(8));
  });

  test('smart swap never treats UNDETERMINED as better', () {
    final SeafoodSummary avoid = _item(
      id: 'SF008',
      name: 'Jenahak',
      classification: 'AVOID',
    );
    final List<SeafoodSummary> swaps = DiscoveryCatalog.betterSwaps(
      current: avoid,
      catalogue: <SeafoodSummary>[
        avoid,
        _item(id: 'SF013', name: 'Unknown'),
        _item(id: 'SF007', name: 'Cencaru', classification: 'GOOD CHOICE'),
      ],
    );
    expect(swaps.map((SeafoodSummary e) => e.fishId).toList(), <String>[
      'SF007',
    ]);
  });

  testWidgets('Discover shows categories, cards and scan entry', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AuthController auth = AuthController.forTesting(
      profile: const UserProfile(
        uid: 'test',
        name: 'Amir',
        email: 'amir@example.com',
        forecastLocationName: 'Selangor',
      ),
    );
    final CatalogController catalog = CatalogController.forTesting(
      items: <SeafoodSummary>[
        _item(
          id: 'SF001',
          name: 'Kembung',
          classification: 'REDUCE',
          methods: <String>['grill'],
        ),
        _item(
          id: 'SF007',
          name: 'Cencaru',
          classification: 'GOOD CHOICE',
          methods: <String>['grill'],
        ),
      ],
    );

    await tester.pumpWidget(
      SukaSeafoodApp(authController: auth, catalogController: catalog),
    );
    await tester.pump();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    expect(find.text('Explore Seafood'), findsOneWidget);
    expect(find.text('Better Choices'), findsOneWidget);
    expect(find.text('Popular in Malaysia'), findsOneWidget);
    expect(find.text('For Grilling'), findsOneWidget);
    expect(find.text('For Curry'), findsOneWidget);
    expect(find.text('For Steaming'), findsOneWidget);
    expect(find.text('For Frying'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Explore the full catalogue')),
      findsOneWidget,
    );
    expect(find.text('Not sure what this is?'), findsOneWidget);
    expect(find.text('See all  >'), findsNothing);
    expect(find.text('For Soup'), findsNothing);
    expect(find.text('For Baking'), findsNothing);
    expect(find.text('For Raw'), findsNothing);

    await tester.tap(find.text('Better Choices'));
    await tester.pumpAndSettle();
    expect(find.text('For Sustainable Choices'), findsOneWidget);
    expect(find.text('Good for our oceans'), findsOneWidget);
    expect(find.text('Why sustainable seafood?'), findsOneWidget);
    expect(find.text('Cencaru EN'), findsNothing);
    expect(find.text('Cencaru (Cencaru EN)'), findsWidgets);
    expect(find.text('Kembung'), findsNothing);
  });

  testWidgets('fish cards show a short description on a phone layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AuthController auth = AuthController.forTesting(
      profile: const UserProfile(
        uid: 'test',
        name: 'Amir',
        email: 'amir@example.com',
        forecastLocationName: 'Selangor',
      ),
    );
    final CatalogController catalog = CatalogController.forTesting(
      items: <SeafoodSummary>[
        _item(
          id: 'SF001',
          name: 'Kembung',
          methods: <String>['grill', 'curry'],
          description: 'Oily fish that holds together in curry sauces.',
        ),
        _item(
          id: 'SF003',
          name: 'Ikan Merah',
          methods: <String>['curry', 'grill'],
          description: 'Firm flesh that stays together in rich sauces.',
        ),
      ],
    );

    await tester.pumpWidget(
      SukaSeafoodApp(authController: auth, catalogController: catalog),
    );
    await tester.pump();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(
      find.text('Local favourites, loved across the country.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Popular in Malaysia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('everyday Malaysian favourite'), findsOneWidget);
    expect(find.text('Kembung'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('For Curry'));
    await tester.tap(find.text('For Curry'));
    await tester.pumpAndSettle();
    expect(find.text('Made for curry'), findsOneWidget);
    expect(find.text('Fish that hold their own in the sauce.'), findsOneWidget);
    expect(
      find.text('Oily fish that holds together in curry sauces.'),
      findsOneWidget,
    );
    expect(find.text('Curry fit 5/5'), findsWidgets);
    expect(
      find.text('Firm flesh that stays together in rich sauces.'),
      findsOneWidget,
    );
  });

  testWidgets('grilling shows X/5 scores and a hero every third fish', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AuthController auth = AuthController.forTesting(
      profile: const UserProfile(
        uid: 'test',
        name: 'Amir',
        email: 'amir@example.com',
        forecastLocationName: 'Selangor',
      ),
    );
    final CatalogController catalog = CatalogController.forTesting(
      items: <SeafoodSummary>[
        _item(
          id: 'SF001',
          name: 'Kembung',
          methods: <String>['grill'],
          cookingScores: const <String, int>{'grill': 5},
        ),
        _item(
          id: 'SF003',
          name: 'Ikan Merah',
          methods: <String>['grill'],
          cookingScores: const <String, int>{'grill': 4},
        ),
        _item(
          id: 'SF015',
          name: 'Tenggiri',
          methods: <String>['grill'],
          cookingScores: const <String, int>{'grill': 5},
        ),
      ],
    );

    await tester.pumpWidget(
      SukaSeafoodApp(authController: auth, catalogController: catalog),
    );
    await tester.pump();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('For Grilling'));
    await tester.tap(find.text('For Grilling'));
    await tester.pumpAndSettle();

    expect(find.text('Grill fit 5/5'), findsNWidgets(2));
    expect(find.text('Grill fit 4/5'), findsOneWidget);
    expect(find.text('Grill fit'), findsNothing);
    expect(find.bySemanticsLabel('Featured pick'), findsOneWidget);
  });

  testWidgets('steaming landing has no recipes banner', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AuthController auth = AuthController.forTesting(
      profile: const UserProfile(
        uid: 'test',
        name: 'Amir',
        email: 'amir@example.com',
        forecastLocationName: 'Selangor',
      ),
    );
    final CatalogController catalog = CatalogController.forTesting(
      items: <SeafoodSummary>[
        _item(
          id: 'SF002',
          name: 'Bawal Hitam',
          methods: <String>['steam'],
          cookingScores: const <String, int>{'steam': 5},
        ),
      ],
    );

    await tester.pumpWidget(
      SukaSeafoodApp(authController: auth, catalogController: catalog),
    );
    await tester.pump();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('For Steaming'));
    await tester.tap(find.text('For Steaming'));
    await tester.pumpAndSettle();

    expect(find.text('Ready to cook?'), findsNothing);
    expect(find.text('Explore recipes'), findsNothing);
    expect(find.text('See simple recipes for this seafood.'), findsNothing);
  });

  testWidgets('favourites page matches the saved-choices layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AuthController auth = AuthController.forTesting(
      profile: const UserProfile(
        uid: 'test',
        name: 'Amir',
        email: 'amir@example.com',
        forecastLocationName: 'Selangor',
      ),
    );
    final CatalogController catalog = CatalogController.forTesting(
      items: <SeafoodSummary>[
        _item(
          id: 'SF003',
          name: 'Ikan Merah',
          classification: 'AVOID',
          methods: <String>['grill', 'curry'],
        ),
      ],
      favourites: <SeafoodSummary>[
        _item(
          id: 'SF003',
          name: 'Ikan Merah',
          classification: 'AVOID',
          methods: <String>['grill', 'curry'],
        ),
      ],
    );

    await tester.pumpWidget(
      SukaSeafoodApp(authController: auth, catalogController: catalog),
    );
    await tester.pump();
    await tester.tap(find.text('Favourites'));
    await tester.pumpAndSettle();

    expect(find.text('Favourites'), findsWidgets);
    expect(find.text('Your saved seafood choices'), findsOneWidget);
    expect(find.textContaining('Same Oceans'), findsNothing);
    expect(find.text('Your favourites, at a glance'), findsOneWidget);
    expect(find.text('Ikan Merah'), findsOneWidget);
    expect(find.text('Sustainability'), findsOneWidget);
    expect(find.text('Overfished'), findsOneWidget);
    expect(find.text('Best for'), findsOneWidget);
    expect(find.text('Grilling, Curry'), findsOneWidget);
    expect(find.text('Common in'), findsOneWidget);
    expect(find.text('Ready to cook?'), findsNothing);
  });

  testWidgets('empty category explains itself and can be cleared', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AuthController auth = AuthController.forTesting(
      profile: const UserProfile(
        uid: 'test',
        name: 'Amir',
        email: 'amir@example.com',
        forecastLocationName: 'Selangor',
      ),
    );
    final CatalogController catalog = CatalogController.forTesting(
      items: <SeafoodSummary>[
        _item(id: 'SF001', name: 'Kembung', classification: 'REDUCE'),
      ],
    );

    await tester.pumpWidget(
      SukaSeafoodApp(authController: auth, catalogController: catalog),
    );
    await tester.pump();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Better Choices'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No supported seafood matches'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Browse by category'), findsOneWidget);
  });

  testWidgets('Fish Bio hub opens the combined Sustainability page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const SeafoodSummary kembung = SeafoodSummary(
      fishId: 'SF001',
      scientificName: 'Rastrelliger kanagurta',
      primaryCommonName: 'Kembung',
      displayNameEn: 'Indian Mackerel',
      fishType: 'marine pelagic',
      imageUrl: 'https://example.com/k.jpg',
      classification: 'REDUCE',
    );
    const SeafoodProfile profile = SeafoodProfile(
      fishId: 'SF001',
      scientificName: 'Rastrelliger kanagurta',
      primaryCommonName: 'Kembung',
      displayNameEn: 'Indian Mackerel',
      fishType: 'marine pelagic',
      family: 'Scombridae',
      commonIn: 'Malaysia',
      marketAvailability: 'Year-round',
      about: 'Everyday oily fish.',
      imageUrl: 'https://example.com/k.jpg',
      sustainability: SustainabilityInfo(
        classification: 'REDUCE',
        origin: 'Malaysia',
        productionMethod: 'Purse seine',
        explanation: 'Applies to purse seine.',
        whyItMatters: 'WWF rates Malaysian Kembung as Reduce.',
        sourceName: 'WWF Save Our Seafood',
        sourceUrl: 'https://www.saveourseafood.my/',
        verified: true,
        assessments: <MethodRating>[
          MethodRating(
            classification: 'REDUCE',
            productionMethod: 'Purse seine',
            productionMethodCode: 'PURSE_SEINE',
            origin: 'Malaysia',
            explanation: 'Applies to purse seine.',
          ),
        ],
      ),
    );

    final AuthController auth = AuthController.forTesting(
      profile: const UserProfile(
        uid: 'test',
        name: 'Amir',
        email: 'amir@example.com',
        forecastLocationName: 'Selangor',
      ),
    );
    final CatalogController catalog = CatalogController.forTesting(
      items: const <SeafoodSummary>[kembung],
      profiles: const <String, SeafoodProfile>{'SF001': profile},
    );

    await tester.pumpWidget(
      SukaSeafoodApp(authController: auth, catalogController: catalog),
    );
    await tester.pump();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popular in Malaysia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kembung').first);
    await tester.pumpAndSettle();

    expect(find.text('Kembung'), findsWidgets);
    expect(find.text('Rastrelliger kanagurta'), findsOneWidget);
    expect(find.text('Sustainability'), findsOneWidget);
    expect(find.text('WWF Sustainability'), findsNothing);
    expect(find.text('Biodiversity Context'), findsNothing);
    expect(find.text('Price Context'), findsOneWidget);
    expect(find.text('Smart Swap & Cooking'), findsOneWidget);
    expect(find.text('Find another seafood'), findsOneWidget);

    final Finder chevrons = find.byIcon(Icons.chevron_right);
    expect(chevrons, findsNWidgets(3));
    final double firstRight = tester.getTopRight(chevrons.at(0)).dx;
    for (int i = 1; i < 3; i++) {
      expect(tester.getTopRight(chevrons.at(i)).dx, closeTo(firstRight, 0.5));
    }

    await tester.tap(find.text('Sustainability'));
    await tester.pumpAndSettle();
    expect(find.text('SUSTAINABILITY'), findsWidgets);
    expect(find.textContaining('WWF Save Our Seafood'), findsWidgets);
    expect(find.text('Why does this fish matter?'), findsOneWidget);
    expect(find.textContaining('Every species plays a role'), findsNothing);
    expect(find.textContaining('Local fish.'), findsNothing);
    expect(find.text('Conservation status'), findsOneWidget);
    expect(find.textContaining('Population trend'), findsNothing);
    expect(find.textContaining('MyBIS:'), findsNothing);
    expect(find.textContaining('Reef Check:'), findsNothing);
    expect(find.textContaining('Better choices today'), findsNothing);
  });

  testWidgets('full catalogue drops Sort A-Z and the letter rail jumps', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const String pollockBlurb =
        'A cold-water schooling whitefish that forms an important catch.';
    const String tunaBlurb =
        'A highly migratory tuna with firm, pale meat, commonly found in markets.';

    final AuthController auth = AuthController.forTesting(
      profile: const UserProfile(
        uid: 'test',
        name: 'Amir',
        email: 'amir@example.com',
        forecastLocationName: 'Selangor',
      ),
    );
    final CatalogController catalog = CatalogController.forTesting(
      items: <SeafoodSummary>[
        _item(id: 'SF016', name: 'Alaskan Pollock', description: pollockBlurb),
        _item(
          id: 'SF018',
          name: 'Albacore Tuna',
          classification: 'GOOD CHOICE',
          methods: <String>['grill'],
          description: tunaBlurb,
        ),
        _item(
          id: 'SF007',
          name: 'Cencaru',
          classification: 'GOOD CHOICE',
          description: 'A firm coastal jack often grilled whole.',
        ),
      ],
    );

    await tester.pumpWidget(
      SukaSeafoodApp(authController: auth, catalogController: catalog),
    );
    await tester.pump();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(RegExp('Explore the full catalogue')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sort: A – Z'), findsNothing);
    expect(find.text(pollockBlurb), findsOneWidget);
    expect(find.text(tunaBlurb), findsOneWidget);
    expect(find.bySemanticsLabel('Jump to A'), findsOneWidget);
    expect(find.bySemanticsLabel('Jump to C'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Jump to C'));
    await tester.pumpAndSettle();
    expect(find.text('Cencaru'), findsWidgets);
    expect(tester.getTopLeft(find.text('Cencaru').first).dy, lessThan(1800));
  });
}
