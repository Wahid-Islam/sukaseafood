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
    expect(
      DiscoveryCatalog.tagsFor(item, DiscoveryCategory.steam),
      <String>['WWF Good Choice', 'Great for Steaming'],
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
    expect(find.text('All Seafood'), findsOneWidget);
    expect(find.text('Good Sustainable Choices'), findsOneWidget);
    expect(find.text('Scan a fish'), findsOneWidget);
    expect(find.text('Kembung'), findsWidgets);

    await tester.tap(find.text('Good Sustainable Choices'));
    await tester.pumpAndSettle();
    expect(find.text('Cencaru'), findsWidgets);
    expect(find.text('Kembung'), findsNothing);
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
    await tester.tap(find.text('Good Sustainable Choices'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No supported seafood matches'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Browse by category'), findsOneWidget);
  });

  testWidgets('Fish Bio hub opens sustainability and cooking routes', (
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
    await tester.tap(find.text('Kembung').first);
    await tester.pumpAndSettle();

    expect(find.text('Kembung'), findsWidgets);
    expect(find.text('Rastrelliger kanagurta'), findsOneWidget);
    expect(find.text('WWF Sustainability'), findsOneWidget);
    expect(find.text('Biodiversity Context'), findsOneWidget);
    expect(find.text('Price Context'), findsOneWidget);
    expect(find.text('Smart Swap & Cooking'), findsOneWidget);
    expect(find.text('Find another seafood'), findsOneWidget);

    await tester.tap(find.text('WWF Sustainability'));
    await tester.pumpAndSettle();
    expect(find.text('WWF Sustainability'), findsWidgets);
    expect(find.textContaining('WWF Save Our Seafood'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biodiversity Context'));
    await tester.pumpAndSettle();
    expect(find.text('Why biodiversity matters'), findsOneWidget);
    expect(find.text('Conservation status'), findsOneWidget);
  });
}
