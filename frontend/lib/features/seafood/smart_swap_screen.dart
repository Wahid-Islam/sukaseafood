import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/api_client.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/fish_ids.dart';
import '../../data/models/cooking_intent.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';

/// Epic 4 — "What should I choose instead?"
///
///   1. Cooking intent   "I want fish curry for 4 people."
///   2. Smart swap       explainable ranking from the API
///   3. Recipe           generated server-side with OpenAI
///
/// Opened from a species profile (`/seafood/:id/swap`, the fish becomes
/// "Your choice") or standalone (`/smart-swap`).
class SmartSwapScreen extends StatefulWidget {
  const SmartSwapScreen({super.key, this.seafoodId, this.initialQuery});

  final String? seafoodId;
  final String? initialQuery;

  @override
  State<SmartSwapScreen> createState() => _SmartSwapScreenState();
}

class _SmartSwapScreenState extends State<SmartSwapScreen> {
  static const Color _green = AppColors.tealDark;
  static const List<String> _suggestions = <String>[
    'Fish curry for 4 people',
    'Steamed fish for 2',
    'Ikan bakar, budget RM15',
    'Fried fish for kids',
  ];

  final ApiClient _api = ApiClient();
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  String? _fishId;
  SmartSwapResult? _result;
  bool _loading = false;
  String? _error;

  /// Which ranked fish the recipe step cooks. Defaults to the recommendation;
  /// the user can pick another alternative.
  SwapFish? _chosen;

  final List<Recipe> _recipes = <Recipe>[];
  bool _recipesLoading = false;
  String? _recipesError;
  bool _recipesUnavailable = false;
  int _recipeRequest = 0;

  @override
  void initState() {
    super.initState();
    _fishId = widget.seafoodId == null
        ? null
        : FishIds.canonical(widget.seafoodId!);
    final String initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _query.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runQuery());
    }
  }

  @override
  void dispose() {
    _api.close();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  // --- data -------------------------------------------------------------------

  Future<void> _runQuery() async {
    final String text = _query.text.trim();
    if (text.isEmpty) return;
    _focus.unfocus();
    await _swap(<String, Object?>{'query': text, 'fish_id': _fishId});
  }

  Future<void> _swap(Map<String, Object?> body) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final SmartSwapResult result = await _api.smartSwap(body);
      if (!mounted) return;
      setState(() {
        _result = result;
        _chosen = result.fishToCook;
        _loading = false;
      });
      _loadRecipes(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Re-rank after a chip is removed, without re-parsing the sentence.
  void _removeChip(IntentChip chip) {
    final CookingIntent? intent = _result?.intent;
    if (intent == null) return;
    final Map<String, Object?> body = <String, Object?>{
      'cooking_method': intent.cookingMethod ?? '',
      'dish': intent.dish ?? '',
      'servings': intent.servings,
      'fish_id': intent.fishId ?? '',
      'max_price_rm_per_kg': intent.maxPriceRmPerKg,
      'prefer_affordable': intent.preferAffordable,
      'kid_friendly': intent.kidFriendly,
    };
    switch (chip.key) {
      case 'dish':
        body['cooking_method'] = '';
        body['dish'] = '';
      case 'servings':
        body['servings'] = null;
      case 'fish':
        body['fish_id'] = '';
        _fishId = null;
      case 'budget':
        body['max_price_rm_per_kg'] = null;
        body['prefer_affordable'] = false;
      case 'affordable':
        body['prefer_affordable'] = false;
      case 'kids':
        body['kid_friendly'] = false;
    }
    _swap(body);
  }

  Future<void> _loadRecipes({bool reset = false, int count = 1}) async {
    final SmartSwapResult? result = _result;
    final SwapFish? fish = _chosen;
    if (reset) {
      _recipes.clear();
      _recipesError = null;
      _recipesUnavailable = false;
    }
    if (result == null || fish == null) {
      setState(() {});
      return;
    }
    if (!result.recipesAvailable) {
      setState(() => _recipesUnavailable = true);
      return;
    }
    final int request = ++_recipeRequest;
    setState(() {
      _recipesLoading = true;
      _recipesError = null;
    });
    try {
      final RecipeBatch batch = await _api.generateRecipes(
        fishId: fish.fishId,
        cookingMethod: result.intent.cookingMethod,
        dish: result.intent.dish,
        servings: result.intent.servings ?? 2,
        count: count,
        kidFriendly: result.intent.kidFriendly,
        excludeTitles: _recipes.map((Recipe r) => r.title).toList(),
      );
      if (!mounted || request != _recipeRequest) return;
      setState(() {
        _recipes.addAll(batch.recipes);
        _recipesLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _recipeRequest) return;
      setState(() {
        _recipesLoading = false;
        _recipesUnavailable = e.code == 'RECIPE_UNAVAILABLE';
        _recipesError = e.message;
      });
    }
  }

  void _choose(SwapFish fish) {
    if (_chosen?.fishId == fish.fishId) return;
    setState(() => _chosen = fish);
    _loadRecipes(reset: true);
  }

  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final SwapFish? favTarget = _chosen;
    final bool fav = favTarget != null && catalog.isFavourite(favTarget.fishId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 30),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Save fish',
            icon: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              color: _green,
            ),
            onPressed: favTarget == null
                ? null
                : () => catalog.toggleFavourite(favTarget.fishId),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            const _Header(),
            const SizedBox(height: 18),
            _stepOne(),
            const Divider(height: 36, color: AppColors.line),
            _stepTwo(),
            if (_result?.fishToCook != null) ...[
              const Divider(height: 36, color: AppColors.line),
              _stepThree(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _result?.fishToCook == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _PrimaryButton(
                icon: Icons.soup_kitchen_outlined,
                label: _recipesLoading ? 'Finding recipes…' : 'View more recipes',
                onPressed: _recipesLoading || _recipesUnavailable
                    ? null
                    : () => _loadRecipes(count: 2),
              ),
            ),
    );
  }

  Widget _stepOne() {
    final CookingIntent? intent = _result?.intent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          number: 1,
          title: 'What are you cooking?',
          subtitle:
              'Tell us what you want to make and for how many people. '
              "We'll find the best seafood match for your meal.",
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _runQuery(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'I want to make fish curry for 4 people',
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.chat_bubble_outline, size: 20),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _query.clear();
                      setState(() {});
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(color: _green, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (intent != null && intent.chips.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final IntentChip chip in intent.chips)
                InputChip(
                  label: Text(chip.label),
                  labelStyle: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  backgroundColor: AppColors.tealSoft,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  deleteIconColor: _green,
                  onDeleted: _loading ? null : () => _removeChip(chip),
                ),
            ],
          )
        else if (_result == null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final String s in _suggestions)
                ActionChip(
                  label: Text(s),
                  labelStyle: const TextStyle(fontSize: 12, color: AppColors.ink),
                  backgroundColor: AppColors.foam,
                  side: const BorderSide(color: AppColors.line),
                  shape: const StadiumBorder(),
                  onPressed: () {
                    _query.text = s;
                    _runQuery();
                  },
                ),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                intent?.source == 'llm'
                    ? 'We used AI to read your request, then ranked alternatives on sustainability, price and cooking suitability.'
                    : 'We use your cooking intent to suggest the best alternatives based on sustainability, price and cooking suitability.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepTwo() {
    final SmartSwapResult? result = _result;
    final String subtitle = result == null
        ? 'Based on your cooking intent, we look for a more sustainable and suitable alternative.'
        : result.message;

    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator(color: _green)),
      );
    } else if (_error != null) {
      body = _Notice(
        icon: Icons.cloud_off,
        text: _error!,
        actionLabel: 'Try again',
        onAction: _runQuery,
      );
    } else if (result == null || result.needsIntent) {
      body = const SizedBox.shrink();
    } else {
      body = _comparison(result);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          number: 2,
          title: result?.status == 'ALREADY_GOOD'
              ? 'Your choice is already great'
              : 'Recommended alternative',
          subtitle: subtitle,
        ),
        const SizedBox(height: 14),
        body,
      ],
    );
  }

  Widget _comparison(SmartSwapResult result) {
    final SwapFish? current = result.current;
    final SwapFish? recommended = result.recommended;
    final SwapFish? chosen = _chosen;
    final bool chosenIsAlternative =
        chosen != null && chosen.fishId != recommended?.fishId && chosen.fishId != current?.fishId;
    final SwapFish? right = chosenIsAlternative ? chosen : recommended;

    final List<Widget> cards = <Widget>[];
    if (current != null && right != null) {
      cards.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _FishCard(fish: current, tag: 'Your choice')),
              const _SwapArrow(),
              Expanded(
                child: _FishCard(fish: right, tag: 'Recommended', highlight: true),
              ),
            ],
          ),
        ),
      );
    } else if (right != null || current != null) {
      final SwapFish only = (right ?? current)!;
      cards.add(
        _FishCard(
          fish: only,
          tag: right != null ? 'Recommended' : 'Your choice',
          highlight: right != null,
          noSwap: right == null,
          wide: true,
        ),
      );
    }

    final SwapFish? explained = right;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...cards,
        if (explained != null && explained.reasons.isNotEmpty) ...[
          const SizedBox(height: 12),
          _WhyCard(fish: explained, weights: result.rankingWeights),
        ],
        if (result.alternatives.isNotEmpty || chosenIsAlternative) ...[
          const SizedBox(height: 14),
          const Text(
            'Other good options',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final SwapFish alt in <SwapFish>[
                  ?recommended,
                  ...result.alternatives,
                ])
                  _AltChip(
                    fish: alt,
                    selected: alt.fishId == (right?.fishId),
                    onTap: () => _choose(alt),
                  ),
              ],
            ),
          ),
        ],
        if (result.status == 'NO_BETTER_OPTION') ...[
          const SizedBox(height: 10),
          const _Notice(
            icon: Icons.info_outline,
            text: 'You can still cook your choice — recipes below use it.',
          ),
        ],
      ],
    );
  }

  Widget _stepThree() {
    final SwapFish fish = _chosen ?? _result!.fishToCook!;
    Widget body;
    if (_recipesUnavailable) {
      body = const _Notice(
        icon: Icons.menu_book_outlined,
        text:
            'Recipe suggestions are not switched on for this server yet '
            '(no OpenAI key configured).',
      );
    } else {
      body = Column(
        children: [
          for (final Recipe recipe in _recipes) ...[
            _RecipeTile(
              recipe: recipe,
              fish: fish,
              onTap: () => context.push('/recipe', extra: recipe),
            ),
            const SizedBox(height: 10),
          ],
          if (_recipesLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                  ),
                  SizedBox(width: 10),
                  Text('Cooking up recipe ideas…'),
                ],
              ),
            ),
          if (_recipesError != null && !_recipesLoading)
            _Notice(
              icon: Icons.error_outline,
              text: _recipesError!,
              actionLabel: 'Retry',
              onAction: () => _loadRecipes(),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          number: 3,
          title: 'Find your recipe',
          subtitle:
              'Now that you\'ve selected ${fish.name} and your cooking intent, '
              'browse recipes that match your dish and ingredients.',
        ),
        const SizedBox(height: 12),
        body,
      ],
    );
  }
}

// --- pieces -------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.tealDark,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Better Choice',
                style: TextStyle(fontSize: 11, color: AppColors.tealDark, fontWeight: FontWeight.w700),
              ),
              Text(
                'Smart Swap & Cooking Intent',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              SizedBox(height: 2),
              Text(
                'Get a more sustainable alternative and find recipes that match your cooking needs.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.tealSoft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.soup_kitchen_outlined, size: 36, color: AppColors.tealDark),
              Positioned(
                right: 8,
                bottom: 8,
                child: Icon(Icons.eco, size: 22, color: AppColors.good),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.title, required this.subtitle});

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.tealDark, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

Color _wwfColour(String colour) {
  switch (colour) {
    case 'Green':
      return AppColors.good;
    case 'Yellow':
      return const Color(0xFFF2C94C);
    case 'Red':
      return AppColors.avoid;
    default:
      return AppColors.muted;
  }
}

class _FishCard extends StatelessWidget {
  const _FishCard({
    required this.fish,
    required this.tag,
    this.highlight = false,
    this.noSwap = false,
    this.wide = false,
  });

  final SwapFish fish;
  final String tag;
  final bool highlight;
  final bool noSwap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final bool better = fish.isBetterChoice;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/seafood/${fish.fishId}'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: highlight ? AppColors.teal : AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: highlight ? AppColors.tealDark : AppColors.headerTeal,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: CatalogueFishArt(
                fishId: fish.fishId,
                networkUrl: fish.imageUrl,
                width: wide ? 220 : 130,
                height: wide ? 110 : 70,
                borderRadius: 10,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 6),
            Text(fish.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink)),
            Text(
              fish.scientificName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.tealDark),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  better ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: better ? AppColors.good : AppColors.reduce,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    better
                        ? 'Better choice'
                        : highlight
                        ? 'Better than your choice'
                        : noSwap
                        ? 'No better-rated swap on file'
                        : 'Consider: Better options available',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: better ? AppColors.good : AppColors.reduce,
                    ),
                  ),
                ),
              ],
            ),
            if (fish.cookingScore != null) ...[
              const SizedBox(height: 4),
              Text(
                '${fish.cookingScore}/5 for ${fish.cookingMethod}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ],
            if (wide) const SizedBox(height: 4) else const Spacer(),
            const Divider(height: 14, color: AppColors.line),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WWF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 9, color: _wwfColour(fish.wwfColour)),
                        const SizedBox(width: 4),
                        Text(fish.wwfColour, style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fish.priceRmPerKg == null
                          ? 'No price'
                          : 'RM ${fish.priceRmPerKg!.toStringAsFixed(2)} / kg',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      fish.priceRmPerKg == null ? 'on file' : '(latest)',
                      style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapArrow extends StatelessWidget {
  const _SwapArrow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Center(
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: AppColors.tealSoft, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_forward, size: 16, color: AppColors.tealDark),
        ),
      ),
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.fish, required this.weights});

  final SwapFish fish;
  final Map<String, double> weights;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, double)> rows = <(String, String, double)>[
      ('Sustainability', 'sustainability', fish.breakdown.sustainability),
      ('Cooking suitability', 'cooking', fish.breakdown.cooking),
      ('Price', 'price', fish.breakdown.price),
      ('Food-use attributes', 'attributes', fish.breakdown.attributes),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.foam,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            'Why ${fish.name}? · match ${fish.score}/100',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          children: [
            for (final String reason in fish.reasons)
              _Bullet(icon: Icons.check, color: AppColors.good, text: reason),
            for (final String caveat in fish.caveats)
              _Bullet(icon: Icons.info_outline, color: AppColors.reduce, text: caveat),
            const SizedBox(height: 8),
            for (final (String label, String key, double value) in rows)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        '$label · ${((weights[key] ?? 0) * 100).round()}%',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: value.clamp(0.0, 1.0),
                          minHeight: 6,
                          color: AppColors.tealDark,
                          backgroundColor: AppColors.line,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.ink))),
        ],
      ),
    );
  }
}

class _AltChip extends StatelessWidget {
  const _AltChip({required this.fish, required this.selected, required this.onTap});

  final SwapFish fish;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.tealSoft : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.teal : AppColors.line),
          ),
          child: Row(
            children: [
              CatalogueFishArt(
                fishId: fish.fishId,
                networkUrl: fish.imageUrl,
                width: 52,
                height: 44,
                borderRadius: 10,
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fish.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: _wwfColour(fish.wwfColour)),
                      const SizedBox(width: 4),
                      Text(
                        '${fish.score}/100',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe, required this.fish, required this.onTap});

  final Recipe recipe;
  final SwapFish fish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            CatalogueFishArt(
              fishId: fish.fishId,
              networkUrl: fish.imageUrl,
              width: 96,
              height: 76,
              borderRadius: 12,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 13, color: AppColors.tealDark),
                      const SizedBox(width: 3),
                      Text('${recipe.timeMinutes} mins', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.soup_kitchen_outlined, size: 13, color: AppColors.tealDark),
                      const SizedBox(width: 3),
                      Text(recipe.difficulty, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.foam, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.tealDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
