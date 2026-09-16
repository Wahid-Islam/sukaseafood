import 'dart:async';

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
import '../cooking/recipe_image.dart';

/// Epic 4 — Cooking Intent → Smart Swap → Recipes.
///
/// Two views on one route, matching the designs:
///
///   * Cooking Intent (page 1): the sentence, optional preferences, "What we'll
///     consider", and the "Finding your better match…" progress card.
///   * Smart Swap (page 2): "We understand your request as", the swap cards,
///     "Why <fish>?", and three recipe photo cards.
///
/// The results view is only revealed once all three steps are done — the swap
/// is ranked, three recipes are written and their photos have been pre-loaded
/// (or given up on after a timeout) — so the user lands on a finished page.
class SmartSwapScreen extends StatefulWidget {
  const SmartSwapScreen({super.key, this.seafoodId, this.initialQuery});

  final String? seafoodId;
  final String? initialQuery;

  @override
  State<SmartSwapScreen> createState() => _SmartSwapScreenState();
}

const Color _kInk = Color(0xFF0B2545);
const Color _kTeal = AppColors.tealDark;
const Color _kPage = Color(0xFFF5F9FA);

const List<(String, String)> _kMethods = <(String, String)>[
  ('fry', 'Frying'),
  ('grill', 'Grilling'),
  ('steam', 'Steaming'),
  ('curry', 'Curry'),
  ('soup', 'Soup'),
  ('bake', 'Baking'),
];

const List<(String, String, double?)> _kBudgets = <(String, String, double?)>[
  ('any', 'Any budget', null),
  ('15', 'Under RM 15/kg', 15.0),
  ('25', 'Under RM 25/kg', 25.0),
  ('40', 'Under RM 40/kg', 40.0),
];

const List<(String?, String)> _kDifficulties = <(String?, String)>[
  (null, 'Any level'),
  ('Beginner', 'Easy'),
  ('Intermediate', 'Medium'),
  ('Advanced', 'Hard'),
];

/// (key, label, text sent to the recipe writer)
const List<(String, String, String?)> _kDietary = <(String, String, String?)>[
  ('none', 'No preference', null),
  ('kids', 'Kid friendly', null),
  ('mild', 'Low spice', 'Low spice, mild chilli'),
  ('no_coconut', 'No coconut milk', 'No coconut milk or santan'),
  ('less_oil', 'Less oil', 'Less oil; avoid deep-frying where possible'),
];

String _methodLabel(String? code) {
  for (final (String key, String label) in _kMethods) {
    if (key == code) return label;
  }
  return 'Not set';
}

String _methodWord(String? code) {
  switch (code) {
    case 'fry':
      return 'frying';
    case 'grill':
      return 'grilling';
    case 'steam':
      return 'steaming';
    case 'bake':
      return 'baking';
    case 'curry':
      return 'curry';
    case 'soup':
      return 'soup';
    default:
      return 'this dish';
  }
}

String _peopleText(int n) => n == 1 ? '1 person' : '$n people';

Color _wwfColour(String colour) {
  switch (colour) {
    case 'Green':
      return AppColors.good;
    case 'Yellow':
      return const Color(0xFFF2B705);
    case 'Red':
      return AppColors.avoid;
    default:
      return AppColors.muted;
  }
}

class _SmartSwapScreenState extends State<SmartSwapScreen> {
  static const List<(String, String)> _examples = <(String, String)>[
    ('Grilled fish', 'I want to make grilled fish'),
    ('Fish curry', 'I want to make fish curry'),
    ('Steamed fish', 'I want to make steamed fish'),
    ('Fish for kids', 'I want to make fish for kids'),
  ];
  static final RegExp _peoplePattern = RegExp(
    r'(\d{1,2})\s*(people|persons?|pax|orang|servings?)',
    caseSensitive: false,
  );

  final ApiClient _api = ApiClient();
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  final PageController _carousel = PageController(viewportFraction: 0.88);

  String? _fishId;

  // Preferences (page 1).
  bool _prefsOpen = true;
  int? _people; // chosen explicitly; otherwise read from the sentence
  String _budget = 'any';
  String? _difficulty;
  String _dietary = 'none';

  // Progress.
  bool _running = false;
  int _stepsDone = 0; // 0-3
  String? _runError;
  int _runId = 0;

  // Results (page 2).
  SmartSwapResult? _result;
  SwapFish? _chosen;
  List<Recipe> _recipes = <Recipe>[];
  bool _recipesLoading = false;
  String? _recipesError;
  bool _recipesUnavailable = false;
  int _carouselPage = 0;

  @override
  void initState() {
    super.initState();
    _fishId = widget.seafoodId == null
        ? null
        : FishIds.canonical(widget.seafoodId!);
    final String initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _query.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _findMatch());
    }
  }

  @override
  void dispose() {
    _api.close();
    _query.dispose();
    _focus.dispose();
    _carousel.dispose();
    super.dispose();
  }

  // --- derived values ---------------------------------------------------------

  int? get _peopleFromText {
    final RegExpMatch? m = _peoplePattern.firstMatch(_query.text);
    if (m == null) return null;
    final int? n = int.tryParse(m.group(1)!);
    return (n != null && n >= 1 && n <= 30) ? n : null;
  }

  String get _peopleLabel {
    final int? n = _people ?? _peopleFromText;
    return n == null ? 'Not set' : _peopleText(n);
  }

  double? get _budgetValue {
    for (final (String key, String _, double? value) in _kBudgets) {
      if (key == _budget) return value;
    }
    return null;
  }

  String get _budgetLabel {
    for (final (String key, String label, double? _) in _kBudgets) {
      if (key == _budget) return label;
    }
    return 'Any budget';
  }

  String get _difficultyLabel {
    for (final (String? key, String label) in _kDifficulties) {
      if (key == _difficulty) return label;
    }
    return 'Any level';
  }

  String get _dietaryLabel {
    for (final (String key, String label, String? _) in _kDietary) {
      if (key == _dietary) return label;
    }
    return 'No preference';
  }

  String? get _dietaryText {
    for (final (String key, String _, String? text) in _kDietary) {
      if (key == _dietary) return text;
    }
    return null;
  }

  bool get _kids => _dietary == 'kids';

  // --- actions ----------------------------------------------------------------

  void _findMatch() {
    final String text = _query.text.trim();
    if (text.isEmpty && _fishId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tell us what you\'re cooking, e.g. "fish curry for 4 people".',
          ),
        ),
      );
      return;
    }
    _focus.unfocus();
    final double? budget = _budgetValue;
    _run(<String, Object?>{
      'query': text.isEmpty ? null : text,
      'fish_id': _fishId,
      'servings': _people,
      'max_price_rm_per_kg': budget,
      'prefer_affordable': budget != null ? true : null,
      'kid_friendly': _kids ? true : null,
    });
  }

  /// Re-rank from page 2 after the user changes a "we understand" dropdown.
  void _rerun({String? method, int? servings}) {
    final CookingIntent? intent = _result?.intent;
    if (intent == null) return;
    final bool methodChanged =
        method != null && method != intent.cookingMethod;
    _run(<String, Object?>{
      'cooking_method': method ?? intent.cookingMethod ?? '',
      // A new method gets the default dish name for that method.
      'dish': methodChanged ? null : (intent.dish ?? ''),
      'servings': servings ?? intent.servings,
      'fish_id': intent.fishId ?? '',
      'max_price_rm_per_kg': intent.maxPriceRmPerKg,
      'prefer_affordable': intent.preferAffordable,
      'kid_friendly': intent.kidFriendly,
    });
  }

  Future<void> _run(Map<String, Object?> body) async {
    final int runId = ++_runId;
    final DateTime started = DateTime.now();
    setState(() {
      _running = true;
      _stepsDone = 0;
      _runError = null;
    });

    // Steps 1 + 2: read the sentence and rank the swap (one API call).
    final SmartSwapResult result;
    try {
      result = await _api.smartSwap(body);
    } on ApiException catch (e) {
      if (!mounted || runId != _runId) return;
      setState(() {
        _running = false;
        _runError = e.message;
      });
      return;
    }
    if (!mounted || runId != _runId) return;

    await _atLeast(started, const Duration(milliseconds: 700));
    if (!mounted || runId != _runId) return;
    setState(() => _stepsDone = 1);

    if (result.needsIntent) {
      setState(() {
        _running = false;
        _runError = result.message;
      });
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || runId != _runId) return;
    setState(() => _stepsDone = 2);

    // Step 3: three recipes, with their photos pre-loaded before we reveal.
    final SwapFish? fish = result.fishToCook;
    List<Recipe> recipes = <Recipe>[];
    String? recipesError;
    bool unavailable = false;
    if (fish != null && !result.recipesAvailable) {
      unavailable = true;
    } else if (fish != null) {
      try {
        final RecipeBatch batch = await _api.generateRecipes(
          fishId: fish.fishId,
          cookingMethod: result.intent.cookingMethod,
          dish: result.intent.dish,
          servings: result.intent.servings ?? 2,
          count: 3,
          kidFriendly: result.intent.kidFriendly || _kids,
          difficulty: _difficulty,
          dietary: _dietaryText,
        );
        recipes = batch.recipes;
        if (!mounted || runId != _runId) return;
        await _precachePhotos(recipes);
      } on ApiException catch (e) {
        recipesError = e.message;
        unavailable = e.isRecipeUnavailable;
      }
    }
    if (!mounted || runId != _runId) return;

    setState(() => _stepsDone = 3);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || runId != _runId) return;

    setState(() {
      _result = result;
      _chosen = fish;
      _recipes = recipes;
      _recipesError = recipesError;
      _recipesUnavailable = unavailable;
      _recipesLoading = false;
      _running = false;
      _carouselPage = 0;
    });
    if (_carousel.hasClients) _carousel.jumpToPage(0);
  }

  Future<void> _atLeast(DateTime started, Duration minimum) async {
    final Duration elapsed = DateTime.now().difference(started);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
  }

  /// Warm the image cache so the cards appear with their photos. Photos still
  /// generating after the timeout keep loading inside their cards.
  Future<void> _precachePhotos(List<Recipe> recipes) async {
    if (!mounted) return;
    final List<Future<void>> jobs = <Future<void>>[
      for (final Recipe r in recipes)
        if (r.imageUrl != null)
          precacheImage(
            NetworkImage(r.imageUrl!),
            context,
            onError: (Object error, StackTrace? stack) {},
          ),
    ];
    if (jobs.isEmpty) return;
    try {
      await Future.wait(jobs).timeout(const Duration(seconds: 75));
    } on TimeoutException {
      // Reveal anyway; the cards show a "plating" placeholder until ready.
    }
  }

  Future<void> _chooseAlternative(SwapFish fish) async {
    final SmartSwapResult? result = _result;
    if (result == null || _chosen?.fishId == fish.fishId) return;
    final int runId = ++_runId;
    setState(() {
      _chosen = fish;
      _recipes = <Recipe>[];
      _recipesLoading = true;
      _recipesError = null;
      _carouselPage = 0;
    });
    try {
      final RecipeBatch batch = await _api.generateRecipes(
        fishId: fish.fishId,
        cookingMethod: result.intent.cookingMethod,
        dish: result.intent.dish,
        servings: result.intent.servings ?? 2,
        count: 3,
        kidFriendly: result.intent.kidFriendly || _kids,
        difficulty: _difficulty,
        dietary: _dietaryText,
      );
      if (!mounted || runId != _runId) return;
      setState(() {
        _recipes = batch.recipes;
        _recipesLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || runId != _runId) return;
      setState(() {
        _recipesLoading = false;
        _recipesError = e.message;
        _recipesUnavailable = e.isRecipeUnavailable;
      });
    }
  }

  Future<void> _moreRecipes() async {
    final SmartSwapResult? result = _result;
    final SwapFish? fish = _chosen;
    if (result == null || fish == null) return;
    final RecipeBatch batch = await _api.generateRecipes(
      fishId: fish.fishId,
      cookingMethod: result.intent.cookingMethod,
      dish: result.intent.dish,
      servings: result.intent.servings ?? 2,
      count: 3,
      kidFriendly: result.intent.kidFriendly || _kids,
      difficulty: _difficulty,
      dietary: _dietaryText,
      excludeTitles: _recipes.map((Recipe r) => r.title).toList(),
    );
    if (!mounted) return;
    setState(() => _recipes = <Recipe>[..._recipes, ...batch.recipes]);
  }

  void _back() {
    if (_result != null && !_running) {
      setState(() {
        _result = null;
        _runError = null;
        _stepsDone = 0;
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  // --- build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final String? favId = _chosen?.fishId ?? _fishId;
    final bool fav = favId != null && catalog.isFavourite(favId);

    return Scaffold(
      backgroundColor: _kPage,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(
              onBack: _back,
              favourite: fav,
              onFavourite: favId == null
                  ? null
                  : () => catalog.toggleFavourite(favId),
            ),
            Expanded(
              child: ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: <Widget>[
                    const _TitleBlock(),
                    const SizedBox(height: 14),
                    if (_result == null) ..._intentView() else ..._resultsView(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- page 1: Cooking Intent ---------------------------------------------------

  List<Widget> _intentView() {
    return <Widget>[
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _QueryField(
              controller: _query,
              focusNode: _focus,
              onSubmitted: _findMatch,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Text(
              'Try an example:',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final (String label, String text) in _examples)
                  _SoftChip(
                    label: label,
                    onTap: () {
                      final int? n = _people ?? _peopleFromText;
                      setState(() {
                        _query.text = n == null ? text : '$text for ${_peopleText(n)}';
                        if (label == 'Fish for kids') _dietary = 'kids';
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _prefsOpen = !_prefsOpen),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: <Widget>[
              const _IconBubble(icon: Icons.tune, size: 38),
              const SizedBox(width: 10),
              const Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'More preferences ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                    TextSpan(
                      text: '(optional)',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                _prefsOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: _kInk,
              ),
            ],
          ),
        ),
      ),
      if (_prefsOpen) ...<Widget>[
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _PickerTile<int?>(
                icon: Icons.groups_outlined,
                iconColor: _kTeal,
                label: 'Number of people',
                value: _peopleLabel,
                options: <(int?, String)>[
                  (null, 'From my request'),
                  for (int i = 1; i <= 10; i++) (i, _peopleText(i)),
                ],
                onSelected: (int? v) => setState(() => _people = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickerTile<String>(
                icon: Icons.savings_outlined,
                iconColor: const Color(0xFFD9822B),
                label: 'Budget',
                value: _budgetLabel,
                options: <(String, String)>[
                  for (final (String key, String label, double? _)
                      in _kBudgets)
                    (key, label),
                ],
                onSelected: (String v) => setState(() => _budget = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _PickerTile<String?>(
                icon: Icons.soup_kitchen_outlined,
                iconColor: _kTeal,
                label: 'Cooking difficulty',
                value: _difficultyLabel,
                options: _kDifficulties,
                onSelected: (String? v) => setState(() => _difficulty = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickerTile<String>(
                icon: Icons.eco_outlined,
                iconColor: AppColors.good,
                label: 'Dietary preference',
                value: _dietaryLabel,
                options: <(String, String)>[
                  for (final (String key, String label, String? _)
                      in _kDietary)
                    (key, label),
                ],
                onSelected: (String v) => setState(() => _dietary = v),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      const _ConsiderCard(),
      const SizedBox(height: 16),
      _PrimaryButton(
        label: _running ? 'Finding your match…' : 'Find my better match',
        trailingIcon: Icons.arrow_forward,
        onPressed: _running ? null : _findMatch,
      ),
      if (_running || _runError != null) ...<Widget>[
        const SizedBox(height: 14),
        _ProgressCard(
          stepsDone: _stepsDone,
          error: _running ? null : _runError,
          onRetry: _findMatch,
        ),
      ],
    ];
  }

  // --- page 2: Smart Swap results -----------------------------------------------

  List<Widget> _resultsView() {
    final SmartSwapResult result = _result!;
    final CookingIntent intent = result.intent;
    final SwapFish? chosen = _chosen;
    final int? servings = intent.servings;

    return <Widget>[
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _QueryField(
              controller: _query,
              focusNode: _focus,
              onSubmitted: _findMatch,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'We understand your request as:',
                    style: TextStyle(fontSize: 12.5, color: _kInk),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _PickerTile<String>(
                          icon: Icons.ramen_dining_outlined,
                          iconColor: const Color(0xFFD9822B),
                          label: 'Cooking method',
                          value: _methodLabel(intent.cookingMethod),
                          options: _kMethods,
                          enabled: !_running,
                          onSelected: (String v) => _rerun(method: v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PickerTile<int>(
                          icon: Icons.groups_outlined,
                          iconColor: _kTeal,
                          label: 'Serves',
                          value: servings == null
                              ? 'Not set'
                              : _peopleText(servings),
                          options: <(int, String)>[
                            for (int i = 1; i <= 10; i++) (i, _peopleText(i)),
                          ],
                          enabled: !_running,
                          onSelected: (int v) => _rerun(servings: v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: <Widget>[
                      Icon(Icons.info, size: 14, color: Color(0xFF2F80ED)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'We\'ll consider sustainability, cooking suitability and price.',
                          style: TextStyle(fontSize: 12, color: _kInk),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      if (_running || _runError != null)
        _ProgressCard(
          stepsDone: _stepsDone,
          error: _running ? null : _runError,
          onRetry: _findMatch,
        )
      else ...<Widget>[
        _SectionHeader(
          icon: Icons.swap_horiz,
          title: result.status == 'ALREADY_GOOD'
              ? 'Great choice already'
              : 'Your Smart Swap',
          subtitle: result.message,
        ),
        const SizedBox(height: 12),
        _comparison(result),
        if (chosen != null) ...<Widget>[
          const SizedBox(height: 12),
          _WhyCard(
            fish: chosen,
            isOwnChoice: chosen.fishId == result.current?.fishId,
            weights: result.rankingWeights,
            options: <SwapFish>[
              if (result.recommended != null) result.recommended!,
              ...result.alternatives,
            ],
            onChoose: _chooseAlternative,
          ),
          const SizedBox(height: 22),
          _SectionHeader(
            icon: Icons.soup_kitchen_outlined,
            title: chosen.fishId != result.current?.fishId
                ? 'Recipes for your new choice'
                : 'Recipes for ${chosen.name}',
            subtitle:
                'Malay, Chinese and Indian recipes to help you get cooking.',
            trailing: _recipes.isEmpty
                ? null
                : TextButton(
                    onPressed: _openAllRecipes,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'View all',
                          style: TextStyle(
                            color: _kTeal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: _kTeal, size: 18),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          _recipesCarousel(chosen),
        ],
      ],
    ];
  }

  Widget _comparison(SmartSwapResult result) {
    final SwapFish? current = result.current;
    final SwapFish? chosen = _chosen;
    final String? method = result.intent.cookingMethod;

    if (current != null && chosen != null && chosen.fishId != current.fishId) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _FishCard(
                fish: current,
                tag: 'Your choice',
                method: method,
              ),
            ),
            const SizedBox(
              width: 30,
              child: Center(
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.tealSoft,
                  child: Icon(Icons.arrow_forward, size: 16, color: _kTeal),
                ),
              ),
            ),
            Expanded(
              child: _FishCard(
                fish: chosen,
                tag: 'Recommended',
                method: method,
                highlight: true,
              ),
            ),
          ],
        ),
      );
    }
    final SwapFish? only = chosen ?? current;
    if (only == null) {
      return const _Notice(
        icon: Icons.info_outline,
        text: 'No species on file suits this request yet.',
      );
    }
    return _FishCard(
      fish: only,
      tag: current == null ? 'Recommended' : 'Your choice',
      method: method,
      highlight: current == null || only.isBetterChoice,
      wide: true,
      noBetterOption: result.status == 'NO_BETTER_OPTION',
    );
  }

  Widget _recipesCarousel(SwapFish fish) {
    if (_recipesUnavailable) {
      return const _Notice(
        icon: Icons.menu_book_outlined,
        text: 'Recipe suggestions are not switched on for this server yet.',
      );
    }
    if (_recipesLoading) {
      return const _Notice(
        icon: Icons.soup_kitchen_outlined,
        text: 'Cooking up recipes…',
        loading: true,
      );
    }
    if (_recipes.isEmpty) {
      return _Notice(
        icon: Icons.error_outline,
        text: _recipesError ?? 'No recipes yet.',
        actionLabel: 'Retry',
        onAction: () {
          _chosen = null;
          _chooseAlternative(fish);
        },
      );
    }
    // watch, not read: this runs during build.
    final String? fallbackUrl = context
        .watch<CatalogController>()
        .itemById(fish.fishId)
        ?.imageUrl;
    final List<Recipe> shown = _recipes.take(3).toList();
    return Column(
      children: <Widget>[
        SizedBox(
          height: 286,
          child: PageView.builder(
            controller: _carousel,
            padEnds: false,
            itemCount: shown.length,
            onPageChanged: (int i) => setState(() => _carouselPage = i),
            itemBuilder: (BuildContext context, int i) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _RecipeCard(
                recipe: shown[i],
                fallbackImageUrl: fallbackUrl,
                onTap: () => context.push('/recipe', extra: shown[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < shown.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _carouselPage ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _carouselPage
                      ? _kTeal
                      : const Color(0xFFC9D6DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _openAllRecipes() {
    final SwapFish? fish = _chosen;
    final String? fallbackUrl = fish == null
        ? null
        : context.read<CatalogController>().itemById(fish.fishId)?.imageUrl;
    final GoRouter router = GoRouter.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _kPage,
      builder: (BuildContext sheetContext) {
        bool loading = false;
        String? error;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheet) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (BuildContext context, ScrollController scroll) {
                return ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: <Widget>[
                    Text(
                      'Recipes for ${fish?.name ?? 'your fish'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final Recipe r in _recipes) ...<Widget>[
                      SizedBox(
                        height: 286,
                        child: _RecipeCard(
                          recipe: r,
                          fallbackImageUrl: fallbackUrl,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            router.push('/recipe', extra: r);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          error!,
                          style: const TextStyle(color: AppColors.avoid),
                        ),
                      ),
                    _PrimaryButton(
                      label: loading
                          ? 'Cooking up more…'
                          : 'Show 3 more recipes',
                      trailingIcon: Icons.add,
                      onPressed: loading
                          ? null
                          : () async {
                              setSheet(() {
                                loading = true;
                                error = null;
                              });
                              try {
                                await _moreRecipes();
                              } on ApiException catch (e) {
                                error = e.message;
                              }
                              if (sheetContext.mounted) {
                                setSheet(() => loading = false);
                              }
                            },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- building blocks ------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.favourite,
    this.onFavourite,
  });

  final VoidCallback onBack;
  final bool favourite;
  final VoidCallback? onFavourite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: _kInk),
            onPressed: onBack,
          ),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                BrandLogo(size: 30),
                SizedBox(width: 6),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: 'Suka',
                        style: TextStyle(
                          color: _kInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'Seafood',
                        style: TextStyle(
                          color: Color(0xFF1C9BD6),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Save fish to favourites',
            icon: Icon(
              favourite ? Icons.favorite : Icons.favorite_border,
              color: _kInk,
            ),
            onPressed: onFavourite,
          ),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        _IconBubble(icon: Icons.restaurant, size: 56),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Cooking Intent',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Tell us what you\'re making. We\'ll help you choose the right seafood.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    this.size = 40,
    this.background = AppColors.tealSoft,
    this.color = _kTeal,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QueryField extends StatelessWidget {
  const _QueryField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(color: AppColors.line),
    );
    return Row(
      children: <Widget>[
        const _IconBubble(
          icon: Icons.sentiment_satisfied_alt,
          size: 44,
          background: _kTeal,
          color: Colors.white,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSubmitted(),
            onChanged: (_) => onChanged(),
            style: const TextStyle(fontSize: 14.5, color: _kInk),
            decoration: InputDecoration(
              hintText: 'I want to make fried fish for 4 people',
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: _kTeal, width: 1.5),
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Color(0xFFEFF3F5),
                        child: Icon(Icons.close, size: 14, color: _kInk),
                      ),
                      onPressed: () {
                        controller.clear();
                        onChanged();
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE6F4F2),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _kInk),
          ),
        ),
      ),
    );
  }
}

/// A white preference tile that opens a menu of options.
class _PickerTile<T> extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: PopupMenuButton<int>(
        enabled: enabled,
        tooltip: label,
        position: PopupMenuPosition.under,
        onSelected: (int index) => onSelected(options[index].$1),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
          for (int i = 0; i < options.length; i++)
            PopupMenuItem<int>(value: i, child: Text(options[i].$2)),
        ],
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EFF2)),
          ),
          child: Row(
            children: <Widget>[
              _IconBubble(
                icon: icon,
                size: 38,
                background: iconColor.withValues(alpha: 0.12),
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: _kInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsiderCard extends StatelessWidget {
  const _ConsiderCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(6, 2, 6, 12),
            child: Text(
              'What we\'ll consider',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _ConsiderItem(
                    icon: Icons.eco,
                    color: AppColors.good,
                    title: 'Sustainability',
                    body: 'WWF ratings & ocean impact',
                  ),
                ),
                VerticalDivider(width: 1, color: AppColors.line),
                Expanded(
                  child: _ConsiderItem(
                    icon: Icons.restaurant,
                    color: Color(0xFFB5541C),
                    title: 'Cooking suitability',
                    body: 'Match for your dish',
                  ),
                ),
                VerticalDivider(width: 1, color: AppColors.line),
                Expanded(
                  child: _ConsiderItem(
                    icon: Icons.bar_chart,
                    color: Color(0xFF2F80ED),
                    title: 'Price',
                    body: 'Market price & availability',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsiderItem extends StatelessWidget {
  const _ConsiderItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: <Widget>[
          _IconBubble(
            icon: icon,
            size: 52,
            background: color.withValues(alpha: 0.14),
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.muted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _kTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kTeal.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label),
            if (trailingIcon != null) ...<Widget>[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Finding your better match…" with three steps.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.stepsDone,
    required this.onRetry,
    this.error,
  });

  final int stepsDone;
  final String? error;
  final VoidCallback onRetry;

  static const List<String> _labels = <String>[
    'Understanding\nyour dish',
    'Comparing\nseafood choices',
    'Cooking up\nrecipes',
  ];

  @override
  Widget build(BuildContext context) {
    final String? failure = error;
    final bool failed = failure != null;
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _IconBubble(
                  icon: failed ? Icons.error_outline : Icons.auto_awesome,
                  size: 50,
                  background: failed
                      ? AppColors.avoid.withValues(alpha: 0.1)
                      : const Color(0xFFE3F1FB),
                  color: failed ? AppColors.avoid : const Color(0xFF2F80ED),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    failed
                        ? 'We couldn\'t finish your match'
                        : 'Finding your better match...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < _labels.length; i++)
                  Expanded(
                    child: _StepDot(
                      label: _labels[i],
                      done: i < stepsDone,
                      active: !failed && i == stepsDone,
                      failed: failed && i == stepsDone,
                      lineBefore: i > 0,
                      lineAfter: i < _labels.length - 1,
                      lineBeforeDone: i > 0 && i <= stepsDone,
                      lineAfterDone: i < stepsDone,
                    ),
                  ),
              ],
            ),
            if (failure != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                failure,
                style: const TextStyle(fontSize: 13, color: _kInk),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.done,
    required this.active,
    required this.failed,
    required this.lineBefore,
    required this.lineAfter,
    required this.lineBeforeDone,
    required this.lineAfterDone,
  });

  final String label;
  final bool done;
  final bool active;
  final bool failed;
  final bool lineBefore;
  final bool lineAfter;
  final bool lineBeforeDone;
  final bool lineAfterDone;

  Widget _line(bool visible, bool solid) {
    if (!visible) return const Expanded(child: SizedBox());
    return Expanded(
      child: Container(
        height: 2,
        color: solid ? _kTeal : const Color(0xFFBFD9E6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget dot;
    if (done) {
      dot = const CircleAvatar(
        radius: 16,
        backgroundColor: _kTeal,
        child: Icon(Icons.check, color: Colors.white, size: 18),
      );
    } else if (active) {
      dot = const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Color(0xFF2F9BD6),
        ),
      );
    } else if (failed) {
      dot = CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.avoid.withValues(alpha: 0.12),
        child: const Icon(Icons.close, color: AppColors.avoid, size: 18),
      );
    } else {
      dot = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFBFD9E6), width: 2),
        ),
      );
    }
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            _line(lineBefore, lineBeforeDone),
            dot,
            _line(lineAfter, lineAfterDone),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget? trailingWidget = trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _IconBubble(icon: icon, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.muted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (trailingWidget != null) trailingWidget,
      ],
    );
  }
}

class _FishCard extends StatelessWidget {
  const _FishCard({
    required this.fish,
    required this.tag,
    required this.method,
    this.highlight = false,
    this.wide = false,
    this.noBetterOption = false,
  });

  final SwapFish fish;
  final String tag;
  final String? method;
  final bool highlight;
  final bool wide;
  final bool noBetterOption;

  @override
  Widget build(BuildContext context) {
    final bool better = fish.isBetterChoice;
    final String status;
    if (better) {
      status = 'Better choice';
    } else if (highlight) {
      status = 'Better than your choice';
    } else if (noBetterOption) {
      status = 'No better-rated swap on file';
    } else {
      status = 'Consider: Better options available';
    }
    final Color statusColor = better
        ? AppColors.good
        : const Color(0xFFE08A00);
    final double? price = fish.priceRmPerKg;
    final int? cookingScore = fish.cookingScore;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/seafood/${fish.fishId}'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFF1FBF9) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlight
                ? const Color(0xFF8FD8CF)
                : const Color(0xFFE9EFF2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: highlight ? _kTeal : AppColors.headerTeal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (highlight && better)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goodSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.check_circle,
                          size: 12,
                          color: AppColors.good,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Better choice',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.good,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: CatalogueFishArt(
                fishId: fish.fishId,
                networkUrl: fish.imageUrl,
                width: wide ? 240 : 140,
                height: wide ? 120 : 76,
                borderRadius: 12,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fish.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _kInk,
              ),
            ),
            Text(
              fish.scientificName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(
                  better ? Icons.check_circle : Icons.error,
                  size: 15,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (wide) const SizedBox(height: 6) else const Spacer(),
            const SizedBox(height: 8),
            _FactRow(
              label: 'Cooking suitability',
              value: cookingScore == null
                  ? 'Not rated'
                  : '$cookingScore/5 for ${_methodWord(method)}',
            ),
            const Divider(height: 12, color: Color(0xFFEDF1F3)),
            _FactRow(
              label: 'WWF rating',
              valueWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _wwfColour(fish.wwfColour),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    fish.wwfColour,
                    style: const TextStyle(fontSize: 11.5, color: _kInk),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _FactRow(
              label: 'Price (per kg)',
              valueWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    price == null
                        ? 'No price'
                        : 'RM ${price.toStringAsFixed(2)} / kg',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  Text(
                    price == null ? 'on file' : '(latest)',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
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

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, this.value, this.valueWidget});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ),
        const SizedBox(width: 4),
        valueWidget ??
            Flexible(
              child: Text(
                value ?? '',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11.5, color: _kInk),
              ),
            ),
      ],
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({
    required this.fish,
    required this.isOwnChoice,
    required this.weights,
    required this.options,
    required this.onChoose,
  });

  final SwapFish fish;
  final bool isOwnChoice;
  final Map<String, double> weights;
  final List<SwapFish> options;
  final ValueChanged<SwapFish> onChoose;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, double)> rows = <(String, String, double)>[
      ('Sustainability', 'sustainability', fish.breakdown.sustainability),
      ('Cooking suitability', 'cooking', fish.breakdown.cooking),
      ('Price', 'price', fish.breakdown.price),
      ('Food-use attributes', 'attributes', fish.breakdown.attributes),
    ];
    return _Panel(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          leading: const _IconBubble(icon: Icons.spa_outlined, size: 44),
          title: Text(
            'Why ${fish.name}?',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _kInk,
            ),
          ),
          subtitle: const Text(
            'See how we compared sustainability, cooking suitability and price.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          children: <Widget>[
            for (final String reason in fish.reasons)
              _Bullet(icon: Icons.check, color: AppColors.good, text: reason),
            for (final String caveat in fish.caveats)
              _Bullet(
                icon: Icons.info_outline,
                color: const Color(0xFFE08A00),
                text: caveat,
              ),
            if (isOwnChoice && fish.reasons.isEmpty)
              const _Bullet(
                icon: Icons.info_outline,
                color: AppColors.muted,
                text:
                    'This is your own choice; no better-rated swap was found for this dish.',
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Match score ${fish.score}/100',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
            for (final (String label, String key, double value) in rows)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 150,
                      child: Text(
                        '$label · ${((weights[key] ?? 0) * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: value.clamp(0.0, 1.0),
                          minHeight: 6,
                          color: _kTeal,
                          backgroundColor: AppColors.line,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (options.length > 1) ...<Widget>[
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Other good options',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: _kInk,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final SwapFish option in options)
                    ChoiceChip(
                      selected: option.fishId == fish.fishId,
                      onSelected: (_) => onChoose(option),
                      avatar: Icon(
                        Icons.circle,
                        size: 10,
                        color: _wwfColour(option.wwfColour),
                      ),
                      label: Text('${option.name} · ${option.score}'),
                      selectedColor: AppColors.tealSoft,
                      showCheckmark: false,
                    ),
                ],
              ),
            ],
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
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: _kInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    this.fallbackImageUrl,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final bool saved = catalog.isFavourite(recipe.fishId);
    final String? badge =
        recipe.cuisine ?? (recipe.tags.isEmpty ? null : recipe.tags.first);
    final Color badgeColor = cuisineColor(recipe.cuisine);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                RecipeImage(
                  recipe: recipe,
                  height: 168,
                  fallbackImageUrl: fallbackImageUrl,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Save ${recipe.fishName} to favourites',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        saved ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: _kInk,
                      ),
                      onPressed: () => catalog.toggleFavourite(recipe.fishId),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recipe.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.schedule,
                        size: 15,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.timeMinutes} mins',
                        style: const TextStyle(fontSize: 12, color: _kInk),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.soup_kitchen_outlined,
                        size: 15,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.difficultyLabel,
                        style: const TextStyle(fontSize: 12, color: _kInk),
                      ),
                      const SizedBox(width: 12),
                      if (badge != null)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ),
                    ],
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

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final String? action = actionLabel;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EFF2)),
      ),
      child: Row(
        children: <Widget>[
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kTeal),
            )
          else
            Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: _kInk),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}
