import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukaseafood/core/theme/app_theme.dart';
import 'package:sukaseafood/data/models/seafood.dart';
import 'package:sukaseafood/features/seafood/wwf_card.dart';
import 'package:sukaseafood/shared/widgets/catalogue_fish_art.dart';
import 'package:sukaseafood/shared/widgets/expandable_text.dart';
import 'package:sukaseafood/shared/widgets/ui_kit.dart';

void main() {
  testWidgets('Read more appears when the description is long', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const String about =
        'Small pelagic sold in almost every Malaysian wet market and '
        'supermarket. Cheap, oily, and the default everyday fish — which '
        'makes it the most useful comparison point when a shopper is '
        'deciding between species.';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 200,
            child: ExpandableText(text: about, maxLines: 2),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read more'), findsOneWidget);
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('short copy has no Read more control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ExpandableText(text: 'Short.', maxLines: 3)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Read more'), findsNothing);
  });

  test('Kembung uses the catalogue photo', () {
    expect(CatalogueFishArt.hasLocalPlate('SF001'), isTrue);
    expect(
      CatalogueFishArt.assetFor('SF001'),
      'assets/images/catalogue/sf001.jpg',
    );
    expect(
      CatalogueFishArt.photoAssetFor('SF001'),
      CatalogueFishArt.assetFor('SF001'),
    );
  });

  test('catalogue photos map to the matching fish codes', () {
    expect(CatalogueFishArt.hasLocalPlate('SF002'), isTrue);
    expect(CatalogueFishArt.photoAssetFor('SF002'), isNotNull);
    expect(CatalogueFishArt.hasLocalPlate('SF007'), isTrue);
    expect(CatalogueFishArt.hasLocalPlate('SF012'), isTrue);
    expect(CatalogueFishArt.hasLocalPlate('SF014'), isFalse);
    expect(CatalogueFishArt.photoAssetFor('SF014'), isNull);
  });

  test('WWF logo asset is bundled', () {
    expect(WwfLogo.asset, 'assets/images/wwf_logo.webp');
  });

  test('brand logo asset is bundled', () {
    expect(BrandLogo.asset, 'assets/images/suka_logo.png');
  });

  testWidgets('WWF card shows both gear ratings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: WwfCard(
            info: SustainabilityInfo(
              classification: 'UNDETERMINED',
              origin: 'Malaysia',
              productionMethod: 'Hook-and-line / Gillnet',
              explanation: 'Rating varies by catch method.',
              whyItMatters:
                  'Tenggiri\'s WWF rating depends on the fishing method.',
              sourceName: 'WWF Save Our Seafood',
              sourceUrl: 'https://www.saveourseafood.my/',
              verified: true,
              assessments: <MethodRating>[
                MethodRating(
                  classification: 'REDUCE',
                  productionMethod: 'Hook-and-line',
                  productionMethodCode: 'HOOK_AND_LINE',
                  origin: 'Malaysia',
                  explanation: 'Applies to hook and line.',
                ),
                MethodRating(
                  classification: 'AVOID',
                  productionMethod: 'Gillnet',
                  productionMethodCode: 'GILLNET',
                  origin: 'Malaysia',
                  explanation: 'Applies to gillnet.',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Why this rating?'), findsOneWidget);
    expect(find.text('Rating varies by catch method.'), findsOneWidget);
    expect(find.text('Hook-and-line'), findsOneWidget);
    expect(find.text('Gillnet'), findsOneWidget);
    expect(find.text('REDUCE'), findsOneWidget);
    expect(find.text('AVOID'), findsOneWidget);
    expect(
      find.textContaining('depends on the fishing method'),
      findsOneWidget,
    );
  });
}
