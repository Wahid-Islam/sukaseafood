import '../../data/models/seafood.dart';

/// Week-over-week change from the last two displayable weekly medians.
///
/// This is observed PriceCatcher history only — not a forecast.
class WeekOverWeek {
  const WeekOverWeek({
    required this.latestPrice,
    required this.previousPrice,
    required this.percent,
    this.latestDate,
    this.previousDate,
  });

  final double latestPrice;
  final double previousPrice;
  final double percent;
  final DateTime? latestDate;
  final DateTime? previousDate;

  bool get fell => percent < 0;
  bool get rose => percent > 0;

  static WeekOverWeek? fromHistory(List<ObservedPricePoint> history) {
    if (history.length < 2) return null;
    final ObservedPricePoint latest = history.last;
    final ObservedPricePoint previous = history[history.length - 2];
    if (previous.priceRmPerKg == 0) return null;
    final double percent =
        ((latest.priceRmPerKg - previous.priceRmPerKg) /
            previous.priceRmPerKg) *
        100;
    return WeekOverWeek(
      latestPrice: latest.priceRmPerKg,
      previousPrice: previous.priceRmPerKg,
      percent: (percent * 10).roundToDouble() / 10,
      latestDate: latest.observedDate,
      previousDate: previous.observedDate,
    );
  }
}
