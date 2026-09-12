import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/fish_ids.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/ui_kit.dart';
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
          title: const Text('WWF Sustainability'),
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
    final SustainabilityInfo? info = profile.sustainability;

    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        title: const Text('WWF Sustainability'),
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
              profile.shortName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              profile.scientificName,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.tealDark,
              ),
            ),
            const SizedBox(height: 14),
            WwfCard(info: info),
            const SizedBox(height: 14),
            SoftCard(
              onTap: () =>
                  context.push('/seafood/${profile.fishId}/biodiversity'),
              child: const Row(
                children: [
                  Icon(Icons.public, color: AppColors.tealDark),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Open Biodiversity Context',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sources',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    info?.verified == true
                        ? '${info!.sourceName} — catch-method ratings. '
                              '${info.sourceUrl}'
                        : 'WWF Save Our Seafood — no verified assessment '
                              'on file (UNDETERMINED).',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
