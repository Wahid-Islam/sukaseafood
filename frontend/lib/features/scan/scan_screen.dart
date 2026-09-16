import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
      body: Stack(
        children: [
          const _ScanBackdrop(),
          SafeArea(
            child: ContentWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _ScanChrome(
                    onClose: () => context.go('/home'),
                    onInfo: () => _showCoverageInfo(context),
                  ),
                  const SizedBox(height: 18),
                  const _ScanIntro(),
                  const SizedBox(height: 18),
                  _Viewfinder(preview: _preview),
                  const SizedBox(height: 14),
                  _ScanActionButton(
                    icon: Icons.photo_camera_outlined,
                    title: 'Camera',
                    subtitle: 'Take a photo now',
                    filled: true,
                    onTap: _loading ? null : () => _pick(ImageSource.camera),
                  ),
                  const SizedBox(height: 10),
                  _ScanActionButton(
                    icon: Icons.photo_outlined,
                    title: 'Gallery',
                    subtitle: 'Choose from your photos',
                    filled: false,
                    onTap: _loading ? null : () => _pick(ImageSource.gallery),
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        minimumSize: const Size(44, 48),
                      ),
                      onPressed: _loading || _rejectReason != null
                          ? null
                          : _identify,
                      child: const Text('Identify this photo'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const _TipsCard(),
                  if (_rejectReason != null) ...[
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Text(
                        _rejectReason!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(color: AppColors.teal),
                  ],
                  if (_error != null) _ScanError(error: _error!),
                  if (_result != null) _Candidates(result: _result!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCoverageInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scanner coverage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This scanner currently identifies only these five species. '
                'Other seafood should be found through Search or Discovery.',
              ),
              const SizedBox(height: 10),
              for (final String name in AppConstants.scannerSpeciesLabels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $name'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _ScanBackdrop extends StatelessWidget {
  const _ScanBackdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 460,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/explore/scanner_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x6606151F),
                  Color(0x2206151F),
                  Color(0x0006151F),
                  AppColors.foam,
                ],
                stops: <double>[0, 0.42, 0.72, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  Color(0x9906151F),
                  Color(0x3306151F),
                  Color(0x0006151F),
                ],
                stops: <double>[0, 0.45, 0.85],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanChrome extends StatelessWidget {
  const _ScanChrome({required this.onClose, required this.onInfo});

  final VoidCallback onClose;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        const Expanded(
          child: Column(
            children: [
              Text(
                'Identify seafood',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                'Scan. Discover. Choose Better.',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Scanner coverage',
          onPressed: onInfo,
          icon: const Icon(Icons.info_outline, color: Colors.white),
        ),
      ],
    );
  }
}

class _ScanIntro extends StatelessWidget {
  const _ScanIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Snap\nthe seafood',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 34,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(
          width: 260,
          child: Text(
            'Point your camera at the fish on the counter and we will identify it in seconds.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Same Oceans Brighter Tomorrows',
          style: GoogleFonts.dancingScript(
            color: const Color(0xFFB7E4DC),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({this.preview});

  final Uint8List? preview;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 210,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (preview != null)
              Image.memory(preview!, fit: BoxFit.cover)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xCC0B2A38), Color(0xB30B1C28)],
                  ),
                ),
              ),
            CustomPaint(painter: _CornerBracketsPainter()),
            if (preview == null)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white,
                      size: 42,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Point at the fish on the counter',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            const Positioned(right: 12, bottom: 12, child: _AutoBadge()),
          ],
        ),
      ),
    );
  }
}

class _AutoBadge extends StatelessWidget {
  const _AutoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x9906151F),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Auto',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const double inset = 18;
    const double arm = 22;
    final List<Offset> origins = <Offset>[
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ];
    final List<List<Offset>> arms = <List<Offset>>[
      <Offset>[const Offset(arm, 0), const Offset(0, arm)],
      <Offset>[const Offset(-arm, 0), const Offset(0, arm)],
      <Offset>[const Offset(arm, 0), const Offset(0, -arm)],
      <Offset>[const Offset(-arm, 0), const Offset(0, -arm)],
    ];
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(origins[i], origins[i] + arms[i][0], paint);
      canvas.drawLine(origins[i], origins[i] + arms[i][1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanActionButton extends StatelessWidget {
  const _ScanActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = filled ? Colors.white : AppColors.navy;
    return Material(
      color: filled ? AppColors.tealDark : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: filled ? null : Border.all(color: const Color(0xFFD7E4EA)),
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 28,
                color: filled
                    ? Colors.white.withValues(alpha: 0.35)
                    : AppColors.line,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: filled ? Colors.white70 : AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          const _TipRow(
            icon: Icons.lightbulb_outline,
            title: 'Scanner coverage',
            body:
                'This scanner currently identifies only these five species. '
                'Other seafood should be found through Search or Discovery.',
          ),
          const SizedBox(height: 12),
          const _TipRow(
            icon: Icons.photo_camera_outlined,
            title: 'Quick tip',
            body:
                'One whole fish fills the frame, on a plain background. '
                'Your photo is used for this identification only and is not stored.',
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.tealSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.tealDark, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
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
