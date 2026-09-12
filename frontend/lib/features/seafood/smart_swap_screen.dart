import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/discovery_categories.dart';
import '../../data/catalog/fish_ids.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';

class SmartSwapScreen extends StatelessWidget {
  const SmartSwapScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  Widget build(BuildContext context) {
    final String fishId = FishIds.canonical(seafoodId);
    final CatalogController catalog = context.watch<CatalogController>();
    final SeafoodSummary? current = catalog.itemById(fishId);
    final List<SeafoodSummary> swaps = current == null
        ? const <SeafoodSummary>[]
        : DiscoveryCatalog.betterSwaps(
            current: current,
            catalogue: catalog.items,
          );

    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        title: const Text('Smart Swap & Cooking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              current?.shortName ?? fishId,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              current == null
                  ? 'Seafood record unavailable.'
                  : 'Alternatives use WWF ratings already on file. '
                        'UNDETERMINED species are never treated as better.',
            ),
            const SizedBox(height: 14),
            SoftCard(
              onTap: () => context.push('/cooking/$fishId'),
              child: const Row(
                children: [
                  Icon(Icons.restaurant_outlined, color: Color(0xFF7B61FF)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cooking Intent',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Open cooking methods with this seafood selected.',
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Better-rated alternatives',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (current == null)
              const SoftCard(
                child: Text('This seafood record is not available.'),
              )
            else if (DiscoveryCatalog.swapRank(current.classification) == 0)
              const SoftCard(
                child: Text(
                  'This species is already among the better-rated '
                  'choices on file. No higher WWF rating is available.',
                ),
              )
            else if (swaps.isEmpty)
              const SoftCard(
                child: Text(
                  'No better-rated alternative is on file for this species. '
                  'We do not invent a swap.',
                ),
              )
            else
              for (final SeafoodSummary item in swaps) ...[
                SoftCard(
                  onTap: () => context.push('/seafood/${item.fishId}'),
                  child: Row(
                    children: [
                      CatalogueFishArt(
                        fishId: item.fishId,
                        networkUrl: item.imageUrl,
                        width: 64,
                        height: 56,
                        borderRadius: 12,
                        fit: BoxFit.cover,
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
                              ),
                            ),
                            ClassificationPill(
                              label: item.classification ?? 'UNDETERMINED',
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}
