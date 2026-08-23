/// Shared API models for SukaSeafood.
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

  factory SeafoodSummary.fromJson(Map<String, dynamic> json) {
    return SeafoodSummary(
      fishId: json['fish_id'] as String,
      scientificName: json['scientific_name'] as String,
      primaryCommonName: json['primary_common_name'] as String,
      fishType: json['fish_type'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      classification: json['classification'] as String?,
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
      classification: json['classification'] as String,
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

class SupplyInfo {
  const SupplyInfo({
    required this.summary,
    required this.trendLabel,
    required this.sourceName,
  });

  final String summary;
  final String trendLabel;
  final String sourceName;

  factory SupplyInfo.fromJson(Map<String, dynamic> json) {
    return SupplyInfo(
      summary: json['summary'] as String? ?? '',
      trendLabel: json['trend_label'] as String? ?? '',
      sourceName: json['source_name'] as String? ?? '',
    );
  }
}

class CookingInfo {
  const CookingInfo({
    required this.method,
    required this.suitabilityScore,
    required this.rationale,
    required this.verified,
  });

  final String method;
  final double suitabilityScore;
  final String rationale;
  final bool verified;

  factory CookingInfo.fromJson(Map<String, dynamic> json) {
    return CookingInfo(
      method: json['method'] as String,
      suitabilityScore: (json['suitability_score'] as num).toDouble(),
      rationale: json['rationale'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
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
    required this.aliases,
    required this.cooking,
    this.imageUrl,
    this.sustainability,
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
  final List<String> aliases;
  final SustainabilityInfo? sustainability;
  final List<CookingInfo> cooking;
  final SupplyInfo? supply;

  factory SeafoodProfile.fromJson(Map<String, dynamic> json) {
    final List<dynamic> aliasRows = json['aliases'] as List<dynamic>? ?? [];
    final List<dynamic> cookingRows = json['cooking'] as List<dynamic>? ?? [];
    return SeafoodProfile(
      fishId: json['fish_id'] as String,
      scientificName: json['scientific_name'] as String,
      primaryCommonName: json['primary_common_name'] as String,
      fishType: json['fish_type'] as String? ?? '',
      commonIn: json['common_in'] as String? ?? '',
      marketAvailability: json['market_availability'] as String? ?? '',
      about: json['about'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      aliases: aliasRows
          .map((dynamic e) => (e as Map<String, dynamic>)['alias'] as String)
          .toList(),
      sustainability: json['sustainability'] == null
          ? null
          : SustainabilityInfo.fromJson(
              json['sustainability'] as Map<String, dynamic>,
            ),
      cooking: cookingRows
          .map((dynamic e) => CookingInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      supply: json['supply'] == null
          ? null
          : SupplyInfo.fromJson(json['supply'] as Map<String, dynamic>),
    );
  }
}

class PricePoint {
  const PricePoint({
    required this.observedDate,
    required this.priceRmPerKg,
  });

  final DateTime observedDate;
  final double priceRmPerKg;

  factory PricePoint.fromJson(Map<String, dynamic> json) {
    return PricePoint(
      observedDate: DateTime.parse(json['observed_date'] as String),
      priceRmPerKg: (json['price_rm_per_kg'] as num).toDouble(),
    );
  }
}

class PriceContext {
  const PriceContext({
    required this.fishId,
    required this.status,
    required this.history,
    required this.disclaimer,
    this.latestPriceRmPerKg,
    this.changeVsRecentPct,
  });

  final String fishId;
  final double? latestPriceRmPerKg;
  final String status;
  final double? changeVsRecentPct;
  final List<PricePoint> history;
  final String disclaimer;

  factory PriceContext.fromJson(Map<String, dynamic> json) {
    final List<dynamic> historyRows = json['history'] as List<dynamic>? ?? [];
    return PriceContext(
      fishId: json['fish_id'] as String,
      latestPriceRmPerKg: (json['latest_price_rm_per_kg'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'Unavailable',
      changeVsRecentPct: (json['change_vs_recent_pct'] as num?)?.toDouble(),
      history: historyRows
          .map((dynamic e) => PricePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

class IdentifyCandidate {
  const IdentifyCandidate({
    required this.fishId,
    required this.primaryCommonName,
    required this.scientificName,
    required this.confidence,
  });

  final String fishId;
  final String primaryCommonName;
  final String scientificName;
  final double confidence;

  factory IdentifyCandidate.fromJson(Map<String, dynamic> json) {
    return IdentifyCandidate(
      fishId: json['fish_id'] as String,
      primaryCommonName: json['primary_common_name'] as String,
      scientificName: json['scientific_name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class IdentifyResult {
  const IdentifyResult({
    required this.modelVersion,
    required this.topPrediction,
    required this.alternatives,
    required this.requiresUserConfirmation,
    required this.isMock,
  });

  final String modelVersion;
  final IdentifyCandidate topPrediction;
  final List<IdentifyCandidate> alternatives;
  final bool requiresUserConfirmation;
  final bool isMock;

  factory IdentifyResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> alts = json['alternatives'] as List<dynamic>? ?? [];
    return IdentifyResult(
      modelVersion: json['model_version'] as String,
      topPrediction: IdentifyCandidate.fromJson(
        json['top_prediction'] as Map<String, dynamic>,
      ),
      alternatives: alts
          .map(
            (dynamic e) =>
                IdentifyCandidate.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      requiresUserConfirmation:
          json['requires_user_confirmation'] as bool? ?? true,
      isMock: json['is_mock'] as bool? ?? true,
    );
  }
}
