import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_client.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/catalog/fish_ids.dart';
import '../../data/models/price_forecast.dart' as api;
import '../../data/models/seafood.dart';
import '../../shared/widgets/ui_kit.dart';
import 'forecast_card.dart';

class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key, required this.seafoodId});

  final String seafoodId;

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  final ApiClient _api = ApiClient();

  late final String _fishId = FishIds.canonical(widget.seafoodId);
  int _tab = 0;
  bool _loading = true;
  SeafoodProfile? _profile;
  PriceContext? _price;
  api.PriceForecast? _forecast;
  ApiException? _forecastError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    final CatalogController catalog = context.read<CatalogController>();
    final String? locationId = context.read<AuthController>().forecastLocationId;
    try {
      final SeafoodProfile profile = await catalog.profile(_fishId);
      PriceContext? price;
      try {
        price = await catalog.price(_fishId);
      } catch (_) {
        price = null;
      }
      try {
        final api.PriceForecast forecast =
            await _api.forecast(_fishId, locationId: locationId);
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _price = price;
          _forecast = forecast;
          _loading = false;
        });
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _price = price;
          _forecastError = error;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _forecastError = ApiException(error.toString());
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final SeafoodProfile? item = _profile;
    final String title = item?.shortName ?? _forecast?.canonicalName ?? _fishId;
    final String scientific =
        item?.scientificName ?? _forecast?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DarkHeader(
              height: 210,
              backgroundUrl: item?.imageUrl,
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
                            'Observed PriceCatcher prices and the live four-week outlook.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            scientific,
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontStyle: FontStyle.italic,
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
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
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
                        if (_tab == 0) _currentCard(),
                        if (_tab == 1) _trendCard(),
                        if (_tab == 2)
                          ForecastCard(
                            forecast: _forecast,
                            error: _forecastError,
                            loading: false,
                          ),
                        if (_tab == 3) _supplyCard(),
                        if (_tab != 2) ...[
                          const SizedBox(height: 14),
                          ForecastCard(
                            forecast: _forecast,
                            error: _forecastError,
                            loading: false,
                          ),
                        ],
                        const SizedBox(height: 14),
                        const SoftCard(
                          child: Text(
                            'Sources: PriceCatcher · Department of Fisheries Malaysia '
                            '· SukaSeafood forecast engine. Observed prices and '
                            'forecasts are different series and may disagree.',
                            style: TextStyle(fontSize: 12),
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

  Widget _currentCard() {
    final PriceContext? price = _price;
    final bool priced = price?.isDisplayable == true;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Observed Price',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (priced)
            Text(
              'RM ${price!.latestPriceRmPerKg!.toStringAsFixed(2)} /kg',
              style: const TextStyle(
                color: AppColors.good,
                fontWeight: FontWeight.w900,
                fontSize: 30,
              ),
            )
          else
            Text(
              price?.status ?? 'Insufficient data',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          Text(
            priced
                ? 'Latest observed price from PriceCatcher'
                : (price?.disclaimer ??
                    'Not enough recent PriceCatcher observations to display a number.'),
          ),
          if (itemClassification.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClassificationPill(label: itemClassification),
          ],
        ],
      ),
    );
  }

  String get itemClassification =>
      _profile?.classification ?? '';

  Widget _trendCard() {
    final List<ObservedPricePoint> history = _price?.history ?? const [];
    if (history.isEmpty) {
      return const SoftCard(
        child: Text(
          'No displayable PriceCatcher history for this species yet. '
          'The four-week outlook below is modelled separately and is not a substitute.',
        ),
      );
    }
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historical Trend',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: AppColors.good,
                    barWidth: 3,
                    spots: [
                      for (int i = 0; i < history.length; i++)
                        FlSpot(i.toDouble(), history[i].priceRmPerKg),
                    ],
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplyCard() {
    final SupplyContext? supply = _profile?.supply;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Supply context',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            supply?.summary ??
                'Species-level landings are not published. We do not invent a pulse.',
          ),
          if (supply != null) ...[
            const SizedBox(height: 8),
            Text(
              '${supply.trendLabel} · ${supply.sourceName}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
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
