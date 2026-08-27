import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock/mock_catalog.dart';
import '../../shared/widgets/ui_kit.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<SeafoodItem> items = MockCatalog.items.take(4).toList();
    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(title: const Text('Favourites')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final SeafoodItem item = items[index];
          return SoftCard(
            onTap: () => context.push('/seafood/${item.id}'),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: NetworkFishImage(url: item.imageUrl, borderRadius: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.commonName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(item.scientificName),
                      const SizedBox(height: 6),
                      ClassificationPill(label: item.classification),
                    ],
                  ),
                ),
                const Icon(Icons.favorite, color: AppColors.avoid),
              ],
            ),
          );
        },
      ),
    );
  }
}
