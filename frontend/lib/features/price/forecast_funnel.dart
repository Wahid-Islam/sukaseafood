import 'package:fl_chart/fl_chart.dart';

import '../../data/models/price_forecast.dart';

/// Fan from a point estimate out to each week's stored interval.
///
/// The last pair of spots is the engine's predicted low and high. Earlier
/// weeks open gradually so the band reads as a funnel, not a rectangle.
/// Table values stay the stored R-engine bounds.
class ForecastFunnel {
  const ForecastFunnel({required this.lower, required this.upper});

  final List<FlSpot> lower;
  final List<FlSpot> upper;

  factory ForecastFunnel.fromWeeks({
    required List<ForecastWeek> weeks,
    required int startIndex,
    required double originX,
    required double originY,
  }) {
    if (weeks.isEmpty) {
      return const ForecastFunnel(lower: <FlSpot>[], upper: <FlSpot>[]);
    }

    final int n = weeks.length;
    final List<FlSpot> lower = <FlSpot>[FlSpot(originX, originY)];
    final List<FlSpot> upper = <FlSpot>[FlSpot(originX, originY)];
    for (int i = 0; i < n; i++) {
      final double t = (i + 1) / n;
      final ForecastWeek week = weeks[i];
      final double x = (startIndex + i).toDouble();
      lower.add(FlSpot(x, originY + (week.lowerBound - originY) * t));
      upper.add(FlSpot(x, originY + (week.upperBound - originY) * t));
    }
    return ForecastFunnel(lower: lower, upper: upper);
  }
}
