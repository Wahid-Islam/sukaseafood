import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/sukaseafood_api.dart';
import '../../data/models/seafood_models.dart';
import '../../shared/widgets/common_widgets.dart';

class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({super.key, required this.api});

  final SukaseafoodApi api;

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen> {
  final ImagePicker _picker = ImagePicker();
  IdentifyResult? _result;
  String? _pickedLabel;
  bool _loading = false;
  String? _error;

  Future<void> _pickAndIdentify(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _pickedLabel = file.name;
      _result = null;
    });

    try {
      // Mock CV adapter — Fish-Vista model plugs into the same /identify route.
      final IdentifyResult result = await widget.api.identify();
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _demoIdentify() async {
    setState(() {
      _loading = true;
      _error = null;
      _pickedLabel = 'demo-mock.jpg';
    });
    try {
      final IdentifyResult result = await widget.api.identify(hint: 'kembung');
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identify seafood')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            title: 'Scan at the counter',
            subtitle:
                'Photograph seafood, confirm the species, then continue the journey',
          ),
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [AppTheme.navy, AppTheme.deepSea],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: 42),
                  const SizedBox(height: 8),
                  Text(
                    _pickedLabel ?? 'No image selected',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _pickAndIdentify(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _pickAndIdentify(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _loading ? null : _demoIdentify,
            child: const Text('Use mock CV demo (Kembung)'),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_result != null) ...[
            const SizedBox(height: 12),
            if (_result!.isMock)
              const Text(
                'Using mock CV adapter (Fish-Vista model pending). '
                'Please confirm before continuing.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 8),
            _CandidateCard(
              label: 'Top prediction',
              candidate: _result!.topPrediction,
              emphasized: true,
              onConfirm: () => context.push(
                '/seafood/${_result!.topPrediction.fishId}',
              ),
            ),
            ..._result!.alternatives.map(
              (IdentifyCandidate c) => _CandidateCard(
                label: 'Alternative',
                candidate: c,
                onConfirm: () => context.push('/seafood/${c.fishId}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.label,
    required this.candidate,
    required this.onConfirm,
    this.emphasized = false,
  });

  final String label;
  final IdentifyCandidate candidate;
  final VoidCallback onConfirm;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: emphasized ? 1 : 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              candidate.primaryCommonName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(candidate.scientificName),
            Text('Confidence ${(candidate.confidence * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onConfirm,
              child: const Text('Confirm this species'),
            ),
          ],
        ),
      ),
    );
  }
}
