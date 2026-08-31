/// Response models for `GET /seafood/{fish_id}/price`.
///
/// Observed PriceCatcher context only. This is not a forecast: a null latest
/// price or `Insufficient data` must be shown as absence, never filled from
/// mock catalogue figures or from GET /forecast.
library;

/// One weekly median from `price_trend_point`.
class ObservedPricePoint {
  const ObservedPricePoint({
    required this.observedDate,
    required this.priceRmPerKg,
    required this.premiseState,
    required this.premiseType,
    required this.note,
  });

  final DateTime? observedDate;
  final double priceRmPerKg;
  final String premiseState;
  final String premiseType;
  final String note;

  factory ObservedPricePoint.fromJson(Map<String, dynamic> json) {
    return ObservedPricePoint(
      observedDate: DateTime.tryParse(json['observed_date'] as String? ?? ''),
      priceRmPerKg: (json['price_rm_per_kg'] as num?)?.toDouble() ?? 0,
      premiseState: json['premise_state'] as String? ?? '',
      premiseType: json['premise_type'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

/// Full observed-price payload for one canonical species.
class PriceContext {
  const PriceContext({
    required this.fishId,
    required this.latestPriceRmPerKg,
    required this.status,
    required this.changeVsRecentPct,
    required this.history,
    required this.disclaimer,
  });

  final String fishId;
  final double? latestPriceRmPerKg;
  final String status;
  final double? changeVsRecentPct;
  final List<ObservedPricePoint> history;
  final String disclaimer;

  /// The backend withholds a number unless the monthly rollup is DISPLAYABLE.
  bool get hasDisplayablePrice {
    if (latestPriceRmPerKg == null) return false;
    return status.trim().toLowerCase() != 'insufficient data';
  }

  bool get hasHistory => history.isNotEmpty;

  /// Weekly-median min. Not a premise-level statistic.
  double? get historyLowest => _reduceHistory(
        (double a, double b) => a < b ? a : b,
      );

  /// Arithmetic mean of returned weekly medians.
  double? get historyAverage {
    if (history.isEmpty) return null;
    final double sum = history.fold<double>(
      0,
      (double acc, ObservedPricePoint p) => acc + p.priceRmPerKg,
    );
    return sum / history.length;
  }

  /// Weekly-median max. Not a premise-level statistic.
  double? get historyHighest => _reduceHistory(
        (double a, double b) => a > b ? a : b,
      );

  double? _reduceHistory(double Function(double, double) pick) {
    if (history.isEmpty) return null;
    return history
        .map((ObservedPricePoint p) => p.priceRmPerKg)
        .reduce(pick);
  }

  factory PriceContext.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['history'] as List<dynamic>?) ?? const <dynamic>[];
    return PriceContext(
      fishId: json['fish_id'] as String? ?? '',
      latestPriceRmPerKg: (json['latest_price_rm_per_kg'] as num?)?.toDouble(),
      status: json['status'] as String? ?? '',
      changeVsRecentPct: (json['change_vs_recent_pct'] as num?)?.toDouble(),
      history: raw
          .whereType<Map<String, dynamic>>()
          .map(ObservedPricePoint.fromJson)
          .toList(),
      disclaimer: json['disclaimer'] as String? ??
          'Observed price context from OpenDOSM PriceCatcher — '
              'not a nationally representative average.',
    );
  }
}
