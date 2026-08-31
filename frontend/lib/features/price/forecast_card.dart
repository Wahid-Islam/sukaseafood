import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/api_client.dart';
import '../../data/models/price_forecast.dart';
import '../../shared/widgets/ui_kit.dart';

/// "Price Outlook (Next 4 weeks)", fed by `GET /seafood/{id}/forecast`.
///
/// Presentation only. The point estimates, interval bounds, direction and
/// forecast dates were all produced by the backend's R pipeline and validated
/// there; this widget formats them. Nothing here recomputes a range or decides
/// a direction, because a forecast the app derived itself would be a number no
/// model ever stood behind.
class ForecastCard extends StatelessWidget {
  const ForecastCard({
    super.key,
    required this.forecast,
    required this.error,
    required this.loading,
  });

  final PriceForecast? forecast;
  final ApiException? error;
  final bool loading;

  static final DateFormat _week = DateFormat('d MMM');
  static final DateFormat _updated = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Outlook (Next 4 weeks)',
            style: TextStyle(fontWeight: FontWeight.w800),
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
            _ForecastBody(forecast: forecast!),
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
    // Three distinct situations, three distinct explanations. "No forecast for
    // this fish" is a normal outcome of the eligibility rules, not a failure,
    // and must not read like one.
    final String detail;
    if (error.isForecastUnavailable) {
      detail = 'We only forecast species with enough recent price history to '
          'model honestly. This one does not have it yet.';
    } else if (error.isUnreachable) {
      detail = 'Cannot reach the SukaSeafood API, so the outlook cannot be '
          'loaded. The observed price above is unaffected.';
    } else {
      detail = error.message;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.remove_circle_outline, color: AppColors.muted, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(detail, style: const TextStyle(color: AppColors.muted)),
        ),
      ],
    );
  }
}

class _ForecastBody extends StatelessWidget {
  const _ForecastBody({required this.forecast});

  final PriceForecast forecast;

  @override
  Widget build(BuildContext context) {
    final ForecastWeek nearest = forecast.nearest!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DirectionRow(week: nearest),
        const SizedBox(height: 12),
        _RangeSummary(forecast: forecast, week: nearest),
        const SizedBox(height: 16),
        _RangeChart(weeks: forecast.weeks),
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
      parts.add('run ${ForecastCard._updated.format(forecast.generatedAt!)}');
    }
    return parts.join(' · ');
  }
}

/// The directional verdict, with the icon matched to the claim being made.
class _DirectionRow extends StatelessWidget {
  const _DirectionRow({required this.week});

  final ForecastWeek week;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color colour) = switch (week.outlook) {
      ForecastOutlook.likelyIncrease => (Icons.trending_up, AppColors.avoid),
      ForecastOutlook.likelyDecrease => (Icons.trending_down, AppColors.good),
      // A flat line, not an arrow. An arrow would imply a direction the model
      // explicitly declined to claim.
      ForecastOutlook.noStrongSignal => (Icons.trending_flat, AppColors.tealDark),
      ForecastOutlook.unknown => (Icons.help_outline, AppColors.muted),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colour),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                week.directionalOutlookLabel ?? 'Outlook unavailable',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: colour,
                ),
              ),
              if (week.outlook == ForecastOutlook.noStrongSignal)
                const Text(
                  'The evidence is not strong enough to say the price will '
                  'move either way.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                )
              else if (week.outlookLabel != null)
                Text(
                  week.outlookLabel!,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RangeSummary extends StatelessWidget {
  const _RangeSummary({required this.forecast, required this.week});

  final PriceForecast forecast;
  final ForecastWeek week;

  @override
  Widget build(BuildContext context) {
    final double? reference = forecast.reference.price;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tealSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            week.weekStart == null
                ? 'Next week'
                : 'Week of ${ForecastCard._week.format(week.weekStart!)}',
            style: const TextStyle(fontSize: 11, color: AppColors.tealDark),
          ),
          const SizedBox(height: 2),
          Text(
            'Expected around RM ${week.expectedPrice.toStringAsFixed(2)} /kg',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          Text(
            'Estimated range RM ${week.lowerBound.toStringAsFixed(2)}'
            ' – RM ${week.upperBound.toStringAsFixed(2)} /kg',
            style: const TextStyle(fontSize: 13),
          ),
          if (reference != null) ...[
            const SizedBox(height: 6),
            Text(
              'Reference price RM ${reference.toStringAsFixed(2)} /kg'
              '${forecast.reference.weekStart == null ? '' : ' '
                  '(week of ${ForecastCard._week.format(forecast.reference.weekStart!)})'}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Expected price with the prediction interval shaded around it.
///
/// The band is drawn as two bounding lines rather than the point estimate
/// alone: the interval is the honest part of the forecast, and a single crisp
/// line would suggest a precision the model does not claim.
class _RangeChart extends StatelessWidget {
  const _RangeChart({required this.weeks});

  final List<ForecastWeek> weeks;

  @override
  Widget build(BuildContext context) {
    if (weeks.length < 2) return const SizedBox.shrink();

    final double minY = weeks
            .map((ForecastWeek w) => w.lowerBound)
            .reduce((double a, double b) => a < b ? a : b) -
        0.5;
    final double maxY = weeks
            .map((ForecastWeek w) => w.upperBound)
            .reduce((double a, double b) => a > b ? a : b) +
        0.5;

    List<FlSpot> spots(double Function(ForecastWeek) pick) => <FlSpot>[
          for (int i = 0; i < weeks.length; i++)
            FlSpot(i.toDouble(), pick(weeks[i])),
        ];

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int i = value.round();
                  if (i < 0 || i >= weeks.length) {
                    return const SizedBox.shrink();
                  }
                  final DateTime? start = weeks[i].weekStart;
                  return Text(
                    start == null ? '' : ForecastCard._week.format(start),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots((ForecastWeek w) => w.upperBound),
              isCurved: true,
              barWidth: 1,
              color: AppColors.teal,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: spots((ForecastWeek w) => w.lowerBound),
              isCurved: true,
              barWidth: 1,
              color: AppColors.teal,
              dotData: const FlDotData(show: false),
              // Shade up to the upper line, giving the interval as a band.
              belowBarData: BarAreaData(show: false),
              aboveBarData: BarAreaData(
                show: true,
                applyCutOffY: true,
                cutOffY: maxY,
                color: AppColors.teal.withValues(alpha: 0.16),
              ),
            ),
            LineChartBarData(
              spots: spots((ForecastWeek w) => w.expectedPrice),
              isCurved: true,
              barWidth: 3,
              color: AppColors.tealDark,
              dotData: const FlDotData(show: true),
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
                        : ForecastCard._week.format(week.weekStart!),
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    'RM ${week.expectedPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'RM ${week.lowerBound.toStringAsFixed(2)}'
                  ' – ${week.upperBound.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Thin recent data is a property the user is entitled to know about.
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
