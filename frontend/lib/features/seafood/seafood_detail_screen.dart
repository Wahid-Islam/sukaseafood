import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock/mock_catalog.dart';
import '../../shared/widgets/ui_kit.dart';

class SeafoodDetailScreen extends StatelessWidget {
  const SeafoodDetailScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  Widget build(BuildContext context) {
    final SeafoodItem? prototype = MockCatalog.tryById(seafoodId);
    if (prototype == null) {
      // A confirmed scan can land on any of the fourteen canonical species,
      // and the prototype catalogue covers seven. Sustainability and cooking
      // copy for the rest is not in this build; the live price outlook is.
      return _ProfileUnavailable(fishId: seafoodId);
    }
    final SeafoodItem item = prototype;
    final Color tone = AppTheme.classificationColor(item.classification);

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.navy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: const [
              Icon(Icons.favorite_border, color: Colors.white),
              SizedBox(width: 8),
              Icon(Icons.ios_share, color: Colors.white),
              SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: AppColors.navy),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          AppColors.navy.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.commonName,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: 36,
                              ),
                        ),
                        Text(
                          item.scientificName,
                          style: const TextStyle(
                            color: AppColors.teal,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.photo_camera_outlined,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              'Also known as: ${item.alsoKnownAs}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.about,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 16,
                    bottom: 16,
                    child: Text('1/5', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
                children: [
                  SoftCard(
                    child: Row(
                      children: [
                        _Fact(
                          icon: Icons.bubble_chart_outlined,
                          label: 'Fish Type',
                          value: item.fishType,
                        ),
                        _divider(),
                        _Fact(
                          icon: Icons.place_outlined,
                          label: 'Common in',
                          value: item.commonIn,
                        ),
                        _divider(),
                        _Fact(
                          icon: Icons.calendar_month_outlined,
                          label: 'Observed in market',
                          value: item.marketAvailability,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.spa, color: AppColors.good),
                                  SizedBox(width: 8),
                                  Text(
                                    'WWF Sustainability Classification',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: tone),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.classification,
                                    style: TextStyle(
                                      color: tone,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(item.classificationBlurb),
                              const SizedBox(height: 10),
                              const Text(
                                'About WWF ratings',
                                style: TextStyle(
                                  color: AppColors.tealDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: CustomPaint(
                            painter: _GaugePainter(color: tone),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    color: AppColors.goodSoft,
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.eco, color: tone),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Why this is a good choice for you',
                                style: TextStyle(
                                  color: tone,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(item.whyGood.join(' · ')),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SoftCard(
                          onTap: () => context.push('/price/${item.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.circle, size: 8, color: AppColors.good),
                                  SizedBox(width: 6),
                                  Text(
                                    'LIVE DATA',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.good,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Text(
                                    'Check Price',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  Icon(Icons.north_east, size: 14, color: AppColors.tealDark),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Icon(Icons.show_chart, color: AppColors.good, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'RM ${item.priceRm.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                              const Text('Latest price / kg'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SoftCard(
                          onTap: () => context.push('/cooking/${item.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.restaurant, size: 14, color: Color(0xFF7B61FF)),
                                  SizedBox(width: 6),
                                  Text(
                                    'COOKING',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF7B61FF),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Text(
                                    'Find Cooking Options',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  Icon(Icons.north_east, size: 14, color: Color(0xFF7B61FF)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              NetworkFishImage(
                                url: MockCatalog.grilled,
                                height: 52,
                                borderRadius: 10,
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(Icons.star, color: AppColors.star, size: 16),
                                  Icon(Icons.star, color: AppColors.star, size: 16),
                                  Icon(Icons.star, color: AppColors.star, size: 16),
                                  Icon(Icons.star, color: AppColors.star, size: 16),
                                  Icon(Icons.star, color: AppColors.star, size: 16),
                                ],
                              ),
                              const Text('Top rating match'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider() => Container(width: 1, height: 46, color: AppColors.line);
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.tealDark, size: 18),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Landing state for a canonical species this build has no profile content for.
///
/// Deliberately sparse. A confident-looking profile assembled from defaults
/// would be worse than an empty one: sustainability advice is the whole point
/// of the screen, and inventing it for an unsourced species would mislead
/// exactly the decision the app exists to inform.
class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable({required this.fishId});

  final String fishId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        title: const Text('Species confirmed'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fishId,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sustainability and cooking guidance for this species is not '
                  'in this build yet. We would rather show nothing than guess a '
                  'rating.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => context.push('/price/$fishId'),
                    icon: const Icon(Icons.show_chart),
                    label: const Text('See price outlook'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height * 0.7);
    final double radius = size.width * 0.42;
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = AppColors.line;
    final Paint value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      3.14,
      3.14,
      false,
      track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      3.14,
      2.5,
      false,
      value,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.color != color;
}
