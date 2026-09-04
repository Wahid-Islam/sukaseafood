import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/ui_kit.dart';
import 'price_axis_scale.dart';

/// Observed PriceCatcher weekly medians with lowest / average / highest.
class HistoricalTrendCard extends StatefulWidget {
  const HistoricalTrendCard({super.key, required this.history});

  final List<ObservedPricePoint> history;

  @override
  State<HistoricalTrendCard> createState() => _HistoricalTrendCardState();
}

class _HistoricalTrendCardState extends State<HistoricalTrendCard> {
  static const List<int> _windows = <int>[4, 8, 12];
  static final DateFormat _axis = DateFormat('d MMM');
  static final DateFormat _tip = DateFormat('d MMM yyyy');

  int _weeks = 12;

  List<ObservedPricePoint> get _points {
    final List<ObservedPricePoint> all = widget.history;
    if (all.length <= _weeks) return all;
    return all.sublist(all.length - _weeks);
  }

  @override
  Widget build(BuildContext context) {
    final List<ObservedPricePoint> points = _points;
    if (points.isEmpty) {
      return const SoftCard(
        child: Text(
          'No displayable PriceCatcher history for this species yet. '
          'The four-week outlook is modelled separately and is not a '
          'substitute.',
        ),
      );
    }

    final List<double> prices = points
        .map((ObservedPricePoint p) => p.priceRmPerKg)
        .toList();
    final double lowest = prices.reduce((double a, double b) => a < b ? a : b);
    final double highest = prices.reduce((double a, double b) => a > b ? a : b);
    final double average =
        prices.fold<double>(0, (double s, double v) => s + v) / prices.length;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget title = Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Historical Trend',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const InfoButton(
                    message:
                        'Weekly Selangor medians from OpenDOSM PriceCatcher. '
                        'This is not the four-week forecast.',
                  ),
                ],
              );
              final Widget menu = _WindowMenu(
                weeks: _weeks,
                options: _windows,
                onChanged: (int value) => setState(() => _weeks = value),
              );
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: menu),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Historical Trend (Last $_weeks weeks)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const InfoButton(
                    message:
                        'Weekly Selangor medians from OpenDOSM PriceCatcher. '
                        'This is not the four-week forecast.',
                  ),
                  const SizedBox(width: 8),
                  menu,
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Price (RM/kg)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.muted.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _TrendChart(points: points, axis: _axis, tip: _tip),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCell(
                label: 'Lowest ($_weeks weeks)',
                value: lowest,
                color: AppColors.good,
              ),
              _vDiv(),
              _StatCell(
                label: 'Average ($_weeks weeks)',
                value: average,
                color: AppColors.ink,
              ),
              _vDiv(),
              _StatCell(
                label: 'Highest ($_weeks weeks)',
                value: highest,
                color: AppColors.avoid,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _vDiv() {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.line,
    );
  }
}

class _WindowMenu extends StatelessWidget {
  const _WindowMenu({
    required this.weeks,
    required this.options,
    required this.onChanged,
  });

  final int weeks;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Trend window',
      onSelected: onChanged,
      offset: const Offset(0, 36),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.foam,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Last $weeks weeks',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        return [
          for (final int option in options)
            PopupMenuItem<int>(
              value: option,
              child: Text('Last $option weeks'),
            ),
        ];
      },
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.points,
    required this.axis,
    required this.tip,
  });

  final List<ObservedPricePoint> points;
  final DateFormat axis;
  final DateFormat tip;

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].priceRmPerKg),
    ];
    final LineChartBarData bar = LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      color: AppColors.good,
      barWidth: 3,
      isStrokeCapRound: true,
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
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.good.withValues(alpha: 0.28),
            AppColors.good.withValues(alpha: 0.02),
          ],
        ),
      ),
    );

    final PriceAxisScale axisScale = PriceAxisScale.fromPrices(
      spots.map((FlSpot s) => s.y),
    );

    final int last = spots.length - 1;
    final int labelEvery = spots.length > 8 ? 2 : 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: last.toDouble(),
        minY: axisScale.minY,
        maxY: axisScale.maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: axisScale.interval,
          getDrawingHorizontalLine: (double value) {
            return const FlLine(color: AppColors.line, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        showingTooltipIndicators: <ShowingTooltipIndicators>[
          ShowingTooltipIndicators(<LineBarSpot>[
            LineBarSpot(bar, 0, spots[last]),
          ]),
        ],
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          getTouchedSpotIndicator:
              (LineChartBarData barData, List<int> indicators) {
                return [
                  for (final int _ in indicators)
                    TouchedSpotIndicatorData(
                      const FlLine(color: AppColors.good, strokeWidth: 1.4),
                      FlDotData(
                        getDotPainter:
                            (FlSpot spot, double x, LineChartBarData d, int i) {
                              return FlDotCirclePainter(
                                radius: 5,
                                color: AppColors.good,
                                strokeColor: Colors.white,
                                strokeWidth: 2,
                              );
                            },
                      ),
                    ),
                ];
              },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (LineBarSpot spot) => AppColors.good,
            tooltipBorderRadius: BorderRadius.circular(10),
            maxContentWidth: 160,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (List<LineBarSpot> touched) {
              return [
                for (final LineBarSpot spot in touched)
                  _tooltip(spot.x.round(), spot.y),
              ];
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
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
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.round();
                if (i < 0 || i >= points.length || i % labelEvery != 0) {
                  return const SizedBox.shrink();
                }
                final DateTime? day = points[i].observedDate;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    day == null ? '' : axis.format(day),
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
        lineBarsData: <LineChartBarData>[bar],
      ),
    );
  }

  LineTooltipItem _tooltip(int index, double price) {
    final DateTime? day = index >= 0 && index < points.length
        ? points[index].observedDate
        : null;
    final String when = day == null ? '' : '\n${tip.format(day)}';
    return LineTooltipItem(
      'RM ${price.toStringAsFixed(2)} /kg$when',
      const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        height: 1.3,
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            'RM ${value.toStringAsFixed(2)} /kg',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
