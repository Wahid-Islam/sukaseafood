import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/api_client.dart';
import '../../data/mock/mock_catalog.dart';
import '../../data/models/price_forecast.dart' as api;
import '../../shared/widgets/ui_kit.dart';
import 'forecast_card.dart';

class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key, required this.seafoodId});

  /// Either a prototype slug or a canonical backend code (`SF001`).
  final String seafoodId;

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  final ApiClient _api = ApiClient();

  int _tab = 0;
  bool _loadingForecast = true;
  api.PriceForecast? _forecast;
  ApiException? _forecastError;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  /// The observed-price content is prototype data, so a forecast failure must
  /// not take the screen down with it — the card reports its own state.
  Future<void> _loadForecast() async {
    try {
      final api.PriceForecast forecast =
          await _api.forecast(MockCatalog.apiFishId(widget.seafoodId));
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
        _loadingForecast = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _forecastError = error;
        _loadingForecast = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final SeafoodItem? prototype = MockCatalog.tryById(widget.seafoodId);
    if (prototype == null) {
      // A canonical species with no prototype content — a scan can reach one.
      // The forecast is live data and stands on its own.
      return _ForecastOnlyScaffold(
        fishId: widget.seafoodId,
        forecast: _forecast,
        error: _forecastError,
        loading: _loadingForecast,
      );
    }
    final SeafoodItem item = prototype;
    final List<PricePoint> history = MockCatalog.historyFor(item);

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DarkHeader(
              height: 210,
              backgroundUrl: item.imageUrl,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const Spacer(),
                        const Icon(Icons.favorite_border, color: Colors.white),
                        const SizedBox(width: 12),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price & Supply',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                ),
                          ),
                          Text(
                            'Real-time price, trend and outlook to help you choose better.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.commonName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            item.scientificName,
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Also known as: ${item.alsoKnownAs}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SheetBody(
              child: Column(
                children: [
                  SoftCard(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        _TabChip(
                          label: 'Current',
                          icon: Icons.credit_card,
                          selected: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                        _TabChip(
                          label: 'Trend',
                          icon: Icons.show_chart,
                          selected: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                        _TabChip(
                          label: 'Outlook',
                          icon: Icons.center_focus_strong,
                          selected: _tab == 2,
                          onTap: () => setState(() => _tab = 2),
                        ),
                        _TabChip(
                          label: 'Supply',
                          icon: Icons.sailing,
                          selected: _tab == 3,
                          onTap: () => setState(() => _tab = 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Observed Price',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'RM ${item.priceRm.toStringAsFixed(2)} /kg',
                                    style: const TextStyle(
                                      color: AppColors.good,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 30,
                                    ),
                                  ),
                                  const Text('Latest observed price from PriceCatcher'),
                                  const SizedBox(height: 10),
                                  ClassificationPill(label: item.classification),
                                  const SizedBox(height: 4),
                                  const Text('A sustainable and responsible choice.'),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                const Text('vs last 4 weeks', style: TextStyle(fontSize: 11)),
                                Text(
                                  '↓ ${item.priceChangePct.abs().toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: AppColors.good,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                                ),
                                Text(
                                  'RM ${(item.priceRm + 1.1).toStringAsFixed(2)} /kg',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historical Trend (Last 12 weeks)',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      final int i = value.round();
                                      if (i < 0 || i >= history.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(
                                        history[i].label.split(' ').first,
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  isCurved: true,
                                  color: AppColors.good,
                                  barWidth: 3,
                                  spots: [
                                    for (int i = 0; i < history.length; i++)
                                      FlSpot(i.toDouble(), history[i].price),
                                  ],
                                  dotData: const FlDotData(show: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Stat(
                              label: 'Lowest',
                              value: 'RM ${item.priceLow.toStringAsFixed(2)}',
                            ),
                            _Stat(
                              label: 'Average',
                              value:
                                  'RM ${((item.priceLow + item.priceHigh) / 2).toStringAsFixed(2)}',
                            ),
                            _Stat(
                              label: 'Highest',
                              value: 'RM ${item.priceHigh.toStringAsFixed(2)}',
                              danger: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ForecastCard(
                    forecast: _forecast,
                    error: _forecastError,
                    loading: _loadingForecast,
                  ),
                  const SizedBox(height: 14),
                  const SoftCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sources: PriceCatcher · Department of Fisheries Malaysia '
                            '· SukaSeafood forecast engine',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Price view for a canonical species with no prototype content.
///
/// Reachable by scanning any of the species the prototype catalogue does not
/// cover. Showing the live forecast alone is the honest option: fabricating
/// observed-price history so the layout matches the other screens would put
/// invented numbers next to real model output.
class _ForecastOnlyScaffold extends StatelessWidget {
  const _ForecastOnlyScaffold({
    required this.fishId,
    required this.forecast,
    required this.error,
    required this.loading,
  });

  final String fishId;
  final api.PriceForecast? forecast;
  final ApiException? error;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final String title = forecast?.canonicalName ?? fishId;

    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        title: const Text('Price outlook'),
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
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 20),
                ),
                if (forecast != null && forecast!.displayName.isNotEmpty)
                  Text(
                    forecast!.displayName,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Observed price history is not available in this build for '
                  'this species. The forecast below is live model output.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ForecastCard(
            forecast: forecast,
            error: error,
            loading: loading,
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.goodSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.good : AppColors.muted),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.good : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: danger ? AppColors.avoid : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
