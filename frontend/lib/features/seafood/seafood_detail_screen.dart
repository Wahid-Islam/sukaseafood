import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/fish_ids.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/ui_kit.dart';

class SeafoodDetailScreen extends StatefulWidget {
  const SeafoodDetailScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  State<SeafoodDetailScreen> createState() => _SeafoodDetailScreenState();
}

class _SeafoodDetailScreenState extends State<SeafoodDetailScreen> {
  late final String _fishId = FishIds.canonical(widget.seafoodId);
  SeafoodProfile? _profile;
  PriceContext? _price;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final CatalogController catalog = context.read<CatalogController>();
    try {
      final SeafoodProfile profile = await catalog.profile(_fishId);
      PriceContext? price;
      try {
        price = await catalog.price(_fishId);
      } catch (_) {
        price = null;
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _price = price;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Species'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error?.toString() ?? 'Species not found.'),
          ),
        ),
      );
    }

    final SeafoodProfile item = _profile!;
    final Color tone = AppTheme.classificationColor(item.classification);
    final bool saved = context.watch<CatalogController>().isFavourite(item.fishId);
    final bool priced = _price?.isDisplayable == true;

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
            actions: [
              IconButton(
                tooltip: saved ? 'Remove favourite' : 'Save favourite',
                onPressed: () =>
                    context.read<CatalogController>().toggleFavourite(item.fishId),
                icon: Icon(
                  saved ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkFishImage(url: item.imageUrl, borderRadius: 0),
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
                          item.shortName,
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
                        if (item.alsoKnownAs.isNotEmpty)
                          Text(
                            'Also known as: ${item.alsoKnownAs}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          item.about,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
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
                              ClassificationPill(label: item.classification),
                              const SizedBox(height: 6),
                              Text(
                                item.sustainability?.explanation ??
                                    'No WWF assessment is on file for this species.',
                              ),
                              if (item.sustainability != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  item.sustainability!.verified
                                      ? 'Verified from ${item.sustainability!.sourceName}'
                                      : 'Not verified — UNDETERMINED is the honest state, not a rating.',
                                  style: const TextStyle(
                                    color: AppColors.tealDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
                    child: Text(
                      item.sustainability?.whyItMatters ??
                          'We would rather show UNDETERMINED than invent a rating.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SoftCard(
                          onTap: () => context.push('/price/${item.fishId}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LIVE DATA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.good,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Check Price',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              const Icon(Icons.show_chart, color: AppColors.good, size: 36),
                              const SizedBox(height: 8),
                              if (priced)
                                Text(
                                  'RM ${_price!.latestPriceRmPerKg!.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                  ),
                                )
                              else
                                Text(
                                  _price?.status ?? 'Outlook',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              const Text('Observed / kg'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SoftCard(
                          onTap: () => context.push('/cooking/${item.fishId}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COOKING',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF7B61FF),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Find Cooking Options',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              NetworkFishImage(
                                url: item.imageUrl,
                                height: 52,
                                borderRadius: 10,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.cooking.isEmpty
                                    ? 'No method scores yet'
                                    : '${item.cooking.first.method} · ${item.cooking.first.starsOutOfFive}/5',
                              ),
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
