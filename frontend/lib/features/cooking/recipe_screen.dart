import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/models/cooking_intent.dart';
import '../../shared/widgets/ui_kit.dart';
import 'recipe_image.dart';

/// Epic 4 step 3 — a recipe the user can actually cook.
class RecipeScreen extends StatelessWidget {
  const RecipeScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final bool fav = catalog.isFavourite(recipe.fishId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 30),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Save fish',
            icon: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              color: AppColors.tealDark,
            ),
            onPressed: () => catalog.toggleFavourite(recipe.fishId),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          children: [
            RecipeImage(
              recipe: recipe,
              height: 230,
              borderRadius: BorderRadius.circular(22),
              fallbackImageUrl: catalog.itemById(recipe.fishId)?.imageUrl,
            ),
            const SizedBox(height: 16),
            Text(
              recipe.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              recipe.description,
              style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(icon: Icons.timer_outlined, label: '${recipe.timeMinutes} mins'),
                _MetaChip(icon: Icons.soup_kitchen_outlined, label: recipe.difficulty),
                _MetaChip(icon: Icons.people_outline, label: 'Serves ${recipe.servings}'),
                if (recipe.cuisine != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: cuisineColor(recipe.cuisine).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${recipe.cuisine} recipe',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: cuisineColor(recipe.cuisine),
                      ),
                    ),
                  ),
              ],
            ),
            if (recipe.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final String tag in recipe.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.tealSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                const Text(
                  'Ingredients',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showShoppingList(context),
                  child: const Text(
                    'View shopping list',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            for (final RecipeIngredient ing in recipe.ingredients) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.foam,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        ing.emoji.isEmpty ? '•' : ing.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ing.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if (ing.note.isNotEmpty)
                            Text(
                              ing.note,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      ing.quantity,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
            ],
            const SizedBox(height: 22),
            const Text(
              'Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final RecipeStep step in recipe.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.tealDark,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${step.step}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step.minutes == null
                            ? step.instruction
                            : '${step.instruction}  (${step.minutes} min)',
                        style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            if (recipe.tips.isNotEmpty) ...[
              const SizedBox(height: 8),
              SoftCard(
                color: AppColors.tealSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tips', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    for (final String tip in recipe.tips)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $tip', style: const TextStyle(color: AppColors.ink)),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'AI-generated recipe suggestion. Make sure fish is cooked through and adjust spice to taste.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tealDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            onPressed: recipe.steps.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CookingModeScreen(recipe: recipe),
                      fullscreenDialog: true,
                    ),
                  ),
            icon: const Icon(Icons.soup_kitchen_outlined),
            label: const Text('Start cooking'),
          ),
        ),
      ),
    );
  }

  void _showShoppingList(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ShoppingListSheet(recipe: recipe),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.tealDark),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ShoppingListSheet extends StatefulWidget {
  const _ShoppingListSheet({required this.recipe});

  final Recipe recipe;

  @override
  State<_ShoppingListSheet> createState() => _ShoppingListSheetState();
}

class _ShoppingListSheetState extends State<_ShoppingListSheet> {
  final Set<int> _have = <int>{};

  @override
  Widget build(BuildContext context) {
    final List<RecipeIngredient> items = widget.recipe.ingredients;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Shopping list',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                  onPressed: () async {
                    final String text = <String>[
                      widget.recipe.title,
                      for (int i = 0; i < items.length; i++)
                        if (!_have.contains(i)) '- ${items[i].name}: ${items[i].quantity}',
                    ].join('\n');
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shopping list copied')),
                    );
                  },
                ),
              ],
            ),
            const Text(
              'Tick what you already have at home.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (int i = 0; i < items.length; i++)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.tealDark,
                      value: _have.contains(i),
                      onChanged: (bool? v) => setState(() {
                        if (v == true) {
                          _have.add(i);
                        } else {
                          _have.remove(i);
                        }
                      }),
                      title: Text(
                        '${items[i].emoji} ${items[i].name}'.trim(),
                        style: TextStyle(
                          decoration: _have.contains(i) ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      secondary: Text(items[i].quantity),
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

/// Step-by-step, large-type cooking mode.
class CookingModeScreen extends StatefulWidget {
  const CookingModeScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<RecipeStep> steps = widget.recipe.steps;
    final bool last = _index == steps.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.recipe.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (_index + 1) / steps.length,
                minHeight: 6,
                color: AppColors.tealDark,
                backgroundColor: AppColors.line,
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: steps.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (BuildContext context, int i) {
                final RecipeStep step = steps[i];
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Step ${i + 1} of ${steps.length}',
                        style: const TextStyle(
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.instruction,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      if (step.minutes != null) ...[
                        const SizedBox(height: 18),
                        Chip(
                          avatar: const Icon(Icons.timer_outlined, size: 18),
                          label: Text('About ${step.minutes} min'),
                          backgroundColor: AppColors.tealSoft,
                          side: BorderSide.none,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                if (_index > 0)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: () => _pages.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_index > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.tealDark,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: last
                        ? () => Navigator.of(context).pop()
                        : () => _pages.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    child: Text(last ? 'Done — selamat makan!' : 'Next step'),
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
