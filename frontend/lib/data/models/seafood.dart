/// Live catalogue models matching `GET /seafood` and `GET /seafood/{id}`.
library;

class SeafoodSummary {
  const SeafoodSummary({
    required this.fishId,
    required this.scientificName,
    required this.primaryCommonName,
    required this.fishType,
    this.displayNameEn = '',
    this.imageUrl,
    this.classification,
    this.description = '',
    this.suitableMethods = const <String>[],
    this.cookingScores = const <String, int>{},
  });

  final String fishId;
  final String scientificName;
  final String primaryCommonName;
  final String displayNameEn;
  final String fishType;
  final String? imageUrl;
  final String? classification;
  final String description;
  final List<String> suitableMethods;
  final Map<String, int> cookingScores;

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
      displayNameEn: json['display_name_en'] as String? ?? '',
      fishType: json['fish_type'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      classification: json['classification'] as String?,
      description: json['description'] as String? ?? '',
      suitableMethods: (json['suitable_methods'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((String e) => e.toLowerCase())
          .toList(),
      cookingScores: _scoresFromJson(json['cooking_scores']),
    );
  }

  static Map<String, int> _scoresFromJson(Object? raw) {
    if (raw is! Map) return const <String, int>{};
    return <String, int>{
      for (final MapEntry<dynamic, dynamic> e in raw.entries)
        if (e.key is String && e.value is num)
          (e.key as String).toLowerCase(): (e.value as num).round(),
    };
  }

  /// Malay, English and scientific names for search hits.
  String get namesSubtitle {
    final List<String> parts = <String>[
      if (displayNameEn.isNotEmpty) displayNameEn,
      if (scientificName.isNotEmpty) scientificName,
    ];
    return parts.join(' · ');
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

class MethodRating {
  const MethodRating({
    required this.classification,
    required this.productionMethod,
    required this.productionMethodCode,
    required this.origin,
    required this.explanation,
  });

  final String classification;
  final String productionMethod;
  final String productionMethodCode;
  final String origin;
  final String explanation;

  factory MethodRating.fromJson(Map<String, dynamic> json) {
    return MethodRating(
      classification: json['classification'] as String? ?? 'UNDETERMINED',
      productionMethod: json['production_method'] as String? ?? '',
      productionMethodCode:
          json['production_method_code'] as String? ?? 'OTHER',
      origin: json['origin'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
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
    this.assessments = const <MethodRating>[],
  });

  final String classification;
  final String origin;
  final String productionMethod;
  final String explanation;
  final String whyItMatters;
  final String sourceName;
  final String sourceUrl;
  final bool verified;
  final List<MethodRating> assessments;

  /// Method-specific WWF rows, or a single fallback from the summary fields.
  List<MethodRating> get methodRatings {
    if (assessments.isNotEmpty) return assessments;
    if (!verified) return const <MethodRating>[];
    return <MethodRating>[
      MethodRating(
        classification: classification,
        productionMethod: productionMethod,
        productionMethodCode: 'OTHER',
        origin: origin,
        explanation: explanation,
      ),
    ];
  }

  bool get ratingVaries => methodRatings.length > 1;

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
      assessments: (json['assessments'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(MethodRating.fromJson)
          .toList(),
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

class OccurrencePoint {
  const OccurrencePoint({
    required this.latitude,
    required this.longitude,
    this.country,
    this.locality,
    this.eventDate,
  });

  final double latitude;
  final double longitude;
  final String? country;
  final String? locality;
  final String? eventDate;

  factory OccurrencePoint.fromJson(Map<String, dynamic> json) {
    return OccurrencePoint(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      country: json['country'] as String?,
      locality: json['locality'] as String?,
      eventDate: json['event_date'] as String?,
    );
  }
}

class BiodiversitySource {
  const BiodiversitySource({
    required this.key,
    required this.name,
    required this.available,
    this.url = '',
    this.unavailableReason,
  });

  final String key;
  final String name;
  final bool available;
  final String url;
  final String? unavailableReason;

  factory BiodiversitySource.fromJson(Map<String, dynamic> json) {
    return BiodiversitySource(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      url: json['url'] as String? ?? '',
      unavailableReason: json['unavailable_reason'] as String?,
    );
  }
}

class BiodiversityContext {
  const BiodiversityContext({
    this.family,
    this.habitatGroup,
    this.taxonomicLevel,
    this.ecosystemNote,
    this.depthShallowM,
    this.depthDeepM,
    this.ecologicalRole,
    this.iucnCategory,
    this.iucnLabel,
    this.iucnUrl,
    this.fishbaseUrl,
    this.populationTrend,
    this.mybisNationalStatus,
    this.occurrences = const <OccurrencePoint>[],
    this.sources = const <BiodiversitySource>[],
    required this.available,
    required this.sourceName,
    this.sourceUrl = '',
    this.unavailableReason,
  });

  final String? family;
  final String? habitatGroup;
  final String? taxonomicLevel;
  final String? ecosystemNote;
  final double? depthShallowM;
  final double? depthDeepM;
  final String? ecologicalRole;
  final String? iucnCategory;
  final String? iucnLabel;
  final String? iucnUrl;
  final String? fishbaseUrl;
  final String? populationTrend;
  final String? mybisNationalStatus;
  final List<OccurrencePoint> occurrences;
  final List<BiodiversitySource> sources;
  final bool available;
  final String sourceName;
  final String sourceUrl;
  final String? unavailableReason;

  String? get depthLabel {
    if (depthShallowM == null && depthDeepM == null) return null;
    if (depthShallowM != null && depthDeepM != null) {
      return '${_prettyMetres(depthShallowM!)} – ${_prettyMetres(depthDeepM!)} metres';
    }
    final double only = depthShallowM ?? depthDeepM!;
    return '${_prettyMetres(only)} metres';
  }

  String? get habitatLabel {
    final String? raw = habitatGroup?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw
        .split(RegExp(r'[-_/]'))
        .where((String p) => p.isNotEmpty)
        .map(
          (String p) =>
              '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}',
        )
        .join('-');
  }

  String? get iucnBadge {
    final String? code = iucnCategory?.trim();
    final String? label = iucnLabel?.trim();
    if (code == null || code.isEmpty) return null;
    if (label == null || label.isEmpty) return code;
    return '$label ($code)';
  }

  factory BiodiversityContext.fromJson(Map<String, dynamic> json) {
    return BiodiversityContext(
      family: json['family'] as String?,
      habitatGroup: json['habitat_group'] as String?,
      taxonomicLevel: json['taxonomic_level'] as String?,
      ecosystemNote: json['ecosystem_note'] as String?,
      depthShallowM: (json['depth_shallow_m'] as num?)?.toDouble(),
      depthDeepM: (json['depth_deep_m'] as num?)?.toDouble(),
      ecologicalRole: json['ecological_role'] as String?,
      iucnCategory: json['iucn_category'] as String?,
      iucnLabel: json['iucn_label'] as String?,
      iucnUrl: json['iucn_url'] as String?,
      fishbaseUrl: json['fishbase_url'] as String?,
      populationTrend: json['population_trend'] as String?,
      mybisNationalStatus: json['mybis_national_status'] as String?,
      occurrences: (json['occurrences'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(OccurrencePoint.fromJson)
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(BiodiversitySource.fromJson)
          .toList(),
      available: json['available'] as bool? ?? false,
      sourceName: json['source_name'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
      unavailableReason: json['unavailable_reason'] as String?,
    );
  }

  static String _prettyMetres(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  /// Honest fallback when an older API payload has no biodiversity block.
  factory BiodiversityContext.fromCatalogue({
    required String fishType,
    String? family,
    SustainabilityInfo? sustainability,
  }) {
    return BiodiversityContext(
      family: (family ?? '').trim().isEmpty ? null : family,
      available: false,
      sourceName: 'SukaSeafood catalogue',
      unavailableReason:
          'No independent biodiversity extract is on file for this species. '
          'Habitat, depth, IUCN status and map points are not invented.',
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
    this.displayNameEn = '',
    this.family,
    this.imageUrl,
    this.aliases = const <SeafoodAlias>[],
    this.sustainability,
    this.biodiversity,
    this.cooking = const <CookingSuitability>[],
  });

  final String fishId;
  final String scientificName;
  final String primaryCommonName;
  final String displayNameEn;
  final String fishType;
  final String? family;
  final String commonIn;
  final String marketAvailability;
  final String about;
  final String? imageUrl;
  final List<SeafoodAlias> aliases;
  final SustainabilityInfo? sustainability;
  final BiodiversityContext? biodiversity;
  final List<CookingSuitability> cooking;

  String get shortName {
    final int cut = primaryCommonName.indexOf(' / ');
    return cut < 0 ? primaryCommonName : primaryCommonName.substring(0, cut);
  }

  String get alsoKnownAs {
    final Set<String> skip = <String>{
      shortName.toLowerCase(),
      primaryCommonName.toLowerCase(),
    };
    final List<String> names = <String>[
      if (displayNameEn.isNotEmpty &&
          !skip.contains(displayNameEn.toLowerCase()))
        displayNameEn,
      ...aliases
          .where((SeafoodAlias a) => !skip.contains(a.alias.toLowerCase()))
          .map((SeafoodAlias a) => a.alias),
    ];
    return names.take(4).join(', ');
  }

  String get classification => sustainability?.classification ?? 'UNDETERMINED';

  BiodiversityContext get biodiversityContext =>
      biodiversity ??
      BiodiversityContext.fromCatalogue(
        fishType: fishType,
        family: family,
        sustainability: sustainability,
      );

  factory SeafoodProfile.fromJson(Map<String, dynamic> json) {
    final SustainabilityInfo? sustainability =
        json['sustainability'] is Map<String, dynamic>
        ? SustainabilityInfo.fromJson(
            json['sustainability'] as Map<String, dynamic>,
          )
        : null;
    return SeafoodProfile(
      fishId: json['fish_id'] as String? ?? '',
      scientificName: json['scientific_name'] as String? ?? '',
      primaryCommonName: json['primary_common_name'] as String? ?? '',
      displayNameEn: json['display_name_en'] as String? ?? '',
      fishType: json['fish_type'] as String? ?? '',
      family: json['family'] as String?,
      commonIn: json['common_in'] as String? ?? '',
      marketAvailability: json['market_availability'] as String? ?? '',
      about: json['about'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      aliases: (json['aliases'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SeafoodAlias.fromJson)
          .toList(),
      sustainability: sustainability,
      biodiversity: json['biodiversity'] is Map<String, dynamic>
          ? BiodiversityContext.fromJson(
              json['biodiversity'] as Map<String, dynamic>,
            )
          : null,
      cooking: (json['cooking'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CookingSuitability.fromJson)
          .toList(),
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

  bool get isDisplayable => observedPriceRmPerKg != null;

  /// Latest weekly PriceCatcher median. Prefers history so current price
  /// and week-over-week use the same series.
  double? get observedPriceRmPerKg =>
      history.isNotEmpty ? history.last.priceRmPerKg : latestPriceRmPerKg;

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
