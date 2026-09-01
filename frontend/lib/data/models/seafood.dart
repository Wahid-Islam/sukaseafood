/// Live catalogue models matching `GET /seafood` and `GET /seafood/{id}`.
library;

class SeafoodSummary {
  const SeafoodSummary({
    required this.fishId,
    required this.scientificName,
    required this.primaryCommonName,
    required this.fishType,
    this.imageUrl,
    this.classification,
  });

  final String fishId;
  final String scientificName;
  final String primaryCommonName;
  final String fishType;
  final String? imageUrl;
  final String? classification;

  /// First Malay name when the canonical form is "Kembung / Pelaling".
  String get shortName {
    final int cut = primaryCommonName.indexOf(' / ');
    return cut < 0 ? primaryCommonName : primaryCommonName.substring(0, cut);
  }

  factory SeafoodSummary.fromJson(Map<String, dynamic> json) {
    return SeafoodSummary(
      fishId: json['fish_id'] as String? ?? '',
      scientificName: json['scientific_name'] as String? ?? '',
      primaryCommonName: json['primary_common_name'] as String? ?? '',
      fishType: json['fish_type'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      classification: json['classification'] as String?,
    );
  }
}

class SeafoodAlias {
  const SeafoodAlias({required this.alias, required this.language});

  final String alias;
  final String language;

  factory SeafoodAlias.fromJson(Map<String, dynamic> json) {
    return SeafoodAlias(
      alias: json['alias'] as String? ?? '',
      language: json['language'] as String? ?? '',
    );
  }
}

class SustainabilityInfo {
  const SustainabilityInfo({
    required this.classification,
    required this.origin,
    required this.productionMethod,
    required this.explanation,
    required this.whyItMatters,
    required this.sourceName,
    required this.sourceUrl,
    required this.verified,
  });

  final String classification;
  final String origin;
  final String productionMethod;
  final String explanation;
  final String whyItMatters;
  final String sourceName;
  final String sourceUrl;
  final bool verified;

  factory SustainabilityInfo.fromJson(Map<String, dynamic> json) {
    return SustainabilityInfo(
      classification: json['classification'] as String? ?? 'UNDETERMINED',
      origin: json['origin'] as String? ?? '',
      productionMethod: json['production_method'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      whyItMatters: json['why_it_matters'] as String? ?? '',
      sourceName: json['source_name'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
    );
  }
}

class CookingSuitability {
  const CookingSuitability({
    required this.method,
    required this.suitabilityScore,
    required this.rationale,
    required this.verified,
  });

  final String method;
  final double suitabilityScore;
  final String rationale;
  final bool verified;

  int get starsOutOfFive => (suitabilityScore * 5).round().clamp(0, 5);

  factory CookingSuitability.fromJson(Map<String, dynamic> json) {
    return CookingSuitability(
      method: json['method'] as String? ?? '',
      suitabilityScore: (json['suitability_score'] as num?)?.toDouble() ?? 0,
      rationale: json['rationale'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
    );
  }
}

class SupplyContext {
  const SupplyContext({
    required this.summary,
    required this.trendLabel,
    required this.sourceName,
  });

  final String summary;
  final String trendLabel;
  final String sourceName;

  factory SupplyContext.fromJson(Map<String, dynamic> json) {
    return SupplyContext(
      summary: json['summary'] as String? ?? '',
      trendLabel: json['trend_label'] as String? ?? '',
      sourceName: json['source_name'] as String? ?? '',
    );
  }
}

class SeafoodProfile {
  const SeafoodProfile({
    required this.fishId,
    required this.scientificName,
    required this.primaryCommonName,
    required this.fishType,
    required this.commonIn,
    required this.marketAvailability,
    required this.about,
    this.imageUrl,
    this.aliases = const <SeafoodAlias>[],
    this.sustainability,
    this.cooking = const <CookingSuitability>[],
    this.supply,
  });

  final String fishId;
  final String scientificName;
  final String primaryCommonName;
  final String fishType;
  final String commonIn;
  final String marketAvailability;
  final String about;
  final String? imageUrl;
  final List<SeafoodAlias> aliases;
  final SustainabilityInfo? sustainability;
  final List<CookingSuitability> cooking;
  final SupplyContext? supply;

  String get shortName {
    final int cut = primaryCommonName.indexOf(' / ');
    return cut < 0 ? primaryCommonName : primaryCommonName.substring(0, cut);
  }

  String get alsoKnownAs {
    final Iterable<String> names = aliases
        .where((SeafoodAlias a) => a.alias.toLowerCase() != shortName.toLowerCase())
        .map((SeafoodAlias a) => a.alias)
        .take(4);
    return names.join(', ');
  }

  String get classification =>
      sustainability?.classification ?? 'UNDETERMINED';

  factory SeafoodProfile.fromJson(Map<String, dynamic> json) {
    return SeafoodProfile(
      fishId: json['fish_id'] as String? ?? '',
      scientificName: json['scientific_name'] as String? ?? '',
      primaryCommonName: json['primary_common_name'] as String? ?? '',
      fishType: json['fish_type'] as String? ?? '',
      commonIn: json['common_in'] as String? ?? '',
      marketAvailability: json['market_availability'] as String? ?? '',
      about: json['about'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      aliases: (json['aliases'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SeafoodAlias.fromJson)
          .toList(),
      sustainability: json['sustainability'] is Map<String, dynamic>
          ? SustainabilityInfo.fromJson(
              json['sustainability'] as Map<String, dynamic>,
            )
          : null,
      cooking: (json['cooking'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CookingSuitability.fromJson)
          .toList(),
      supply: json['supply'] is Map<String, dynamic>
          ? SupplyContext.fromJson(json['supply'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ObservedPricePoint {
  const ObservedPricePoint({
    required this.observedDate,
    required this.priceRmPerKg,
    required this.premiseState,
  });

  final DateTime? observedDate;
  final double priceRmPerKg;
  final String premiseState;

  factory ObservedPricePoint.fromJson(Map<String, dynamic> json) {
    return ObservedPricePoint(
      observedDate: DateTime.tryParse(json['observed_date'] as String? ?? ''),
      priceRmPerKg: (json['price_rm_per_kg'] as num?)?.toDouble() ?? 0,
      premiseState: json['premise_state'] as String? ?? '',
    );
  }
}

class PriceContext {
  const PriceContext({
    required this.fishId,
    this.latestPriceRmPerKg,
    required this.status,
    this.changeVsRecentPct,
    this.history = const <ObservedPricePoint>[],
    required this.disclaimer,
  });

  final String fishId;
  final double? latestPriceRmPerKg;
  final String status;
  final double? changeVsRecentPct;
  final List<ObservedPricePoint> history;
  final String disclaimer;

  bool get isDisplayable => latestPriceRmPerKg != null;

  factory PriceContext.fromJson(Map<String, dynamic> json) {
    return PriceContext(
      fishId: json['fish_id'] as String? ?? '',
      latestPriceRmPerKg: (json['latest_price_rm_per_kg'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'Insufficient data',
      changeVsRecentPct: (json['change_vs_recent_pct'] as num?)?.toDouble(),
      history: (json['history'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ObservedPricePoint.fromJson)
          .toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}
