import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukaseafood/core/auth/auth_controller.dart';
import 'package:sukaseafood/data/catalog/catalog_controller.dart';
import 'package:sukaseafood/data/models/seafood.dart';
import 'package:sukaseafood/data/models/user_profile.dart';
import 'package:sukaseafood/main.dart';

void main() {
  testWidgets('home boots with SukaSeafood brand', (WidgetTester tester) async {
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
      items: const <SeafoodSummary>[
        SeafoodSummary(
          fishId: 'SF012',
          scientificName: 'Scomberomorus spp.',
          primaryCommonName: 'Tenggiri',
          fishType: 'Pelagic Fish',
          classification: 'GOOD CHOICE',
        ),
      ],
    );

    await tester.pumpWidget(
      SukaSeafoodApp(authController: auth, catalogController: catalog),
    );
    await tester.pump();

    expect(find.textContaining('SukaSeafood'), findsWidgets);
    expect(find.textContaining('Amir', findRichText: true), findsWidgets);
    expect(find.text('HIGHLIGHTED FISH OF THE WEEK'), findsOneWidget);
    expect(find.text('Tenggiri'), findsOneWidget);
    expect(find.text('Malay, English or scientific name'), findsWidgets);
    expect(find.text('YOUR FAVOURITES'), findsOneWidget);
    expect(
      find.textContaining('Better choices today, healthier oceans tomorrow.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Price and landing alerts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Kembung outlook, Selangor'), findsOneWidget);
  });

  test('favourite list keeps one row per fish', () {
    const SeafoodSummary kembung = SeafoodSummary(
      fishId: 'SF001',
      scientificName: 'Rastrelliger kanagurta',
      primaryCommonName: 'Kembung',
      fishType: 'Pelagic Fish',
    );
    const SeafoodSummary selar = SeafoodSummary(
      fishId: 'SF011',
      scientificName: 'Atule mate',
      primaryCommonName: 'Selar',
      fishType: 'Pelagic Fish',
    );
    final CatalogController catalog = CatalogController.forTesting(
      items: const <SeafoodSummary>[kembung, kembung],
      favourites: const <SeafoodSummary>[kembung, kembung, selar],
    );
    expect(
      catalog.favourites.map((SeafoodSummary e) => e.fishId).toList(),
      <String>['SF001', 'SF011'],
    );
    expect(catalog.items.map((SeafoodSummary e) => e.fishId).toList(), <String>[
      'SF001',
    ]);
  });

  test(
    'toggleFavourite updates the heart without waiting on the API',
    () async {
      const SeafoodSummary kembung = SeafoodSummary(
        fishId: 'SF001',
        scientificName: 'Rastrelliger kanagurta',
        primaryCommonName: 'Kembung',
        fishType: 'Pelagic Fish',
      );
      final CatalogController catalog = CatalogController.forTesting(
        items: const <SeafoodSummary>[kembung],
      );
      expect(catalog.isFavourite('SF001'), isFalse);
      await catalog.toggleFavourite('SF001');
      expect(catalog.isFavourite('SF001'), isTrue);
      await catalog.toggleFavourite('SF001');
      expect(catalog.isFavourite('SF001'), isFalse);
    },
  );
}
