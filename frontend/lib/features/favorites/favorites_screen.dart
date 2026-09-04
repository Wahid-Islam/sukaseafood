import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<SeafoodSummary> items = context
        .watch<CatalogController>()
        .favourites;
    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(title: const Text('Favourites')),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nothing saved yet. Open a species and tap the heart — the list is yours, not a shared starter pack.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final SeafoodSummary item = items[index];
                return SoftCard(
                  onTap: () => context.push('/seafood/${item.fishId}'),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CatalogueFishArt(
                          fishId: item.fishId,
                          networkUrl: item.imageUrl,
                          width: 72,
                          height: 72,
                          borderRadius: 14,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.shortName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(item.scientificName),
                            const SizedBox(height: 6),
                            ClassificationPill(
                              label: item.classification ?? 'UNDETERMINED',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => context
                            .read<CatalogController>()
                            .toggleFavourite(item.fishId),
                        icon: const Icon(
                          Icons.favorite,
                          color: AppColors.avoid,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
