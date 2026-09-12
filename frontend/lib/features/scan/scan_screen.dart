import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_client.dart';
import '../../data/models/identify_result.dart';
import '../../shared/widgets/ui_kit.dart';

/// Fish identification against the backend CV model (`POST /identify`).
///
/// The scanner suggests; it never decides. Even a top candidate above the
/// model's validated threshold is presented for confirmation, because
/// sustainability, price and cooking advice are only meaningful once the
/// species is actually right — and naming the wrong fish confidently is worse
/// than admitting uncertainty.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const int _maxBytes = 10 * 1024 * 1024;
  static const Set<String> _allowed = <String>{'jpg', 'jpeg', 'png', 'webp'};

  final ImagePicker _picker = ImagePicker();
  final ApiClient _api = ApiClient();

  bool _loading = false;
  String? _fileLabel;
  Uint8List? _preview;
  IdentifyResult? _result;
  String? _rejectReason;
  ApiException? _error;

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  String? _validate(String filename, int size) {
    final String ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : '';
    if (!_allowed.contains(ext)) {
      return 'Use a JPEG, PNG or WebP image up to 10 MB.';
    }
    if (size > _maxBytes) {
      return 'The photo exceeds the 10 MB limit. Use JPEG, PNG or WebP '
          'at 10 MB or less.';
    }
    return null;
  }

  Future<void> _pick(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (file == null) return;

    final Uint8List bytes = await file.readAsBytes();
    final String? rejection = _validate(file.name, bytes.length);
    if (!mounted) return;
    setState(() {
      _fileLabel = file.name;
      _preview = bytes;
      _result = null;
      _error = null;
      _rejectReason = rejection;
    });
  }

  Future<void> _identify() async {
    final Uint8List? bytes = _preview;
    if (bytes == null || _rejectReason != null) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final IdentifyResult result = await _api.identify(
        bytes: bytes,
        filename: _fileLabel ?? 'capture.jpg',
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
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
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _CaptureHeader(label: _fileLabel, preview: _preview),
            const SizedBox(height: 14),
            const _CoverageCard(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: _loading
                        ? null
                        : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: _loading
                        ? null
                        : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'One whole fish fills the frame, on a plain background. '
              'Your photo is used for this identification only and is not stored.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  minimumSize: const Size(44, 48),
                ),
                onPressed: _loading || _rejectReason != null ? null : _identify,
                child: const Text('Identify this photo'),
              ),
            ],
            if (_rejectReason != null) ...[
              const SizedBox(height: 12),
              SoftCard(
                child: Text(
                  _rejectReason!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(color: AppColors.teal),
            if (_error != null) _ScanError(error: _error!),
            if (_result != null) _Candidates(result: _result!),
          ],
        ),
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scanner coverage',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'This scanner currently identifies only these five species. '
            'Other seafood should be found through Search or Discovery.',
          ),
          const SizedBox(height: 8),
          for (final String name in AppConstants.scannerSpeciesLabels)
            Text('• $name'),
        ],
      ),
    );
  }
}

class _CaptureHeader extends StatelessWidget {
  const _CaptureHeader({this.label, this.preview});

  final String? label;
  final Uint8List? preview;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 210,
          width: double.infinity,
          child: preview != null
              ? Image.memory(preview!, fit: BoxFit.cover)
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.navyDeep, AppColors.headerTeal],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 46,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          label ?? 'Point at the fish on the counter',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.error});

  final ApiException error;

  @override
  Widget build(BuildContext context) {
    final String headline;
    final String detail;

    if (error.isUnreachable) {
      headline = 'Cannot reach the scanner';
      detail =
          'The SukaSeafood API is not responding. '
          'Check that the backend is running and reachable from this device.';
    } else if (error.isModelUnavailable) {
      headline = 'Scanner unavailable';
      detail =
          'The identification model is not loaded on the server, so no '
          'species can be suggested right now. Search by name or browse Discovery instead.';
    } else if (error.statusCode == 415 || error.statusCode == 422) {
      headline = 'That image will not work';
      detail =
          'Use a JPEG, PNG or WebP photo of a single whole fish, '
          'maximum 10 MB, then try again.';
    } else if (error.statusCode == 413) {
      headline = 'Image too large';
      detail =
          'The photo exceeds the 10 MB limit. Supported formats are '
          'JPEG, PNG and WebP.';
    } else {
      headline = 'Identification failed';
      detail = error.message;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.avoid),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headline,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            const _Fallbacks(),
          ],
        ),
      ),
    );
  }
}

class _Fallbacks extends StatelessWidget {
  const _Fallbacks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => context.go('/explore'),
          child: const Text('Search / Discovery'),
        ),
      ],
    );
  }
}

class _Candidates extends StatelessWidget {
  const _Candidates({required this.result});

  final IdentifyResult result;

  @override
  Widget build(BuildContext context) {
    if (result.candidates.isEmpty || result.isLowConfidence) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.candidates.isEmpty
                    ? 'This seafood could not be reliably identified.'
                    : 'Identification is uncertain. The model did not clear '
                          'its confidence threshold, so this is not a confirmed match.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try a clearer photo of one whole fish, or use Search and '
                'Discovery to browse supported seafood.',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/explore'),
                      child: const Text('Search'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/explore'),
                      child: const Text('Discovery'),
                    ),
                  ),
                ],
              ),
              if (result.candidates.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Possible names, not confirmed:',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                ...result.candidates.map(
                  (IdentifyCandidate candidate) => _CandidateCard(
                    candidate: candidate,
                    emphasized: false,
                    uncertain: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Confirm before continuing',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick the fish in front of you. Nothing is decided until you do.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        ...result.candidates.map(
          (IdentifyCandidate candidate) => _CandidateCard(
            candidate: candidate,
            emphasized: candidate.rank == 1,
          ),
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'None of these match',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => context.go('/explore'),
                    child: const Text('Search'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/explore'),
                    child: const Text('Discovery'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Model ${result.modelVersion}',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    this.emphasized = false,
    this.uncertain = false,
  });

  final IdentifyCandidate candidate;
  final bool emphasized;
  final bool uncertain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uncertain
                            ? 'Uncertain suggestion'
                            : (emphasized ? 'Top suggestion' : 'Also possible'),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        candidate.canonicalNameMs,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        candidate.displayNameEn,
                        style: const TextStyle(color: AppColors.ink),
                      ),
                      Text(
                        candidate.scientificName,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ],
                  ),
                ),
                _ConfidenceBadge(confidence: candidate.confidence),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: emphasized && !uncertain
                      ? AppColors.navy
                      : AppColors.tealSoft,
                  foregroundColor: emphasized && !uncertain
                      ? Colors.white
                      : AppColors.navy,
                ),
                onPressed: () => context.push('/seafood/${candidate.code}'),
                child: Text(
                  uncertain ? 'Open Fish Bio anyway' : 'This is my fish',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${(confidence * 100).round()}%',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        const Text(
          'confidence',
          style: TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }
}
