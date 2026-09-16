import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/fish_ids.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';
import 'biodiversity_context_screen.dart';
import 'wwf_card.dart';

class SustainabilityBiodiversityScreen extends StatefulWidget {
  const SustainabilityBiodiversityScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  State<SustainabilityBiodiversityScreen> createState() =>
      _SustainabilityBiodiversityScreenState();
}

class _SustainabilityBiodiversityScreenState
    extends State<SustainabilityBiodiversityScreen> {
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
    if (_error != null && _profile == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.foam,
          foregroundColor: AppColors.navy,
          title: const Text(
            'Sustainability',
            style: TextStyle(color: AppColors.navy),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.navy),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('This section is unavailable.')),
      );
    }
    if (_profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final SeafoodProfile profile = _profile!;
    final CatalogController catalog = context.watch<CatalogController>();
    final bool saved = catalog.isFavourite(profile.fishId);

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: ContentWidth(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _SpeciesHero(
                profile: profile,
                saved: saved,
                onBack: () => context.pop(),
                onFavourite: () => catalog.toggleFavourite(profile.fishId),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  _NumberedSection(
                    number: '01',
                    title: 'Sustainability',
                    subtitle: 'How good a choice is this?',
                    trailing: const _WwfChip(),
                    child: WwfCard(info: profile.sustainability),
                  ),
                  const SizedBox(height: 16),
                  BiodiversityContextSections(profile: profile),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeciesHero extends StatelessWidget {
  const _SpeciesHero({
    required this.profile,
    required this.saved,
    required this.onBack,
    required this.onFavourite,
  });

  final SeafoodProfile profile;
  final bool saved;
  final VoidCallback onBack;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 240),
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return CatalogueFishArt(
                  fishId: profile.fishId,
                  networkUrl: profile.imageUrl,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  borderRadius: 0,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Color(0xF2082433),
                    Color(0xCC082433),
                    Color(0x66082433),
                    Color(0x00082433),
                  ],
                  stops: <double>[0, 0.42, 0.72, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        visualDensity: VisualDensity.compact,
                        alignment: Alignment.centerLeft,
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: saved ? 'Remove favourite' : 'Save favourite',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        visualDensity: VisualDensity.compact,
                        alignment: Alignment.centerRight,
                        onPressed: onFavourite,
                        icon: Icon(
                          saved ? Icons.favorite : Icons.favorite_border,
                          color: saved ? const Color(0xFFFF8A80) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SUSTAINABILITY',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Color(0xFF8BE0D4),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.shortName,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.scientificName,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            color: Color(0xFFB7E4DC),
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                        if (profile.alsoKnownAs.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Also known as: ${profile.alsoKnownAs}',
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
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
}

class _NumberedSection extends StatelessWidget {
  const _NumberedSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String number;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.tealDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _WwfChip extends StatelessWidget {
  const _WwfChip();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.eco_outlined, size: 16, color: AppColors.tealDark),
        SizedBox(width: 4),
        Text(
          'WWF Save Our Seafood',
          style: TextStyle(
            color: AppColors.tealDark,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
