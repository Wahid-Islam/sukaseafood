import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/fish_ids.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';
import 'occurrence_map.dart';

class BiodiversityContextScreen extends StatefulWidget {
  const BiodiversityContextScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  State<BiodiversityContextScreen> createState() =>
      _BiodiversityContextScreenState();
}

class _BiodiversityContextScreenState extends State<BiodiversityContextScreen> {
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
          title: const Text('Biodiversity Context'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
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
    final BiodiversityContext bio = profile.biodiversityContext;
    final CatalogController catalog = context.watch<CatalogController>();
    final bool saved = catalog.isFavourite(profile.fishId);

    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        backgroundColor: AppColors.foam,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          children: [
            Text(
              'Biodiversity Context',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Understanding the bigger picture',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: saved ? 'Remove favourite' : 'Save favourite',
            onPressed: () => catalog.toggleFavourite(profile.fishId),
            icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _IdentityCard(profile: profile),
            const SizedBox(height: 12),
            const _WhyItMatters(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _FactCard(
                    icon: Icons.waves_outlined,
                    title: 'Habitat',
                    body: bio.habitatLabel == null
                        ? 'Unavailable'
                        : 'FishBase classifies this species as ${bio.habitatGroup}.',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FactCard(
                    icon: Icons.vertical_align_center,
                    title: 'Depth range',
                    body: bio.depthLabel == null
                        ? 'Unavailable'
                        : 'Commonly found from ${bio.depthLabel}.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FactCard(
              icon: Icons.set_meal_outlined,
              title: 'Ecological role',
              body:
                  (bio.ecologicalRole ?? bio.ecosystemNote)
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? (bio.ecologicalRole ?? bio.ecosystemNote)!
                  : 'Unavailable',
            ),
            const SizedBox(height: 12),
            _DistributionCard(bio: bio),
            const SizedBox(height: 12),
            _ConservationCard(bio: bio),
            const SizedBox(height: 16),
            _SourcesFooter(bio: bio),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final SeafoodProfile profile;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CatalogueFishArt(
            fishId: profile.fishId,
            networkUrl: profile.imageUrl,
            width: 72,
            height: 72,
            borderRadius: 16,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.shortName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  profile.scientificName,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (profile.alsoKnownAs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Also known as: ${profile.alsoKnownAs}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyItMatters extends StatelessWidget {
  const _WhyItMatters();

  @override
  Widget build(BuildContext context) {
    return const SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.spa_outlined, color: AppColors.tealDark),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Why biodiversity matters',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Healthy oceans support diverse marine life, which helps ensure seafood is available for future generations.',
          ),
        ],
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.tealDark),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.bio});

  final BiodiversityContext bio;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_outlined, color: AppColors.tealDark),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Observed distribution',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bio.occurrences.isEmpty
                ? 'No OBIS occurrence points are on file for this species. Map dots are not invented.'
                : 'Locations where this species has been observed, based on recorded marine biodiversity data.',
          ),
          if (bio.occurrences.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 240,
                width: double.infinity,
                child: OccurrenceMap(points: bio.occurrences),
              ),
            ),
            const SizedBox(height: 8),
            const OccurrenceMapLegend(),
          ],
        ],
      ),
    );
  }
}

class _ConservationCard extends StatelessWidget {
  const _ConservationCard({required this.bio});

  final BiodiversityContext bio;

  @override
  Widget build(BuildContext context) {
    final String? badge = bio.iucnBadge;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.tealDark),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conservation status',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Assessed by the IUCN Red List of Threatened Species.'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _iucnColor(bio.iucnCategory).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.eco_outlined,
                        color: _iucnColor(bio.iucnCategory),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          badge ?? 'Unavailable',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _iucnColor(bio.iucnCategory),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (bio.populationTrend == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Population trend is unavailable. The IUCN token API was not used.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourcesFooter extends StatelessWidget {
  const _SourcesFooter({required this.bio});

  final BiodiversityContext bio;

  @override
  Widget build(BuildContext context) {
    final List<BiodiversitySource> sources = bio.sources;
    final String cited = sources.isEmpty
        ? bio.sourceName
        : sources
              .where((BiodiversitySource s) => s.available)
              .map((BiodiversitySource s) => s.name)
              .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cited.isEmpty ? 'Sources: unavailable' : 'Sources: $cited',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        for (final BiodiversitySource source in sources)
          if (!source.available)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${source.name}: ${source.unavailableReason ?? 'Unavailable'}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
      ],
    );
  }
}

Color _iucnColor(String? code) {
  switch ((code ?? '').toUpperCase()) {
    case 'LC':
      return AppColors.good;
    case 'NT':
      return AppColors.reduce;
    case 'VU':
    case 'EN':
    case 'CR':
      return AppColors.avoid;
    default:
      return AppColors.muted;
  }
}
