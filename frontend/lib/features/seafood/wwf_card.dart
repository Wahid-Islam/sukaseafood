import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/ui_kit.dart';

/// WWF Save Our Seafood card: one meter per catch method on file.
class WwfCard extends StatelessWidget {
  const WwfCard({super.key, this.info});

  final SustainabilityInfo? info;

  static const String aboutRatings =
      'WWF Save Our Seafood sometimes rates the same species differently '
      'by catch or farming method. Ask the seller how the fish was taken. '
      'Source: saveourseafood.my';

  @override
  Widget build(BuildContext context) {
    final List<MethodRating> methods = info?.methodRatings ?? const [];
    final bool varies = methods.length > 1;
    final bool verified = info?.verified == true;

    return Column(
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const WwfLogo(height: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WWF Sustainability Classification',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (varies)
                          const Text(
                            'Rating varies by catch method.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (methods.isEmpty)
                const ClassificationPill(label: 'UNDETERMINED')
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < methods.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: _MethodColumn(rating: methods[i])),
                    ],
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    verified
                        ? 'About WWF ratings'
                        : 'Not verified — UNDETERMINED is the honest state.',
                    style: const TextStyle(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const InfoButton(message: aboutRatings),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          color: AppColors.goodSoft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.tealSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco_outlined,
                  color: AppColors.tealDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Why?',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info?.whyItMatters ??
                          'We would rather show UNDETERMINED than invent a rating.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MethodColumn extends StatelessWidget {
  const _MethodColumn({required this.rating});

  final MethodRating rating;

  @override
  Widget build(BuildContext context) {
    final Color color = AppTheme.classificationColor(rating.classification);
    final bool good =
        rating.classification.toUpperCase() == 'REDUCE' ||
        rating.classification.toUpperCase() == 'GOOD CHOICE' ||
        rating.classification.toUpperCase() == 'BEST CHOICE';
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _methodIcon(rating.productionMethodCode),
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rating.productionMethod,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              good ? Icons.check_circle : Icons.cancel,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              rating.classification.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        WwfMeter(classification: rating.classification),
      ],
    );
  }
}

IconData _methodIcon(String code) {
  switch (code.toUpperCase()) {
    case 'HOOK_AND_LINE':
      return Icons.phishing;
    case 'GILLNET':
      return Icons.grid_4x4;
    case 'PURSE_SEINE':
      return Icons.circle_outlined;
    case 'TRAWL':
      return Icons.anchor;
    case 'AQUACULTURE':
      return Icons.water;
    default:
      return Icons.set_meal;
  }
}

/// Semicircle WWF meter. Needle sits at Avoid / Reduce / Good Choice.
class WwfMeter extends StatelessWidget {
  const WwfMeter({super.key, required this.classification});

  final String classification;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 64,
      child: CustomPaint(
        painter: _MeterPainter(classification: classification),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  const _MeterPainter({required this.classification});

  final String classification;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height - 6);
    final double radius = size.width / 2 - 8;
    const double start = math.pi;
    const double sweep = math.pi;
    final Rect arc = Rect.fromCircle(center: center, radius: radius);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.butt;

    track.color = AppColors.avoid;
    canvas.drawArc(arc, start, sweep / 3, false, track);
    track.color = AppColors.reduce;
    canvas.drawArc(arc, start + sweep / 3, sweep / 3, false, track);
    track.color = AppColors.good;
    canvas.drawArc(arc, start + 2 * sweep / 3, sweep / 3, false, track);

    final double t = switch (classification.toUpperCase()) {
      'AVOID' => 0.08,
      'REDUCE' => 0.5,
      'GOOD CHOICE' || 'BEST CHOICE' => 0.92,
      _ => 0.5,
    };
    final double angle = start + sweep * t;
    final Offset tip = Offset(
      center.dx + math.cos(angle) * (radius - 6),
      center.dy + math.sin(angle) * (radius - 6),
    );
    final Paint needle = Paint()
      ..color = AppColors.navy
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needle);
    canvas.drawCircle(center, 4.5, Paint()..color = AppColors.navy);
    canvas.drawCircle(center, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MeterPainter oldDelegate) {
    return oldDelegate.classification != classification;
  }
}
