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

    final Widget classification = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const WwfLogo(height: 32),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'WWF Sustainability Classification',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const InfoButton(message: aboutRatings),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Based on assessed fishing methods and their impacts on marine ecosystems.',
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 12),
          if (methods.isEmpty)
            const ClassificationPill(label: 'UNDETERMINED')
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < methods.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _MethodColumn(rating: methods[i])),
                ],
              ],
            ),
          if (methods.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              varies
                  ? 'Rating varies by catch method.'
                  : _meterCaption(methods.first.classification),
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );

    final Widget why = Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.eco_outlined, color: AppColors.tealDark, size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Why this rating?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            info?.whyItMatters ??
                'We would rather show UNDETERMINED than invent a rating.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('About WWF ratings'),
                    content: const Text(aboutRatings),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.tealDark),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'About WWF ratings',
                    style: TextStyle(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: AppColors.tealDark),
              ],
            ),
          ),
          if (!verified)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Not verified — UNDETERMINED is the honest state.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [classification, const SizedBox(height: 10), why],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: classification),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: why),
          ],
        );
      },
    );
  }

  static String _meterCaption(String classification) {
    switch (classification.toUpperCase()) {
      case 'GOOD CHOICE':
      case 'BEST CHOICE':
        return 'Better choice for healthier oceans';
      case 'REDUCE':
        return 'Eat less often, and confirm the catch method.';
      case 'AVOID':
        return 'Avoid this catch method where possible.';
      default:
        return 'No verified WWF rating is on file.';
    }
  }
}

class _MethodColumn extends StatelessWidget {
  const _MethodColumn({required this.rating});

  final MethodRating rating;

  @override
  Widget build(BuildContext context) {
    final Color color = AppTheme.classificationColor(rating.classification);
    final String code = rating.classification.toUpperCase();
    final bool good = code == 'GOOD CHOICE' || code == 'BEST CHOICE';
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
