import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/sukaseafood_api.dart';
import '../../data/models/seafood_models.dart';
import '../../shared/widgets/common_widgets.dart';

class CookingScreen extends StatefulWidget {
  const CookingScreen({super.key, required this.api});

  final SukaseafoodApi api;

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  String _method = AppConstants.cookingMethods.first;
  late Future<List<SeafoodSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.cookingRecommendations(_method);
  }

  void _select(String method) {
    setState(() {
      _method = method;
      _future = widget.api.cookingRecommendations(method);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cooking intent')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'What are you cooking?',
              subtitle: 'Recommendations ranked by suitability + sustainability',
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AppConstants.cookingMethods.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final String method = AppConstants.cookingMethods[index];
                  final bool selected = method == _method;
                  return ChoiceChip(
                    label: Text(method),
                    selected: selected,
                    selectedColor: AppTheme.teal.withValues(alpha: 0.3),
                    onSelected: (_) => _select(method),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<SeafoodSummary>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: snapshot.hasError
                          ? Text('${snapshot.error}')
                          : const CircularProgressIndicator(),
                    );
                  }
                  final List<SeafoodSummary> items = snapshot.data!;
                  if (items.isEmpty) {
                    return const Text('No verified recommendations yet.');
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final SeafoodSummary item = items[index];
                      return SeafoodListTile(
                        title: item.primaryCommonName,
                        subtitle: 'Recommended for $_method',
                        classification: item.classification,
                        onTap: () => context.push('/seafood/${item.fishId}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
