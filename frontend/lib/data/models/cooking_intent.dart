/// Epic 4 models: `POST /smart-swap` and `POST /recipes/generate`.
library;

class IntentChip {
  const IntentChip({required this.key, required this.label});

  /// dish · servings · fish · budget · affordable · kids
  final String key;
  final String label;

  factory IntentChip.fromJson(Map<String, dynamic> json) => IntentChip(
    key: json['key'] as String? ?? '',
    label: json['label'] as String? ?? '',
  );
}

class CookingIntent {
  const CookingIntent({
    this.rawQuery = '',
    this.dish,
    this.cookingMethod,
    this.servings,
    this.fishId,
    this.fishName,
    this.maxPriceRmPerKg,
    this.preferAffordable = false,
    this.kidFriendly = false,
    this.source = 'rules',
    this.inferredFields = const <String>[],
    this.chips = const <IntentChip>[],
  });

  final String rawQuery;
  final String? dish;
  final String? cookingMethod;
  final int? servings;
  final String? fishId;
  final String? fishName;
  final double? maxPriceRmPerKg;
  final bool preferAffordable;
  final bool kidFriendly;
  final String source;
  final List<String> inferredFields;
  final List<IntentChip> chips;

  factory CookingIntent.fromJson(Map<String, dynamic> json) => CookingIntent(
    rawQuery: json['raw_query'] as String? ?? '',
    dish: json['dish'] as String?,
    cookingMethod: json['cooking_method'] as String?,
    servings: (json['servings'] as num?)?.toInt(),
    fishId: json['fish_id'] as String?,
    fishName: json['fish_name'] as String?,
    maxPriceRmPerKg: (json['max_price_rm_per_kg'] as num?)?.toDouble(),
    preferAffordable: json['prefer_affordable'] as bool? ?? false,
    kidFriendly: json['kid_friendly'] as bool? ?? false,
    source: json['source'] as String? ?? 'rules',
    inferredFields: (json['inferred_fields'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    chips: (json['chips'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(IntentChip.fromJson)
        .toList(),
  );
}

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.sustainability,
    required this.cooking,
    required this.price,
    required this.attributes,
  });

  final double sustainability;
  final double cooking;
  final double price;
  final double attributes;

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) => ScoreBreakdown(
    sustainability: (json['sustainability'] as num?)?.toDouble() ?? 0,
    cooking: (json['cooking'] as num?)?.toDouble() ?? 0,
    price: (json['price'] as num?)?.toDouble() ?? 0,
    attributes: (json['attributes'] as num?)?.toDouble() ?? 0,
  );
}

class SwapFish {
  const SwapFish({
    required this.fishId,
    required this.name,
    required this.displayNameEn,
    required this.scientificName,
    required this.fishType,
    required this.classification,
    required this.wwfColour,
    required this.isBetterChoice,
    required this.score,
    required this.breakdown,
    this.imageUrl,
    this.cookingMethod,
    this.cookingScore,
    this.cookingNote,
    this.priceRmPerKg,
    this.priceStatus = 'Insufficient data',
    this.reasons = const <String>[],
    this.caveats = const <String>[],
  });

  final String fishId;
  final String name;
  final String displayNameEn;
  final String scientificName;
  final String fishType;
  final String? imageUrl;
  final String classification;
  final String wwfColour;
  final bool isBetterChoice;
  final String? cookingMethod;
  final int? cookingScore;
  final String? cookingNote;
  final double? priceRmPerKg;
  final String priceStatus;
  final int score;
  final ScoreBreakdown breakdown;
  final List<String> reasons;
  final List<String> caveats;

  factory SwapFish.fromJson(Map<String, dynamic> json) => SwapFish(
    fishId: json['fish_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    displayNameEn: json['display_name_en'] as String? ?? '',
    scientificName: json['scientific_name'] as String? ?? '',
    fishType: json['fish_type'] as String? ?? '',
    imageUrl: json['image_url'] as String?,
    classification: json['classification'] as String? ?? 'UNDETERMINED',
    wwfColour: json['wwf_colour'] as String? ?? 'Unrated',
    isBetterChoice: json['is_better_choice'] as bool? ?? false,
    cookingMethod: json['cooking_method'] as String?,
    cookingScore: (json['cooking_score'] as num?)?.toInt(),
    cookingNote: json['cooking_note'] as String?,
    priceRmPerKg: (json['price_rm_per_kg'] as num?)?.toDouble(),
    priceStatus: json['price_status'] as String? ?? 'Insufficient data',
    score: (json['score'] as num?)?.toInt() ?? 0,
    breakdown: ScoreBreakdown.fromJson(
      json['score_breakdown'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
    ),
    reasons: (json['reasons'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    caveats: (json['caveats'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
  );
}

class SmartSwapResult {
  const SmartSwapResult({
    required this.intent,
    required this.status,
    required this.message,
    required this.recipesAvailable,
    required this.disclaimer,
    this.current,
    this.recommended,
    this.alternatives = const <SwapFish>[],
    this.rankingWeights = const <String, double>{},
  });

  final CookingIntent intent;

  /// SWAP_FOUND · ALREADY_GOOD · NO_BETTER_OPTION · NEEDS_INTENT
  final String status;
  final String message;
  final SwapFish? current;
  final SwapFish? recommended;
  final List<SwapFish> alternatives;
  final Map<String, double> rankingWeights;
  final bool recipesAvailable;
  final String disclaimer;

  bool get needsIntent => status == 'NEEDS_INTENT';

  /// The fish the recipe step should cook: the swap if there is one,
  /// otherwise the user's own (already good, or no better option on file).
  SwapFish? get fishToCook => recommended ?? current;

  factory SmartSwapResult.fromJson(Map<String, dynamic> json) {
    SwapFish? fish(String key) => json[key] is Map<String, dynamic>
        ? SwapFish.fromJson(json[key] as Map<String, dynamic>)
        : null;
    return SmartSwapResult(
      intent: CookingIntent.fromJson(
        json['intent'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      status: json['status'] as String? ?? 'NEEDS_INTENT',
      message: json['message'] as String? ?? '',
      current: fish('current'),
      recommended: fish('recommended'),
      alternatives: (json['alternatives'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SwapFish.fromJson)
          .toList(),
      rankingWeights:
          (json['ranking_weights'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})
              .map((k, v) => MapEntry(k, (v as num).toDouble())),
      recipesAvailable: json['recipes_available'] as bool? ?? false,
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.quantity,
    this.emoji = '',
    this.note = '',
  });

  final String name;
  final String quantity;
  final String emoji;
  final String note;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
}

class RecipeStep {
  const RecipeStep({required this.step, required this.instruction, this.minutes});

  final int step;
  final String instruction;
  final int? minutes;

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    step: (json['step'] as num?)?.toInt() ?? 0,
    instruction: json['instruction'] as String? ?? '',
    minutes: (json['minutes'] as num?)?.toInt(),
  );
}

class Recipe {
  const Recipe({
    required this.recipeId,
    required this.title,
    required this.description,
    required this.fishId,
    required this.fishName,
    required this.timeMinutes,
    required this.difficulty,
    required this.servings,
    this.cookingMethod,
    this.tags = const <String>[],
    this.ingredients = const <RecipeIngredient>[],
    this.steps = const <RecipeStep>[],
    this.tips = const <String>[],
  });

  final String recipeId;
  final String title;
  final String description;
  final String fishId;
  final String fishName;
  final String? cookingMethod;
  final int timeMinutes;
  final String difficulty;
  final int servings;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> tips;

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    recipeId: json['recipe_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    fishId: json['fish_id'] as String? ?? '',
    fishName: json['fish_name'] as String? ?? '',
    cookingMethod: json['cooking_method'] as String?,
    timeMinutes: (json['time_minutes'] as num?)?.toInt() ?? 30,
    difficulty: json['difficulty'] as String? ?? 'Beginner',
    servings: (json['servings'] as num?)?.toInt() ?? 2,
    tags: (json['tags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    ingredients: (json['ingredients'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RecipeIngredient.fromJson)
        .toList(),
    steps: (json['steps'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RecipeStep.fromJson)
        .toList(),
    tips: (json['tips'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
  );
}

class RecipeBatch {
  const RecipeBatch({
    required this.fishId,
    required this.recipes,
    required this.generatedBy,
    required this.disclaimer,
  });

  final String fishId;
  final List<Recipe> recipes;
  final String generatedBy;
  final String disclaimer;

  factory RecipeBatch.fromJson(Map<String, dynamic> json) => RecipeBatch(
    fishId: json['fish_id'] as String? ?? '',
    recipes: (json['recipes'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Recipe.fromJson)
        .toList(),
    generatedBy: json['generated_by'] as String? ?? '',
    disclaimer: json['disclaimer'] as String? ?? '',
  );
}
