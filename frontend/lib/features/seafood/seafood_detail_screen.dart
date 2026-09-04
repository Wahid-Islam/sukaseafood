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
import 'wwf_card.dart';

class SeafoodDetailScreen extends StatefulWidget {
  const SeafoodDetailScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  State<SeafoodDetailScreen> createState() => _SeafoodDetailScreenState();
}

class _SeafoodDetailScreenState extends State<SeafoodDetailScreen> {
  late final String _fishId = FishIds.canonical(widget.seafoodId);
  SeafoodProfile? _profile;
  PriceContext? _price;
  Object? _error;

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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
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
    final bool priced = _price?.isDisplayable == true;

    if (_error != null && profile == null && summary == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Species'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error?.toString() ?? 'Species not found.'),
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

    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: saved ? 'Remove favourite' : 'Save favourite',
            onPressed: () =>
                context.read<CatalogController>().toggleFavourite(fishId),
            icon: Icon(
              saved ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          _IdentityCard(
            fishId: fishId,
            name: name,
            scientificName: scientific,
            imageUrl: imageUrl,
            alsoKnownAs: profile?.alsoKnownAs ?? '',
            about: profile?.about ?? '',
          ),
          if (profile == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            const SizedBox(height: 14),
            SoftCard(
              child: Row(
                children: [
                  _Fact(
                    icon: Icons.bubble_chart_outlined,
                    label: 'Fish Type',
                    value: profile.fishType,
                  ),
                  _divider(),
                  _Fact(
                    icon: Icons.place_outlined,
                    label: 'Common in',
                    value: profile.commonIn,
                  ),
                  _divider(),
                  _Fact(
                    icon: Icons.calendar_month_outlined,
                    label: 'Observed in market',
                    value: profile.marketAvailability,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            WwfCard(info: profile.sustainability),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SoftCard(
                    onTap: () => context.push('/price/${profile.fishId}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LIVE DATA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.good,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check Price',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        const Icon(
                          Icons.show_chart,
                          color: AppColors.good,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        if (priced)
                          Text(
                            'RM ${_price!.observedPriceRmPerKg!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          )
                        else
                          Text(
                            _price?.status ?? 'Outlook',
                            style: const TextStyle(fontSize: 13),
                          ),
                        const Text('Observed / kg'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SoftCard(
                    onTap: () => context.push('/cooking/${profile.fishId}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COOKING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7B61FF),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Find Cooking Options',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        CatalogueFishArt(
                          fishId: profile.fishId,
                          networkUrl: profile.imageUrl,
                          width: 140,
                          height: 52,
                          borderRadius: 10,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.cooking.isEmpty
                              ? 'No method scores yet'
                              : '${profile.cooking.first.method} · ${profile.cooking.first.starsOutOfFive}/5',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _divider() =>
      Container(width: 1, height: 46, color: AppColors.line);
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.fishId,
    required this.name,
    required this.scientificName,
    this.imageUrl,
    this.alsoKnownAs = '',
    this.about = '',
  });

  final String fishId;
  final String name;
  final String scientificName;
  final String? imageUrl;
  final String alsoKnownAs;
  final String about;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CatalogueFishBanner(
            fishId: fishId,
            networkUrl: imageUrl,
            fit: BoxFit.cover,
            aspectRatio: 16 / 10,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  scientificName,
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (alsoKnownAs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Also known as: $alsoKnownAs',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (about.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ExpandableText(text: about, maxLines: 3),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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
