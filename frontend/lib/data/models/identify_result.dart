/// Response models for `POST /identify`.
///
/// The scanner never settles an identity. It returns ranked suggestions and the
/// user confirms one, so these models deliberately carry no "the fish is X"
/// field — only candidates and the confidence behind each.
library;

/// One ranked candidate, already resolved to a canonical seafood item.
class IdentifyCandidate {
  const IdentifyCandidate({
    required this.rank,
    required this.seafoodItemId,
    required this.code,
    required this.canonicalNameMs,
    required this.displayNameEn,
    required this.scientificName,
    required this.confidence,
  });

  final int rank;

  /// The canonical key. Sustainability, price, cooking and favourites all take
  /// this id (or [code]) — never a display name.
  final String seafoodItemId;

  /// Readable public identifier, `SF001`…, used in route paths.
  final String code;

  final String canonicalNameMs;
  final String displayNameEn;
  final String scientificName;
  final double confidence;

  factory IdentifyCandidate.fromJson(Map<String, dynamic> json) {
    return IdentifyCandidate(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      seafoodItemId: json['seafood_item_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      canonicalNameMs: json['canonical_name_ms'] as String? ?? '',
      displayNameEn: json['display_name_en'] as String? ?? '',
      scientificName: json['scientific_name'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// The whole `/identify` result.
class IdentifyResult {
  const IdentifyResult({
    required this.status,
    required this.modelVersion,
    required this.confirmationRequired,
    required this.candidates,
  });

  /// `CANDIDATES` when the top candidate cleared the model's validated
  /// threshold, `LOW_CONFIDENCE` when it did not. Both arrive on HTTP 200 and
  /// both carry candidates — the difference is how firmly the UI may present
  /// them, not whether there is an answer.
  final String status;

  final String modelVersion;
  final bool confirmationRequired;
  final List<IdentifyCandidate> candidates;

  bool get isLowConfidence => status == 'LOW_CONFIDENCE';

  factory IdentifyResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['candidates'] as List<dynamic>?) ?? const <dynamic>[];
    return IdentifyResult(
      status: json['status'] as String? ?? 'LOW_CONFIDENCE',
      modelVersion: json['model_version'] as String? ?? 'unknown',
      confirmationRequired: json['confirmation_required'] as bool? ?? true,
      candidates:
          raw
              .whereType<Map<String, dynamic>>()
              .map(IdentifyCandidate.fromJson)
              .toList()
            ..sort(
              (IdentifyCandidate a, IdentifyCandidate b) =>
                  a.rank.compareTo(b.rank),
            ),
    );
  }
}
