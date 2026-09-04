import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukaseafood/core/theme/app_theme.dart';
import 'package:sukaseafood/data/models/price_forecast.dart';
import 'package:sukaseafood/data/models/seafood.dart';
import 'package:sukaseafood/features/price/forecast_card.dart';
import 'package:sukaseafood/features/price/forecast_funnel.dart';
import 'package:sukaseafood/features/price/historical_trend_card.dart';
import 'package:sukaseafood/features/price/price_axis_scale.dart';
import 'package:sukaseafood/features/price/week_over_week.dart';
import 'package:sukaseafood/shared/widgets/ui_kit.dart';

void main() {
  group('WeekOverWeek', () {
    test('returns percent from the last two weekly points', () {
      final WeekOverWeek? change =
          WeekOverWeek.fromHistory(<ObservedPricePoint>[
            ObservedPricePoint(
              observedDate: DateTime(2026, 8, 17),
              priceRmPerKg: 16.0,
              premiseState: 'Selangor',
            ),
            ObservedPricePoint(
              observedDate: DateTime(2026, 8, 24),
              priceRmPerKg: 15.2,
              premiseState: 'Selangor',
            ),
          ]);

      expect(change, isNotNull);
      expect(change!.fell, isTrue);
      expect(change.previousPrice, 16.0);
      expect(change.latestPrice, 15.2);
      expect(change.percent, closeTo(-5.0, 0.05));
    });

    test('needs two points', () {
      expect(WeekOverWeek.fromHistory(const <ObservedPricePoint>[]), isNull);
    });
  });

  test('current price uses the latest weekly point, not a monthly figure', () {
    final PriceContext price = PriceContext(
      fishId: 'SF006',
      latestPriceRmPerKg: 10.00,
      status: 'Observed',
      disclaimer: '',
      history: <ObservedPricePoint>[
        ObservedPricePoint(
          observedDate: DateTime(2026, 8, 17),
          priceRmPerKg: 10.00,
          premiseState: 'Selangor',
        ),
        ObservedPricePoint(
          observedDate: DateTime(2026, 8, 24),
          priceRmPerKg: 10.90,
          premiseState: 'Selangor',
        ),
      ],
    );
    expect(price.observedPriceRmPerKg, 10.90);
    final WeekOverWeek? change = WeekOverWeek.fromHistory(price.history);
    expect(change, isNotNull);
    expect(change!.latestPrice, price.observedPriceRmPerKg);
    expect(change.previousPrice, 10.00);
    expect(change.percent, closeTo(9.0, 0.05));
  });

  group('PriceAxisScale', () {
    test('uses sen steps when prices barely move', () {
      final PriceAxisScale axis = PriceAxisScale.fromPrices(const <double>[
        10.11,
        10.12,
        10.13,
      ]);
      expect(axis.interval, 0.01);
      expect(axis.decimals, 2);
      expect(axis.label(10.12), '10.12');
      expect(axis.isTick(10.11), isTrue);
      expect(axis.isTick(10.12), isTrue);
      expect(axis.isTick(10.13), isTrue);
    });

    test('keeps two-decimal labels on a one-ringgit swing', () {
      final PriceAxisScale axis = PriceAxisScale.fromPrices(const <double>[
        15.90,
        16.90,
      ]);
      expect(axis.interval, lessThanOrEqualTo(0.20));
      expect(axis.decimals, 2);
      expect(axis.label(axis.minY).contains('.'), isTrue);
    });

    test('keeps wider steps for a several-ringgit swing', () {
      final PriceAxisScale axis = PriceAxisScale.fromPrices(const <double>[
        16,
        18,
        20,
        22,
        24,
      ]);
      expect(axis.interval, greaterThanOrEqualTo(0.5));
      expect(axis.interval, lessThanOrEqualTo(2));
      expect(axis.label(16), '16.00');
    });
  });

  testWidgets('historical trend shows window, stats and last-week copy', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HistoricalTrendCard(
            history: <ObservedPricePoint>[
              for (int i = 0; i < 8; i++)
                ObservedPricePoint(
                  observedDate: DateTime(2026, 7, 6).add(Duration(days: 7 * i)),
                  priceRmPerKg: 14.0 + i,
                  premiseState: 'Selangor',
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Historical Trend'), findsOneWidget);
    expect(find.textContaining('Lowest'), findsOneWidget);
    expect(find.textContaining('Average'), findsOneWidget);
    expect(find.textContaining('Highest'), findsOneWidget);
    expect(find.text('Last 12 weeks'), findsOneWidget);
  });

  testWidgets('price cards fit a narrow phone width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final PriceForecast forecast = PriceForecast(
      fishId: 'SF001',
      canonicalName: 'Kembung / Pelaling',
      displayName: 'Indian Mackerel',
      stateName: 'Selangor',
      reference: const ForecastReference(price: 15.9),
      weeks: <ForecastWeek>[
        ForecastWeek(
          weekStart: DateTime(2026, 8, 24),
          horizonWeeks: 1,
          expectedPrice: 15.9,
          lowerBound: 14.89,
          upperBound: 16.91,
          outlook: ForecastOutlook.likelyDecrease,
          outlookLabel: 'Below current levels',
          directionalOutlookLabel: 'Likely to decrease',
          quality: ForecastQuality.valid,
          modelUsed: 'ETS(A,N,N)',
        ),
        ForecastWeek(
          weekStart: DateTime(2026, 8, 31),
          horizonWeeks: 2,
          expectedPrice: 15.4,
          lowerBound: 14.2,
          upperBound: 16.5,
          outlook: ForecastOutlook.likelyDecrease,
          outlookLabel: 'Below current levels',
          directionalOutlookLabel: 'Likely to decrease',
          quality: ForecastQuality.valid,
          modelUsed: 'ETS(A,N,N)',
        ),
      ],
      modelVersionName: 'test',
      intervalLevel: 0.8,
      generatedAt: DateTime(2026, 8, 30),
      disclaimer: 'An estimated range, not an official or guaranteed price.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                HistoricalTrendCard(
                  history: <ObservedPricePoint>[
                    for (int i = 0; i < 6; i++)
                      ObservedPricePoint(
                        observedDate: DateTime(
                          2026,
                          7,
                          6,
                        ).add(Duration(days: 7 * i)),
                        priceRmPerKg: 14.0 + i,
                        premiseState: 'Selangor',
                      ),
                  ],
                ),
                ForecastCard(forecast: forecast, error: null, loading: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Historical Trend'), findsOneWidget);
    expect(find.textContaining('Price Outlook'), findsOneWidget);
    expect(find.text('Likely to decrease'), findsWidgets);
    expect(find.text('Current'), findsNothing);
    expect(find.text('Trend'), findsNothing);
  });

  testWidgets('outlook uses engine labels and not invented landings copy', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final PriceForecast forecast = PriceForecast(
      fishId: 'SF001',
      canonicalName: 'Kembung / Pelaling',
      displayName: 'Indian Mackerel',
      stateName: 'Selangor',
      reference: ForecastReference(
        weekStart: DateTime(2026, 8, 17),
        price: 15.9,
      ),
      weeks: <ForecastWeek>[
        ForecastWeek(
          weekStart: DateTime(2026, 8, 24),
          horizonWeeks: 1,
          expectedPrice: 15.9,
          lowerBound: 14.89,
          upperBound: 16.91,
          outlook: ForecastOutlook.noStrongSignal,
          outlookLabel: 'Around current levels',
          directionalOutlookLabel: 'No strong directional signal',
          quality: ForecastQuality.valid,
          modelUsed: 'NAIVE',
        ),
        ForecastWeek(
          weekStart: DateTime(2026, 8, 31),
          horizonWeeks: 2,
          expectedPrice: 15.9,
          lowerBound: 14.89,
          upperBound: 16.91,
          outlook: ForecastOutlook.noStrongSignal,
          outlookLabel: 'Around current levels',
          directionalOutlookLabel: 'No strong directional signal',
          quality: ForecastQuality.valid,
          modelUsed: 'NAIVE',
        ),
      ],
      modelVersionName: 'test',
      intervalLevel: 0.8,
      generatedAt: DateTime(2026, 8, 30),
      disclaimer: 'An estimated range, not an official or guaranteed price.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForecastCard(
              forecast: forecast,
              error: null,
              loading: false,
              history: <ObservedPricePoint>[
                ObservedPricePoint(
                  observedDate: DateTime(2026, 8, 10),
                  priceRmPerKg: 15.0,
                  premiseState: 'Selangor',
                ),
                ObservedPricePoint(
                  observedDate: DateTime(2026, 8, 17),
                  priceRmPerKg: 16.0,
                  premiseState: 'Selangor',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Expected around RM'), findsOneWidget);
    expect(find.text('15.90'), findsWidgets);
    expect(find.text('RM 15.90'), findsWidgets);
    expect(find.text('No strong directional signal'), findsWidgets);
    expect(find.text('Around current levels'), findsOneWidget);
    expect(find.textContaining('80%'), findsOneWidget);
    expect(find.text('Historical'), findsOneWidget);
    expect(find.text('Predicted RM /kg'), findsOneWidget);
    expect(find.text('RM 15.90'), findsWidgets);
    expect(find.textContaining('landings'), findsNothing);
    expect(find.text('Current'), findsNothing);
    expect(find.text('Trend'), findsNothing);
    expect(find.text('Outlook'), findsNothing);
  });

  test('forecast funnel opens to the stored low and high', () {
    const ForecastWeek week = ForecastWeek(
      weekStart: null,
      horizonWeeks: 1,
      expectedPrice: 15.9,
      lowerBound: 14.89,
      upperBound: 16.91,
      outlook: ForecastOutlook.noStrongSignal,
      outlookLabel: 'Around current levels',
      directionalOutlookLabel: 'No strong directional signal',
      quality: ForecastQuality.valid,
      modelUsed: 'NAIVE',
    );
    final ForecastFunnel funnel = ForecastFunnel.fromWeeks(
      weeks: const <ForecastWeek>[week, week, week, week],
      startIndex: 1,
      originX: 0,
      originY: 15.9,
    );

    expect(funnel.lower.first.x, 0);
    expect(funnel.lower.first.y, 15.9);
    expect(funnel.upper.first.y, 15.9);
    expect(funnel.lower.last.y, closeTo(14.89, 0.001));
    expect(funnel.upper.last.y, closeTo(16.91, 0.001));
    expect(funnel.lower[2].y, closeTo(15.395, 0.001));
    expect(funnel.upper[2].y, closeTo(16.405, 0.001));
  });

  testWidgets('info button shows the explanation on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: InfoButton(message: 'Change between weekly medians.'),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Show info'));
    await tester.pumpAndSettle();
    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Change between weekly medians.'), findsOneWidget);
  });

  testWidgets('GOOD CHOICE caption stays inside a narrow pill', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const String caption = 'A sustainable and responsible choice.';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 168,
              child: ClassificationPill(label: 'GOOD CHOICE', caption: caption),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('GOOD CHOICE'), findsOneWidget);
    expect(find.text(caption), findsOneWidget);

    final RenderBox pill = tester.renderObject(find.byType(ClassificationPill));
    final RenderBox captionBox = tester.renderObject(find.text(caption));
    expect(captionBox.size.width, lessThanOrEqualTo(pill.size.width));
    expect(
      captionBox.localToGlobal(Offset.zero).dx,
      greaterThanOrEqualTo(pill.localToGlobal(Offset.zero).dx),
    );
    expect(
      captionBox.localToGlobal(Offset(captionBox.size.width, 0)).dx,
      lessThanOrEqualTo(
        pill.localToGlobal(Offset.zero).dx + pill.size.width + 0.5,
      ),
    );
  });

  testWidgets('last-week price uses the same footer pill as WWF', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 140,
              child: CaptionedPill(
                color: AppColors.avoid,
                icon: Icons.history,
                label: 'Last week',
                caption: 'RM 10.00 /kg',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('LAST WEEK'), findsOneWidget);
    expect(find.text('RM 10.00 /kg'), findsOneWidget);
  });

  testWidgets('height-matched price cards still show their copy', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Observed Price'),
                        Text('RM 10.90 /kg'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text('Compared to last week'), Text('9%')],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Current Observed Price'), findsOneWidget);
    expect(find.text('RM 10.90 /kg'), findsOneWidget);
    expect(find.text('9%'), findsOneWidget);
    expect(find.text('Compared to last week'), findsOneWidget);
  });
}
