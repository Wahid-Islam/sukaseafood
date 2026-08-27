import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock/mock_catalog.dart';
import '../../shared/widgets/ui_kit.dart';

class CookingScreen extends StatefulWidget {
  const CookingScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  String _method = 'grilling';
  int _people = 2;

  @override
  Widget build(BuildContext context) {
    final SeafoodItem item = MockCatalog.byId(widget.seafoodId);
    final bool best = item.cookingMethods.contains(_method);

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
            actions: const [
              Icon(Icons.favorite_border, color: Colors.white),
              SizedBox(width: 8),
              Icon(Icons.ios_share, color: Colors.white),
              SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: AppColors.navy),
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
                          item.commonName,
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(fontSize: 34),
                        ),
                        Text(
                          item.scientificName,
                          style: const TextStyle(
                            color: AppColors.teal,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Also known as: ${item.alsoKnownAs}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.about,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
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
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: MockCatalog.cookingMethods.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final String method = MockCatalog.cookingMethods[index];
                        final bool selected = method == _method;
                        return InkWell(
                          onTap: () => setState(() => _method = method),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 86,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected ? AppColors.teal : AppColors.line,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _iconFor(method),
                                  color: selected
                                      ? AppColors.tealDark
                                      : AppColors.muted,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  method,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? AppColors.ink
                                        : AppColors.muted,
                                  ),
                                ),
                                if (selected && best)
                                  const Text(
                                    'Best match',
                                    style: TextStyle(
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
                  const SizedBox(height: 12),
                  SoftCard(
                    color: AppColors.tealSoft,
                    child: Text(
                      best
                          ? '${item.commonName} is recommended for $_method based on our cooking-method suitability data.'
                          : '${item.commonName} can work for $_method, but another method may suit better.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_method[0].toUpperCase()}${_method.substring(1)} suitability',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 92,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.navy,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                best ? '5/5\nExcellent\nmatch' : '3/5\nOkay\nmatch',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• Holds shape well on grill'),
                                  Text('• Mild flavour, pairs easily'),
                                  Text('• Moist & flaky when cooked'),
                                  Text('• Great for quick, everyday meals'),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: NetworkFishImage(
                                url: MockCatalog.grilled,
                                borderRadius: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                                    onSelected: (_) => setState(() => _people = 2),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: const Text('4 people'),
                                    selected: _people == 4,
                                    onSelected: (_) => setState(() => _people = 4),
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
                              Text(
                                'RM ${item.priceLow.toStringAsFixed(0)} – ${item.priceHigh.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: AppColors.tealDark,
                                ),
                              ),
                              const Text('Average price (RM/kg)'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.goodSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Affordable',
                                  style: TextStyle(
                                    color: AppColors.good,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Best time to buy',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (int i = 0; i < 12; i++)
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: i >= 2 && i <= 7
                                    ? AppColors.navy
                                    : AppColors.tealSoft,
                                child: Text(
                                  const <String>[
                                    'J', 'F', 'M', 'A', 'M', 'J',
                                    'J', 'A', 'S', 'O', 'N', 'D',
                                  ][i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: i >= 2 && i <= 7
                                        ? Colors.white
                                        : AppColors.navy,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Available year-round, with highest supply typically from March to August.',
                        ),
                      ],
                    ),
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
                        Icon(Icons.menu_book, color: Colors.deepPurple.shade300, size: 36),
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
    switch (method) {
      case 'grilling':
        return Icons.outdoor_grill;
      case 'soup':
        return Icons.soup_kitchen;
      case 'curry':
        return Icons.rice_bowl;
      case 'stir-fry':
        return Icons.restaurant;
      case 'rice dish':
        return Icons.dinner_dining;
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
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
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
