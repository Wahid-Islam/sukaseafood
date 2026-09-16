import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/fish_ids.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/ui_kit.dart';

class SeafoodDetailScreen extends StatefulWidget {
  const SeafoodDetailScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  State<SeafoodDetailScreen> createState() => _SeafoodDetailScreenState();
}

class _SeafoodDetailScreenState extends State<SeafoodDetailScreen> {
  late final String _fishId = FishIds.canonical(widget.seafoodId);
  SeafoodProfile? _profile;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final SeafoodProfile profile = await context
          .read<CatalogController>()
          .profile(_fishId);
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final SeafoodSummary? summary = catalog.itemById(_fishId);
    final SeafoodProfile? profile = _profile;
    final bool saved = catalog.isFavourite(
      profile?.fishId ?? summary?.fishId ?? _fishId,
    );

    if (_error != null && profile == null && summary == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fish Bio'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This seafood record is not available.'),
          ),
        ),
      );
    }

    if (profile == null && summary == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String fishId = profile?.fishId ?? summary!.fishId;
    final String name = profile?.shortName ?? summary!.shortName;
    final String scientific =
        profile?.scientificName ?? summary!.scientificName;
    final String? imageUrl = profile?.imageUrl ?? summary?.imageUrl;
    final String classification =
        profile?.classification ?? summary?.classification ?? 'UNDETERMINED';

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: AppColors.navy,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/explore');
                      }
                    },
                  ),
                  actions: [
                    IconButton(
                      tooltip: saved ? 'Remove favourite' : 'Save favourite',
                      onPressed: () => context
                          .read<CatalogController>()
                          .toggleFavourite(fishId),
                      icon: Icon(
                        saved ? Icons.favorite : Icons.favorite_border,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CatalogueFishArt(
                          fishId: fishId,
                          networkUrl: imageUrl,
                          width: 800,
                          height: 240,
                          borderRadius: 0,
                          fit: BoxFit.cover,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x6606151F),
                                Color(0xCC06151F),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '1/1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            scientific,
                            style: const TextStyle(
                              color: AppColors.tealDark,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if ((profile?.alsoKnownAs ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Also known as: ${profile!.alsoKnownAs}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if ((profile?.about ?? '').isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ExpandableText(text: profile!.about, maxLines: 3),
                          ],
                          const SizedBox(height: 16),
                          SoftCard(
                            child: Row(
                              children: [
                                _Fact(
                                  icon: Icons.set_meal_outlined,
                                  label: 'Fish Type',
                                  value: _prettyType(
                                    profile?.fishType ??
                                        summary?.fishType ??
                                        'Seafood',
                                  ),
                                ),
                                _divider(),
                                _Fact(
                                  icon: Icons.place_outlined,
                                  label: 'Common in',
                                  value: profile?.commonIn ?? 'Malaysia',
                                ),
                                _divider(),
                                _Fact(
                                  icon: Icons.calendar_month_outlined,
                                  label: 'Observed in market',
                                  value:
                                      profile?.marketAvailability ??
                                      'Year-round',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (profile == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else ...[
                            _HubRow(
                              icon: Icons.eco_outlined,
                              iconColor: AppColors.good,
                              title: 'Sustainability',
                              subtitle:
                                  'WWF catch-method ratings plus habitat, '
                                  'IUCN status, and observed distribution.',
                              trailing: ClassificationPill(
                                label: classification,
                              ),
                              onTap: () => context.push(
                                '/seafood/$fishId/sustainability',
                              ),
                            ),
                            const SizedBox(height: 10),
                            _HubRow(
                              icon: Icons.show_chart,
                              iconColor: AppColors.tealDark,
                              title: 'Price Context',
                              subtitle:
                                  'View latest prices, historical trends and market insights.',
                              onTap: () => context.push('/price/$fishId'),
                            ),
                            const SizedBox(height: 10),
                            _HubRow(
                              icon: Icons.restaurant_outlined,
                              iconColor: const Color(0xFF7B61FF),
                              title: 'Smart Swap & Cooking',
                              subtitle:
                                  'Find better alternatives and get recipe recommendations.',
                              onTap: () =>
                                  context.push('/seafood/$fishId/swap'),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Sources are shown inside each section. '
                              'Missing facts stay marked unavailable.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/explore'),
                  icon: const Icon(Icons.search),
                  label: const Text('Find another seafood'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _prettyType(String raw) {
    final String value = raw.trim();
    if (value.toLowerCase().contains('pelagic')) return 'Pelagic Fish';
    if (value.toLowerCase().contains('reef')) return 'Reef Fish';
    if (value.toLowerCase().contains('demersal')) return 'Demersal Fish';
    if (value.toLowerCase().contains('freshwater')) return 'Freshwater Fish';
    if (value.isEmpty) return 'Unavailable';
    return value;
  }

  static Widget _divider() =>
      Container(width: 1, height: 46, color: AppColors.line);
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.tealDark, size: 18),
          const SizedBox(height: 6),
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

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          const SizedBox(
            width: 24,
            height: 24,
            child: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
