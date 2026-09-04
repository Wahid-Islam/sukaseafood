import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/api_client.dart';
import '../../data/models/price_forecast.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/ui_kit.dart';
import 'price_axis_scale.dart';
import 'forecast_funnel.dart';

/// "Price Outlook (Next 4 weeks)", fed by `GET /seafood/{id}/forecast`.
///
/// Presentation only. Point estimates, interval bounds, direction and
/// forecast dates come from the R pipeline. This widget does not recompute
/// a range or decide a direction.
class ForecastCard extends StatelessWidget {
  const ForecastCard({
    super.key,
    required this.forecast,
    required this.error,
    required this.loading,
    this.history = const <ObservedPricePoint>[],
  });

  final PriceForecast? forecast;
  final ApiException? error;
  final bool loading;
  final List<ObservedPricePoint> history;

  static final DateFormat week = DateFormat('d MMM');
  static final DateFormat updated = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Price Outlook (Next 4 weeks)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const InfoButton(
                message:
                    'Four-week range from the SukaSeafood forecast engine. '
                    'Observed stall prices are a separate series.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(color: AppColors.teal),
            )
          else if (error != null)
            _ForecastUnavailable(error: error!)
          else if (forecast == null || forecast!.weeks.isEmpty)
            const Text(
              'No forecast is available for this species yet.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            _ForecastBody(forecast: forecast!, history: history),
        ],
      ),
    );
  }
}

class _ForecastUnavailable extends StatelessWidget {
  const _ForecastUnavailable({required this.error});

  final ApiException error;

  @override
  Widget build(BuildContext context) {
    final String detail;
    if (error.isForecastUnavailable) {
      detail =
          'We only forecast species with enough recent price history to '
          'model honestly. This one does not have it yet.';
    } else if (error.isUnreachable) {
      detail =
          'Cannot reach the SukaSeafood API, so the outlook cannot be '
          'loaded. The observed price above is unaffected.';
    } else {
      detail = error.message;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.remove_circle_outline,
          color: AppColors.muted,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(detail, style: const TextStyle(color: AppColors.muted)),
        ),
      ],
    );
  }
}

class _ForecastBody extends StatelessWidget {
  const _ForecastBody({required this.forecast, required this.history});

  final PriceForecast forecast;
  final List<ObservedPricePoint> history;

  @override
  Widget build(BuildContext context) {
    final ForecastWeek nearest = forecast.nearest!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 640;
            final Widget summary = _OutlookSummary(
              forecast: forecast,
              week: nearest,
            );
            final Widget chart = _OutlookChart(
              forecast: forecast,
              history: history,
              week: nearest,
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: summary),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: chart),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 16), chart],
            );
          },
        ),
        const SizedBox(height: 12),
        _WeekTable(weeks: forecast.weeks),
        const SizedBox(height: 12),
        if (forecast.isSparse) const _SparseNotice(),
        Text(
          forecast.disclaimer,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          _provenance(forecast),
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }

  String _provenance(PriceForecast forecast) {
    final List<String> parts = <String>[];
    if (forecast.stateName.isNotEmpty) parts.add(forecast.stateName);
    final String? model = forecast.nearest?.modelUsed;
    if (model != null && model.isNotEmpty) parts.add('model $model');
    if (forecast.generatedAt != null) {
      parts.add('run ${ForecastCard.updated.format(forecast.generatedAt!)}');
    }
    return parts.join(' · ');
  }
}

class _OutlookSummary extends StatelessWidget {
  const _OutlookSummary({required this.forecast, required this.week});

  final PriceForecast forecast;
  final ForecastWeek week;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color colour, String body) = switch (week.outlook) {
      ForecastOutlook.likelyIncrease => (
        Icons.trending_up,
        AppColors.avoid,
        'The forecast engine expects prices to rise over the next four weeks.',
      ),
      ForecastOutlook.likelyDecrease => (
        Icons.trending_down,
        AppColors.good,
        'The forecast engine expects prices to ease over the next four weeks.',
      ),
      ForecastOutlook.noStrongSignal => (
        Icons.trending_flat,
        AppColors.tealDark,
        'The evidence is not strong enough to say the price will move either way.',
      ),
      ForecastOutlook.unknown => (
        Icons.help_outline,
        AppColors.muted,
        'A directional outlook is not available for this species.',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          week.directionalOutlookLabel ?? 'Outlook unavailable',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: colour,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Expected around RM ${week.expectedPrice.toStringAsFixed(2)} /kg',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: AppColors.ink,
          ),
        ),
        Text(
          'Estimated range RM ${week.lowerBound.toStringAsFixed(2)}'
          ' – RM ${week.upperBound.toStringAsFixed(2)} /kg',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          forecast.stateName.isEmpty
              ? 'Based on the live four-week forecast for this species.'
              : 'Based on the live four-week forecast for this species in ${forecast.stateName}.',
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 14),
        _IntervalMeter(level: forecast.intervalLevel, quality: week.quality),
      ],
    );
  }
}

class _IntervalMeter extends StatelessWidget {
  const _IntervalMeter({required this.level, required this.quality});

  final double? level;
  final ForecastQuality quality;

  @override
  Widget build(BuildContext context) {
    final int pct = ((level ?? 0) * 100).round();
    final String qualityLabel = switch (quality) {
      ForecastQuality.valid => 'Displayable series',
      ForecastQuality.sparseData => 'Sparse recent data',
      ForecastQuality.unknown => 'Quality unknown',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.foam,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  'Prediction interval',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              const InfoButton(
                message:
                    'Coverage of the stored forecast band. This is not a '
                    'probability that the price will move up or down.',
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: pct.clamp(0, 100),
                    child: const ColoredBox(color: AppColors.good),
                  ),
                  Expanded(
                    flex: (100 - pct).clamp(0, 100),
                    child: const ColoredBox(color: AppColors.line),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            level == null ? qualityLabel : '$pct% · $qualityLabel',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.good,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlookChart extends StatelessWidget {
  const _OutlookChart({
    required this.forecast,
    required this.history,
    required this.week,
  });

  final PriceForecast forecast;
  final List<ObservedPricePoint> history;
  final ForecastWeek week;

  @override
  Widget build(BuildContext context) {
    final DateTime? firstForecast = forecast.weeks.first.weekStart;
    final List<ObservedPricePoint> past = _historical(firstForecast);
    final List<ForecastWeek> future = forecast.weeks;
    if (future.isEmpty) return const SizedBox.shrink();

    final int histCount = past.length;
    final List<FlSpot> histSpots = <FlSpot>[
      for (int i = 0; i < histCount; i++)
        FlSpot(i.toDouble(), past[i].priceRmPerKg),
    ];
    final int start = histCount;
    final List<FlSpot> predicted = <FlSpot>[
      for (int i = 0; i < future.length; i++)
        FlSpot((start + i).toDouble(), future[i].expectedPrice),
    ];
    final List<FlSpot> expected = <FlSpot>[
      if (histSpots.isNotEmpty) histSpots.last,
      ...predicted,
    ];
    final ForecastFunnel funnel = ForecastFunnel.fromWeeks(
      weeks: future,
      startIndex: start,
      originX: histSpots.isNotEmpty
          ? histSpots.last.x
          : (start - 0.35).clamp(0, start.toDouble()).toDouble(),
      originY: future.first.expectedPrice,
    );
    final List<FlSpot> lower = funnel.lower;
    final List<FlSpot> upper = funnel.upper;
    final int expectedBarIndex = histSpots.isEmpty ? 2 : 3;

    final List<double> ys = <double>[
      ...histSpots.map((FlSpot s) => s.y),
      ...expected.map((FlSpot s) => s.y),
      ...lower.map((FlSpot s) => s.y),
      ...upper.map((FlSpot s) => s.y),
    ];
    final PriceAxisScale axisScale = PriceAxisScale.fromPrices(ys);
    final double maxX = (start + future.length - 1).toDouble();
    final double dividerX = histCount == 0 ? -0.5 : start - 0.5;

    final LineChartBarData histBar = LineChartBarData(
      spots: histSpots,
      isCurved: true,
      preventCurveOverShooting: true,
      color: AppColors.good,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (FlSpot spot, double x, LineChartBarData data, int i) {
          return FlDotCirclePainter(
            radius: 3.5,
            color: Colors.white,
            strokeColor: AppColors.good,
            strokeWidth: 2,
          );
        },
      ),
    );
    final LineChartBarData lowerBar = LineChartBarData(
      spots: lower,
      isCurved: false,
      color: Colors.transparent,
      barWidth: 0,
      dotData: const FlDotData(show: false),
    );
    final LineChartBarData upperBar = LineChartBarData(
      spots: upper,
      isCurved: false,
      color: Colors.transparent,
      barWidth: 0,
      dotData: const FlDotData(show: false),
    );
    final LineChartBarData expectedBar = LineChartBarData(
      spots: expected,
      isCurved: false,
      color: AppColors.navy,
      barWidth: 3.5,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (FlSpot spot, LineChartBarData data) {
          return spot.x >= start - 0.01;
        },
        getDotPainter: (FlSpot spot, double x, LineChartBarData data, int i) {
          return FlDotCirclePainter(
            radius: 5,
            color: AppColors.navy,
            strokeColor: Colors.white,
            strokeWidth: 2,
          );
        },
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: histCount.clamp(1, 12),
              child: const Center(child: _SeriesPill(label: 'Historical')),
            ),
            Expanded(
              flex: future.length.clamp(1, 12),
              child: const Center(
                child: _SeriesPill(label: 'Predicted RM /kg'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 248,
          child: Stack(
            children: [
              LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX < 1 ? 1 : maxX,
                  minY: axisScale.minY,
                  maxY: axisScale.maxY,
                  clipData: const FlClipData.none(),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (LineBarSpot spot) => AppColors.navy,
                      tooltipBorderRadius: BorderRadius.circular(10),
                      maxContentWidth: 150,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (List<LineBarSpot> touched) {
                        return [
                          for (final LineBarSpot spot in touched)
                            spot.barIndex == expectedBarIndex &&
                                    spot.x >= start - 0.01
                                ? LineTooltipItem(
                                    'Predicted\n${spot.y.toStringAsFixed(2)} /kg',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                        ];
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: axisScale.interval,
                    getDrawingHorizontalLine: (double value) {
                      return const FlLine(
                        color: AppColors.line,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  extraLinesData: ExtraLinesData(
                    verticalLines: <VerticalLine>[
                      VerticalLine(
                        x: dividerX.clamp(0, maxX),
                        color: AppColors.muted.withValues(alpha: 0.45),
                        strokeWidth: 1.4,
                        dashArray: const <int>[4, 4],
                      ),
                    ],
                  ),
                  borderData: FlBorderData(show: false),
                  showingTooltipIndicators: const <ShowingTooltipIndicators>[],
                  betweenBarsData: <BetweenBarsData>[
                    BetweenBarsData(
                      fromIndex: histSpots.isEmpty ? 0 : 1,
                      toIndex: histSpots.isEmpty ? 1 : 2,
                      color: AppColors.good.withValues(alpha: 0.22),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: axisScale.reservedSize.toDouble(),
                        interval: axisScale.interval,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (!axisScale.isTick(value)) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            axisScale.label(value),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.muted,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int i = value.round();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _label(i, past, future),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: <LineChartBarData>[
                    if (histSpots.isNotEmpty) histBar,
                    lowerBar,
                    upperBar,
                    expectedBar,
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: _PredictedPricePins(
                    spots: predicted,
                    maxX: maxX < 1 ? 1 : maxX,
                    minY: axisScale.minY,
                    maxY: axisScale.maxY,
                    rightReserved: axisScale.reservedSize.toDouble(),
                    bottomReserved: 36,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Callout(week: week),
      ],
    );
  }

  List<ObservedPricePoint> _historical(DateTime? firstForecast) {
    final List<ObservedPricePoint> cut;
    if (firstForecast == null) {
      cut = history;
    } else {
      cut = history.where((ObservedPricePoint p) {
        final DateTime? day = p.observedDate;
        return day != null && day.isBefore(firstForecast);
      }).toList();
    }
    final List<ObservedPricePoint> tail = cut.length <= 4
        ? cut
        : cut.sublist(cut.length - 4);
    if (tail.isNotEmpty) return tail;
    final double? ref = forecast.reference.price;
    if (ref == null) return const <ObservedPricePoint>[];
    return <ObservedPricePoint>[
      ObservedPricePoint(
        observedDate: forecast.reference.weekStart,
        priceRmPerKg: ref,
        premiseState: '',
      ),
    ];
  }

  String _label(
    int index,
    List<ObservedPricePoint> past,
    List<ForecastWeek> future,
  ) {
    if (index < past.length) {
      final DateTime? day = past[index].observedDate;
      if (day == null) return '';
      final String stamp = ForecastCard.week.format(day);
      if (index == past.length - 1 && _isRecent(day)) {
        return '$stamp\n(Today)';
      }
      return stamp;
    }
    final int fi = index - past.length;
    if (fi < 0 || fi >= future.length) return '';
    final DateTime? day = future[fi].weekStart;
    return day == null ? '' : ForecastCard.week.format(day);
  }

  static bool _isRecent(DateTime day) {
    return DateTime.now().difference(day).inDays.abs() <= 7;
  }
}

class _PredictedPricePins extends StatelessWidget {
  const _PredictedPricePins({
    required this.spots,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.rightReserved,
    required this.bottomReserved,
  });

  final List<FlSpot> spots;
  final double maxX;
  final double minY;
  final double maxY;
  final double rightReserved;
  final double bottomReserved;

  static List<FlSpot> _pinsFor(List<FlSpot> spots) {
    if (spots.length < 2) return spots;
    final bool flat = spots.every(
      (FlSpot s) => (s.y - spots.first.y).abs() < 0.005,
    );
    return flat ? <FlSpot>[spots.last] : spots;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double plotW = (constraints.maxWidth - rightReserved).clamp(
          1,
          double.infinity,
        );
        final double plotH = (constraints.maxHeight - bottomReserved).clamp(
          1,
          double.infinity,
        );
        final double ySpan = (maxY - minY).abs() < 0.0001 ? 1 : maxY - minY;
        final double xSpan = maxX <= 0 ? 1 : maxX;
        return Stack(
          children: [
            for (final FlSpot spot in _pinsFor(spots))
              Positioned(
                left: (spot.x / xSpan) * plotW - 18,
                top: ((maxY - spot.y) / ySpan) * plotH - 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    spot.y.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SeriesPill extends StatelessWidget {
  const _SeriesPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goodSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.good,
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.week});

  final ForecastWeek week;

  @override
  Widget build(BuildContext context) {
    final String text =
        week.outlookLabel ??
        week.directionalOutlookLabel ??
        'Forecast range for the next four weeks.';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.foam,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.eco, size: 16, color: AppColors.good),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 11, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekTable extends StatelessWidget {
  const _WeekTable({required this.weeks});

  final List<ForecastWeek> weeks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final ForecastWeek week in weeks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    week.weekStart == null
                        ? '—'
                        : ForecastCard.week.format(week.weekStart!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'RM ${week.expectedPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    'RM ${week.lowerBound.toStringAsFixed(2)}'
                    ' – ${week.upperBound.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SparseNotice extends StatelessWidget {
  const _SparseNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.reduce.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.reduce),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sparse recent data: fewer price observations back this fish, '
                'so treat the range as weaker than for a widely reported species.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
