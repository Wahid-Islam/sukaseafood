/// Response models for `GET /seafood/{fish_id}/forecast` (Step 33C).
///
/// Every value here is produced by the backend's R forecasting pipeline and
/// stored in Postgres. The client is a presentation layer: it must not compute
/// ranges, direction, confidence or forecast dates. That rule is why these
/// models are plain data holders with no arithmetic beyond formatting.
library;

/// Directional verdict for a forecast week.
enum ForecastOutlook {
  likelyIncrease,
  likelyDecrease,

  /// Not "stable". The engine is saying it found no validated evidence of a
  /// move, which is a weaker and more honest claim than predicting the price
  /// will hold. Most fish are in this state and the UI must present it as a
  /// real answer rather than a missing one.
  noStrongSignal,

  /// The backend sent a code this build does not know.
  unknown;

  static ForecastOutlook parse(String? code) {
    switch (code) {
      case 'LIKELY_INCREASE':
        return ForecastOutlook.likelyIncrease;
      case 'LIKELY_DECREASE':
        return ForecastOutlook.likelyDecrease;
      case 'NO_STRONG_SIGNAL':
        return ForecastOutlook.noStrongSignal;
      default:
        return ForecastOutlook.unknown;
    }
  }
}

/// How much recent observed data backs a forecast.
enum ForecastQuality {
  /// Stronger data support under the production eligibility rules.
  valid,

  /// Displayable, but the underlying recent PriceCatcher data is thin. The UI
  /// must say so rather than presenting it as equally strong.
  sparseData,
  unknown;

  static ForecastQuality parse(String? code) {
    switch (code) {
      case 'VALID':
        return ForecastQuality.valid;
      case 'SPARSE_DATA':
        return ForecastQuality.sparseData;
      default:
        return ForecastQuality.unknown;
    }
  }
}

/// One forecast week: a point estimate and the interval around it.
class ForecastWeek {
  const ForecastWeek({
    required this.weekStart,
    required this.horizonWeeks,
    required this.expectedPrice,
    required this.lowerBound,
    required this.upperBound,
    required this.outlook,
    required this.outlookLabel,
    required this.directionalOutlookLabel,
    required this.quality,
    required this.modelUsed,
  });

  final DateTime? weekStart;
  final int? horizonWeeks;
  final double expectedPrice;
  final double lowerBound;
  final double upperBound;
  final ForecastOutlook outlook;

  /// Where the forecast band sits against the reference price.
  final String? outlookLabel;

  /// Human wording for [outlook], supplied by the backend so the app and the
  /// engine cannot drift apart on phrasing.
  final String? directionalOutlookLabel;

  final ForecastQuality quality;

  /// Which estimator won for this fish — `ETS(A,N,N)` or `NAIVE`. Selection is
  /// per series, so it belongs to the week, not to the model version.
  final String? modelUsed;

  factory ForecastWeek.fromJson(Map<String, dynamic> json) {
    return ForecastWeek(
      weekStart: DateTime.tryParse(json['forecast_week_start'] as String? ?? ''),
      horizonWeeks: (json['horizon_weeks'] as num?)?.toInt(),
      expectedPrice: (json['expected_price'] as num?)?.toDouble() ?? 0,
      lowerBound: (json['lower_bound'] as num?)?.toDouble() ?? 0,
      upperBound: (json['upper_bound'] as num?)?.toDouble() ?? 0,
      outlook: ForecastOutlook.parse(json['outlook'] as String?),
      outlookLabel: json['outlook_label'] as String?,
      directionalOutlookLabel: json['directional_outlook_label'] as String?,
      quality: ForecastQuality.parse(json['quality_status'] as String?),
      modelUsed: json['model_used'] as String?,
    );
  }
}

/// The observed price the forecast was anchored to.
class ForecastReference {
  const ForecastReference({this.weekStart, this.price});

  final DateTime? weekStart;
  final double? price;

  factory ForecastReference.fromJson(Map<String, dynamic> json) {
    return ForecastReference(
      weekStart: DateTime.tryParse(json['week_start'] as String? ?? ''),
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

/// The full forecast payload for one canonical species and location.
class PriceForecast {
  const PriceForecast({
    required this.fishId,
    required this.canonicalName,
    required this.displayName,
    required this.stateName,
    required this.reference,
    required this.weeks,
    required this.modelVersionName,
    required this.generatedAt,
    required this.disclaimer,
  });

  final String fishId;
  final String canonicalName;
  final String displayName;
  final String stateName;
  final ForecastReference reference;
  final List<ForecastWeek> weeks;
  final String modelVersionName;
  final DateTime? generatedAt;
  final String disclaimer;

  /// The nearest forecast week — what a price card leads with.
  ForecastWeek? get nearest => weeks.isEmpty ? null : weeks.first;

  /// True when any week rests on thin recent data. Surfaced once for the whole
  /// card rather than per row, because it is a property of the series.
  bool get isSparse =>
      weeks.any((ForecastWeek w) => w.quality == ForecastQuality.sparseData);

  factory PriceForecast.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> location =
        (json['location'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> model =
        (json['model'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<dynamic> raw =
        (json['forecast'] as List<dynamic>?) ?? const <dynamic>[];

    return PriceForecast(
      fishId: json['fish_id'] as String? ?? '',
      canonicalName: json['canonical_name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      stateName: location['state_name'] as String? ?? '',
      reference: ForecastReference.fromJson(
        (json['reference'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      weeks: raw
          .whereType<Map<String, dynamic>>()
          .map(ForecastWeek.fromJson)
          .toList(),
      modelVersionName: model['version_name'] as String? ?? '',
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
      disclaimer: json['disclaimer'] as String? ??
          'An estimated range, not an official or guaranteed price.',
    );
  }
}
