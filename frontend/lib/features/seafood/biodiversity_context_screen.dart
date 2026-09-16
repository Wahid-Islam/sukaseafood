import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';
import 'occurrence_map.dart';

/// Habitat, IUCN, and OBIS sections used on the Sustainability page.
class BiodiversityContextSections extends StatelessWidget {
  const BiodiversityContextSections({super.key, required this.profile});

  final SeafoodProfile profile;

  @override
  Widget build(BuildContext context) {
    final BiodiversityContext bio = profile.biodiversityContext;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionNumber(number: '02'),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BIODIVERSITY CONTEXT',
                      style: TextStyle(
                        color: AppColors.tealDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      'Why does this fish matter?',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Where this fish fits',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          _WhereThisFishFits(bio: bio),
          const SizedBox(height: 12),
          _DistributionCard(bio: bio),
          const SizedBox(height: 12),
          _ConservationCard(bio: bio),
          const SizedBox(height: 12),
          _SourcesFooter(bio: bio),
        ],
      ),
    );
  }
}

class _WhereThisFishFits extends StatelessWidget {
  const _WhereThisFishFits({required this.bio});

  final BiodiversityContext bio;

  @override
  Widget build(BuildContext context) {
    final String role = (bio.ecologicalRole ?? '').trim();
    final _FitTile habitat = _FitTile(
      icon: Icons.waves_outlined,
      title: 'Habitat',
      value: bio.habitatLabel ?? 'Unavailable',
      body: bio.habitatLabel == null
          ? 'No FishBase habitat record is on file.'
          : 'Commonly found in coastal waters.',
    );
    final _FitTile depth = _FitTile(
      icon: Icons.vertical_align_center,
      title: 'Depth range',
      value: bio.depthLabel ?? 'Unavailable',
      body: bio.depthLabel == null
          ? 'No recorded depth range is on file.'
          : 'Typically found in this depth band.',
    );
    final _FitTile ecological = _FitTile(
      icon: Icons.set_meal_outlined,
      title: 'Ecological role',
      value: role.isEmpty ? 'Unavailable' : '',
      body: role.isEmpty ? 'No ecological-role note is on file.' : role,
      expand: true,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: habitat),
                    const SizedBox(width: 8),
                    Expanded(child: depth),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ecological,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: habitat),
              const SizedBox(width: 8),
              Expanded(child: depth),
              const SizedBox(width: 8),
              Expanded(child: ecological),
            ],
          ),
        );
      },
    );
  }
}

class _SectionNumber extends StatelessWidget {
  const _SectionNumber({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _FitTile extends StatelessWidget {
  const _FitTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.body,
    this.expand = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String body;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: expand ? Alignment.topLeft : Alignment.topCenter,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: expand
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.tealDark, size: 22),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: expand ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (value.trim().isNotEmpty)
            Text(
              value,
              textAlign: expand ? TextAlign.left : TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.navy,
                height: 1.25,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: expand ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class BiodiversityIdentityCard extends StatelessWidget {
  const BiodiversityIdentityCard({super.key, required this.profile});

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
                    color: AppColors.navy,
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
                      color: AppColors.ink,
                      fontSize: 12,
                      height: 1.35,
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

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.bio});

  final BiodiversityContext bio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined, color: AppColors.tealDark),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Where this fish is found',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (bio.occurrences.isNotEmpty)
                TextButton(
                  onPressed: () => _openLargeMap(context),
                  child: const Text('View larger map  >'),
                ),
            ],
          ),
          const Text(
            'Recorded observations from marine biodiversity data.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (bio.occurrences.isEmpty)
            const Text(
              'No OBIS occurrence points are on file for this species. Map dots are not invented.',
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 168,
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

  void _openLargeMap(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Where this fish is found',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: OccurrenceMap(points: bio.occurrences)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConservationCard extends StatelessWidget {
  const _ConservationCard({required this.bio});

  final BiodiversityContext bio;

  @override
  Widget build(BuildContext context) {
    final String? badge = bio.iucnBadge;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(18),
      ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              InfoButton(
                message:
                    'IUCN Red List categories come from the IUCN token API when it returns a record.',
              ),
            ],
          ),
          const SizedBox(height: 8),
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
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'IUCN Red List of Threatened Species',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, color: AppColors.tealDark),
              SizedBox(width: 8),
              Text(
                'Sources',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final String name in _sourceNames)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> get _sourceNames {
    final List<String> names = <String>[
      'WWF Save Our Seafood',
      ...bio.sources
          .where((BiodiversitySource s) => s.available)
          .map((BiodiversitySource s) => s.name),
    ];
    return names.toSet().toList();
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
