import 'dart:math' as math;

/// Y-axis scale for RM/kg charts when the series only moves by sen.
class PriceAxisScale {
  const PriceAxisScale({
    required this.minY,
    required this.maxY,
    required this.interval,
    required this.decimals,
  });

  final double minY;
  final double maxY;
  final double interval;
  final int decimals;

  int get reservedSize => decimals >= 2 ? 44 : 36;

  String label(double value) => value.toStringAsFixed(decimals);

  bool isTick(double value) {
    final int vs = _sen(value);
    final int lo = _sen(minY);
    final int hi = _sen(maxY);
    if (vs < lo - 1 || vs > hi + 1) return false;
    final int step = math.max(1, _sen(interval));
    return (vs - lo) % step == 0;
  }

  static const List<double> steps = <double>[
    0.01,
    0.02,
    0.05,
    0.10,
    0.20,
    0.25,
    0.50,
    1,
    2,
    4,
    5,
    10,
    20,
  ];

  /// Picks the smallest step that still keeps labels readable.
  factory PriceAxisScale.fromPrices(
    Iterable<double> prices, {
    int maxTicks = 10,
  }) {
    final List<double> values = prices.toList();
    if (values.isEmpty) {
      return const PriceAxisScale(
        minY: 0,
        maxY: 0.10,
        interval: 0.02,
        decimals: 2,
      );
    }

    final double minP = values.reduce(math.min);
    final double maxP = values.reduce(math.max);
    final double span = math.max(maxP - minP, 0.02);

    double interval = steps.last;
    for (final double step in steps) {
      final int ticks = (span / step).ceil();
      if (ticks <= maxTicks) {
        interval = step;
        break;
      }
    }

    double minY = _snapDown(minP, interval);
    double maxY = _snapUp(maxP, interval);
    while ((maxY - minY) / interval < 3) {
      minY = _snapDown(minY - interval, interval);
      maxY = _snapUp(maxY + interval, interval);
    }
    if (minY < 0) minY = 0;

    return PriceAxisScale(
      minY: minY,
      maxY: maxY,
      interval: interval,
      decimals: 2,
    );
  }

  static int _sen(double value) => (value * 100).round();

  static double _snapDown(double value, double step) {
    return ((value / step) + 1e-9).floor() * step;
  }

  static double _snapUp(double value, double step) {
    return ((value / step) - 1e-9).ceil() * step;
  }
}
