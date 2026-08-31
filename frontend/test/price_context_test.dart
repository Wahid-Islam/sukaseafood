import 'package:flutter_test/flutter_test.dart';
import 'package:sukaseafood/data/mock/mock_catalog.dart';
import 'package:sukaseafood/data/models/price_context.dart';

void main() {
  test('insufficient PriceCatcher data is not treated as a displayable price', () {
    final PriceContext context = PriceContext.fromJson(<String, dynamic>{
      'fish_id': 'SF001',
      'latest_price_rm_per_kg': null,
      'status': 'Insufficient data',
      'change_vs_recent_pct': null,
      'history': <dynamic>[],
      'disclaimer': 'Observed price context from OpenDOSM PriceCatcher.',
    });

    expect(context.hasDisplayablePrice, isFalse);
    expect(context.hasHistory, isFalse);
    expect(context.historyLowest, isNull);
    expect(context.historyAverage, isNull);
    expect(context.historyHighest, isNull);
  });

  test('a null latest price is never filled from history or a default', () {
    final PriceContext context = PriceContext.fromJson(<String, dynamic>{
      'fish_id': 'SF001',
      'latest_price_rm_per_kg': null,
      'status': 'Observed',
      'change_vs_recent_pct': null,
      'history': <Map<String, dynamic>>[
        <String, dynamic>{
          'observed_date': '2026-06-02',
          'price_rm_per_kg': 19.1,
          'premise_state': '',
          'premise_type': '',
          'note': 'Weekly median of 42 observations',
        },
      ],
    });

    expect(context.latestPriceRmPerKg, isNull);
    expect(context.hasDisplayablePrice, isFalse);
  });

  test('low / average / high come only from returned weekly medians', () {
    final PriceContext context = PriceContext.fromJson(<String, dynamic>{
      'fish_id': 'SF012',
      'latest_price_rm_per_kg': 18.5,
      'status': 'Observed',
      'change_vs_recent_pct': -5.1,
      'history': <Map<String, dynamic>>[
        <String, dynamic>{
          'observed_date': '2026-06-02',
          'price_rm_per_kg': 16.0,
          'premise_state': '',
          'premise_type': '',
          'note': '',
        },
        <String, dynamic>{
          'observed_date': '2026-06-09',
          'price_rm_per_kg': 20.0,
          'premise_state': '',
          'premise_type': '',
          'note': '',
        },
        <String, dynamic>{
          'observed_date': '2026-06-16',
          'price_rm_per_kg': 18.0,
          'premise_state': '',
          'premise_type': '',
          'note': '',
        },
      ],
    });

    expect(context.hasDisplayablePrice, isTrue);
    expect(context.historyLowest, 16.0);
    expect(context.historyHighest, 20.0);
    expect(context.historyAverage, closeTo(18.0, 0.0001));
  });

  test('prototype slugs still map to canonical SF codes for the price API', () {
    expect(MockCatalog.apiFishId('tenggiri'), 'SF012');
    expect(MockCatalog.apiFishId('SF001'), 'SF001');
  });
}
