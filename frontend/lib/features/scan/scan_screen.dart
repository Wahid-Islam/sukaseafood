import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock/mock_catalog.dart';
import '../../shared/widgets/ui_kit.dart';

/// Prototype scan screen — ML will later come from on-device TFLite / HF Space.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _fileLabel;
  SeafoodItem? _top;
  List<SeafoodItem> _alts = const [];

  Future<void> _pick(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _loading = true;
      _fileLabel = file.name;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    setState(() {
      _top = MockCatalog.byId('selar');
      _alts = <SeafoodItem>[
        MockCatalog.byId('kembung'),
        MockCatalog.byId('tongkol'),
      ];
      _loading = false;
    });
  }

  Future<void> _demo() async {
    setState(() {
      _loading = true;
      _fileLabel = 'demo-capture.jpg';
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    setState(() {
      _top = MockCatalog.byId('selar');
      _alts = <SeafoodItem>[
        MockCatalog.byId('kembung'),
        MockCatalog.byId('tenggiri'),
      ];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        title: const Text('Identify seafood'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          SoftCard(
            padding: EdgeInsets.zero,
            child: Container(
              height: 210,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [AppColors.navyDeep, AppColors.headerTeal],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 46),
                    const SizedBox(height: 10),
                    Text(
                      _fileLabel ?? 'Point at the fish on the counter',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Prototype mock — model hooks up later',
                      style: TextStyle(color: AppColors.teal, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _loading ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _loading ? null : _demo,
            child: const Text('Use mock identify (Selar)'),
          ),
          if (_loading) const LinearProgressIndicator(color: AppColors.teal),
          if (_top != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Confirm before continuing',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _PredictionCard(
              item: _top!,
              confidence: 0.86,
              emphasized: true,
              onConfirm: () => context.push('/seafood/${_top!.id}'),
            ),
            ..._alts.map(
              (SeafoodItem item) => _PredictionCard(
                item: item,
                confidence: item.id == 'kembung' ? 0.09 : 0.04,
                onConfirm: () => context.push('/seafood/${item.id}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.item,
    required this.confidence,
    required this.onConfirm,
    this.emphasized = false,
  });

  final SeafoodItem item;
  final double confidence;
  final VoidCallback onConfirm;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: NetworkFishImage(url: item.imageUrl, borderRadius: 12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emphasized ? 'Top prediction' : 'Alternative',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      Text(
                        item.commonName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      Text(
                        item.scientificName,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.tealDark,
                        ),
                      ),
                      Text('Confidence ${(confidence * 100).round()}%'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                onPressed: onConfirm,
                child: const Text('Confirm this species'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
