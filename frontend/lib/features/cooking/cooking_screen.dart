import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/fish_ids.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';

class CookingScreen extends StatefulWidget {
  const CookingScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  late final String _fishId = FishIds.canonical(widget.seafoodId);
  SeafoodProfile? _profile;
  PriceContext? _price;
  Object? _error;
  bool _loading = true;
  String? _method;
  int _people = 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final CatalogController catalog = context.read<CatalogController>();
    try {
      final Future<SeafoodProfile> profileFut = catalog.profile(_fishId);
      final Future<PriceContext> priceFut = catalog.price(_fishId);
      final SeafoodProfile profile = await profileFut;
      PriceContext? price;
      try {
        price = await priceFut;
      } catch (_) {
        price = null;
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _price = price;
        _method = profile.cooking.isEmpty ? null : profile.cooking.first.method;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  CookingSuitability? get _selected {
    final String? method = _method;
    if (method == null || _profile == null) return null;
    for (final CookingSuitability row in _profile!.cooking) {
      if (row.method == method) return row;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cooking'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text(_error?.toString() ?? 'Species not found.')),
      );
    }

    final SeafoodProfile item = _profile!;
    final CookingSuitability? selected = _selected;
    final bool priced = _price?.isDisplayable == true;

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.navy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CatalogueFishArt.photoAssetFor(item.fishId) != null
                      ? Image.asset(
                          CatalogueFishArt.photoAssetFor(item.fishId)!,
                          fit: BoxFit.cover,
                        )
                      : CatalogueFishArt(
                          fishId: item.fishId,
                          networkUrl: item.imageUrl,
                          width: 800,
                          height: 240,
                          borderRadius: 0,
                          fit: BoxFit.cover,
                        ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          AppColors.navy.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.shortName,
                          style: Theme.of(
                            context,
                          ).textTheme.displayLarge?.copyWith(fontSize: 34),
                        ),
                        Text(
                          item.scientificName,
                          style: const TextStyle(
                            color: AppColors.teal,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (item.alsoKnownAs.isNotEmpty)
                          Text(
                            'Also known as: ${item.alsoKnownAs}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SoftCard(
                    child: Row(
                      children: [
                        _MiniFact(label: 'Type', value: item.fishType),
                        _MiniFact(label: 'Common in', value: item.commonIn),
                        _MiniFact(
                          label: 'Market',
                          value: item.marketAvailability,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel(
                    title: 'Cooking Intent',
                    icon: Icons.soup_kitchen_outlined,
                  ),
                  const SizedBox(height: 4),
                  const Text('Choose how you plan to cook.'),
                  const SizedBox(height: 12),
                  if (item.cooking.isEmpty)
                    const SoftCard(
                      child: Text(
                        'No cooking-suitability scores are on file for this species yet.',
                      ),
                    )
                  else
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.cooking.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final CookingSuitability row = item.cooking[index];
                          final bool selectedChip = row.method == _method;
                          return InkWell(
                            onTap: () => setState(() => _method = row.method),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 86,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedChip
                                      ? AppColors.teal
                                      : AppColors.line,
                                  width: selectedChip ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _iconFor(row.method),
                                    color: selectedChip
                                        ? AppColors.tealDark
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    row.method,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: selectedChip
                                          ? AppColors.ink
                                          : AppColors.muted,
                                    ),
                                  ),
                                  Text(
                                    '${row.starsOutOfFive}/5',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.tealDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    SoftCard(
                      color: AppColors.tealSoft,
                      child: Text(
                        '${item.shortName} scored ${selected.starsOutOfFive}/5 for ${selected.method}. ${selected.rationale}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'How much do you need?',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('2 people'),
                                    selected: _people == 2,
                                    onSelected: (_) =>
                                        setState(() => _people = 2),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: const Text('4 people'),
                                    selected: _people == 4,
                                    onSelected: (_) =>
                                        setState(() => _people = 4),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _people == 2
                                    ? 'About 300–400 g (1 medium-sized fish).'
                                    : 'About 600–800 g (2 medium-sized fish).',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Market price guide',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              if (priced)
                                Text(
                                  'RM ${_price!.observedPriceRmPerKg!.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    color: AppColors.tealDark,
                                  ),
                                )
                              else
                                Text(
                                  _price?.status ?? 'Insufficient data',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              const Text('Observed PriceCatcher / kg'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    color: const Color(0xFFF3EEFF),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recipe inspiration',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text('Powered by RecipeDB · Coming soon'),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.menu_book,
                          color: Colors.deepPurple.shade300,
                          size: 36,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String method) {
    switch (method.toLowerCase()) {
      case 'grill':
      case 'grilling':
        return Icons.outdoor_grill;
      case 'soup':
        return Icons.soup_kitchen;
      case 'curry':
        return Icons.rice_bowl;
      case 'fry':
      case 'stir-fry':
        return Icons.restaurant;
      case 'steam':
      case 'steaming':
        return Icons.kitchen;
      default:
        return Icons.more_horiz;
    }
  }
}

class _MiniFact extends StatelessWidget {
  const _MiniFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
