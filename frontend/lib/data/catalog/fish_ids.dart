/// Canonical `fish_id` values (`SF001`…`SF015`).
///
/// Older screens and notifications used prototype slugs (`tenggiri`). The API
/// only accepts the code or a UUID, so anything arriving as a slug is mapped
/// here. Unknown values pass through unchanged.
class FishIds {
  FishIds._();

  static const Map<String, String> legacySlugs = <String, String>{
    'kembung': 'SF001',
    'bawal_hitam': 'SF002',
    'ikan_merah': 'SF003',
    'tilapia': 'SF004',
    'kerapu': 'SF005',
    'bawal_putih': 'SF006',
    'cencaru': 'SF007',
    'jenahak': 'SF008',
    'kerisi': 'SF009',
    'pelata': 'SF010',
    'selar': 'SF011',
    'tenggiri': 'SF012',
    'demuduk': 'SF013',
    'siakap': 'SF014',
    'tongkol': 'SF015',
  };

  static String canonical(String id) {
    final String trimmed = id.trim();
    if (trimmed.toUpperCase().startsWith('SF')) {
      return trimmed.toUpperCase();
    }
    return legacySlugs[trimmed.toLowerCase()] ?? trimmed;
  }
}
