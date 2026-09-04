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
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';
import 'forecast_card.dart';
import 'historical_trend_card.dart';
import 'week_over_week.dart';

class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key, required this.seafoodId, this.initialTab});

  final String seafoodId;

  /// Kept so older `/price/:id?tab=` links still open this page.
  final String? initialTab;

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  late final String _fishId = FishIds.canonical(widget.seafoodId);

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

  Future<void> _load() async {
    final CatalogController catalog = context.read<CatalogController>();
    final String? locationId = context
        .read<AuthController>()
        .forecastLocationId;
    final Future<SeafoodProfile> profileFut = catalog.profile(_fishId);
    final Future<PriceContext> priceFut = catalog.price(_fishId);
    final Future<api.PriceForecast> forecastFut = catalog.forecast(
      _fishId,
      locationId: locationId,
    );
    SeafoodProfile? profile;
    PriceContext? price;
    api.PriceForecast? forecast;
    ApiException? forecastError;
    try {
      profile = await profileFut;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _forecastError = ApiException(error.toString());
        _loading = false;
      });
      return;
    }
    try {
      price = await priceFut;
    } catch (_) {
      price = null;
    }
    try {
      forecast = await forecastFut;
    } on ApiException catch (error) {
      forecastError = error;
    } catch (error) {
      forecastError = ApiException(error.toString());
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _price = price;
      _forecast = forecast;
      _forecastError = forecastError;
      _loading = false;
    });
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
              backgroundAsset: CatalogueFishArt.photoAssetFor(_fishId),
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
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
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
                            'Price',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: Colors.white),
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
              topPadding: 32,
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      children: [
                        _currentRow(),
                        const SizedBox(height: 14),
                        HistoricalTrendCard(
                          history: _price?.history ?? const [],
                        ),
                        const SizedBox(height: 14),
                        ForecastCard(
                          forecast: _forecast,
                          error: _forecastError,
                          loading: false,
                          history: _price?.history ?? const [],
                        ),
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

  static const TextStyle _metricTitleStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 13,
    height: 1.2,
  );

  Widget _metricTitle(String title, {Widget? trailing}) {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _metricTitleStyle,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _currentRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _currentCard()),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _comparedCard()),
        ],
      ),
    );
  }

  Widget _splitCard({required List<Widget> header, Widget? footer}) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...header, ?footer],
      ),
    );
  }

  Widget _currentCard() {
    final PriceContext? price = _price;
    final bool priced = price?.isDisplayable == true;
    return _splitCard(
      header: [
        _metricTitle('Current Observed Price'),
        const SizedBox(height: 8),
        if (priced)
          Text(
            'RM ${price!.observedPriceRmPerKg!.toStringAsFixed(2)} /kg',
            style: const TextStyle(
              color: AppColors.good,
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          )
        else
          Text(
            price?.status ?? 'Insufficient data',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
        Text(
          priced
              ? 'Latest observed price from PriceCatcher'
              : 'PriceCatcher does not have enough recent observations to '
                    'show a current market price. The four-week outlook '
                    'below is the forecast engine’s range, not a live '
                    'stall price.',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
      footer: itemClassification.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ClassificationPill(
                label: itemClassification,
                caption: _classificationCaption(itemClassification),
              ),
            ),
    );
  }

  String get itemClassification => _profile?.classification ?? '';

  String? _classificationCaption(String label) {
    switch (label.toUpperCase()) {
      case 'GOOD CHOICE':
      case 'BEST CHOICE':
        return 'A sustainable and responsible choice.';
      case 'REDUCE':
        return 'Better to eat this less often.';
      case 'AVOID':
        return 'Choose a different species if you can.';
      default:
        return null;
    }
  }

  Widget _comparedCard() {
    final WeekOverWeek? change = WeekOverWeek.fromHistory(
      _price?.history ?? const [],
    );
    if (change == null) {
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metricTitle('Compared to last week'),
            const SizedBox(height: 8),
            const Text(
              'Need two weekly PriceCatcher points to compare.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    final bool down = change.fell;
    final Color colour = down
        ? AppColors.good
        : change.rose
        ? AppColors.avoid
        : AppColors.muted;
    final IconData icon = down
        ? Icons.arrow_downward
        : change.rose
        ? Icons.arrow_upward
        : Icons.trending_flat;
    final String pct = '${change.percent.abs().toStringAsFixed(0)}%';

    return _splitCard(
      header: [
        _metricTitle(
          'Compared to last week',
          trailing: const InfoButton(
            message:
                'Change between the latest two weekly Selangor medians. '
                'Not a forecast.',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: colour, size: 26),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                pct,
                style: TextStyle(
                  color: colour,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
            ),
          ],
        ),
        const Text(
          'Previous weekly PriceCatcher median',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CaptionedPill(
          color: colour,
          icon: Icons.history,
          label: 'Last week',
          caption: 'RM ${change.previousPrice.toStringAsFixed(2)} /kg',
        ),
      ),
    );
  }
}
