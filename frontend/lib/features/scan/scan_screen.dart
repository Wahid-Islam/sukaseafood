import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker _picker = ImagePicker();
  final ApiClient _api = ApiClient();

  bool _loading = false;
  String? _fileLabel;
  IdentifyResult? _result;
  ApiException? _error;

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      // The model resizes to 224px anyway, so a full-resolution phone capture
      // only costs upload time. 1600px leaves ample detail for the fins and
      // stripes the classifier keys on.
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (file == null) return;

    setState(() {
      _loading = true;
      _fileLabel = file.name;
      _result = null;
      _error = null;
    });

    try {
      final IdentifyResult result = await _api.identify(
        bytes: await file.readAsBytes(),
        filename: file.name,
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _CaptureHeader(label: _fileLabel),
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
          const SizedBox(height: 6),
          const Text(
            'One whole fish fills the frame, on a plain background. '
            'Your photo is used for this identification only and is not stored.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(color: AppColors.teal),
          if (_error != null) _ScanError(error: _error!),
          if (_result != null) _Candidates(result: _result!),
        ],
      ),
    );
  }
}

class _CaptureHeader extends StatelessWidget {
  const _CaptureHeader({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
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
              const Icon(Icons.camera_alt_outlined,
                  color: Colors.white, size: 46),
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
    );
  }
}

/// Why the scanner could not answer, in the user's terms.
///
/// The three cases are genuinely different and get different copy: an
/// unreachable API is a setup problem, an unavailable model is a deployment
/// state, and a rejected image is something the user can fix by retaking it.
class _ScanError extends StatelessWidget {
  const _ScanError({required this.error});

  final ApiException error;

  @override
  Widget build(BuildContext context) {
    final String headline;
    final String detail;

    if (error.isUnreachable) {
      headline = 'Cannot reach the scanner';
      detail = 'The SukaSeafood API is not responding. '
          'Check that the backend is running and reachable from this device.';
    } else if (error.isModelUnavailable) {
      headline = 'Scanner unavailable';
      detail = 'The identification model is not loaded on the server, so no '
          'species can be suggested right now. Search by name instead.';
    } else if (error.statusCode == 415 || error.statusCode == 422) {
      headline = 'That image will not work';
      detail = 'Use a JPEG, PNG or WebP photo of a single whole fish, '
          'then try again.';
    } else if (error.statusCode == 413) {
      headline = 'Image too large';
      detail = 'The photo exceeds the 10 MB limit. Retake it at a lower '
          'resolution.';
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
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Candidates extends StatelessWidget {
  const _Candidates({required this.result});

  final IdentifyResult result;

  @override
  Widget build(BuildContext context) {
    if (result.candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: SoftCard(
          child: Text(
            'No species could be suggested for that photo. Try a clearer shot '
            'of one whole fish, or search by name.',
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
        Text(
          result.isLowConfidence
              // The model did not clear its own validated threshold. Saying so
              // plainly is the point: the alternative is presenting a guess
              // with the same visual weight as a confident match.
              ? 'The model is not confident about any of these. Check the fish '
                  'against the names below before choosing one.'
              : 'Pick the fish in front of you. Nothing is decided until you do.',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        ...result.candidates.map(
          (IdentifyCandidate candidate) => _CandidateCard(
            candidate: candidate,
            emphasized: candidate.rank == 1 && !result.isLowConfidence,
          ),
        ),
        SoftCard(
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'None of these match',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/explore'),
                child: const Text('Search by name'),
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
  });

  final IdentifyCandidate candidate;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emphasized ? 'Top suggestion' : 'Also possible',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                      Text(
                        candidate.canonicalNameMs,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18),
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
                  backgroundColor:
                      emphasized ? AppColors.navy : AppColors.tealSoft,
                  foregroundColor:
                      emphasized ? Colors.white : AppColors.navy,
                ),
                // The canonical code is what every downstream screen keys off.
                onPressed: () => context.push('/seafood/${candidate.code}'),
                child: const Text('This is my fish'),
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
