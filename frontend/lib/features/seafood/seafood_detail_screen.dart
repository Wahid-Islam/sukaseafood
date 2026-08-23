import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/sukaseafood_api.dart';
import '../../data/models/seafood_models.dart';
import '../../shared/widgets/common_widgets.dart';

class SeafoodDetailScreen extends StatefulWidget {
  const SeafoodDetailScreen({
    super.key,
    required this.api,
    required this.fishId,
  });

  final SukaseafoodApi api;
  final String fishId;

  @override
  State<SeafoodDetailScreen> createState() => _SeafoodDetailScreenState();
}

class _SeafoodDetailScreenState extends State<SeafoodDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<SeafoodProfile> _profileFuture;
  late Future<PriceContext> _priceFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _profileFuture = widget.api.getProfile(widget.fishId);
    _priceFuture = widget.api.getPrice(widget.fishId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SeafoodProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Seafood')),
            body: Center(
              child: snapshot.hasError
                  ? Text('${snapshot.error}')
                  : const CircularProgressIndicator(),
            ),
          );
        }

        final SeafoodProfile profile = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text(profile.primaryCommonName),
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: AppTheme.teal,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Understand'),
                Tab(text: 'Price'),
                Tab(text: 'Cook'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _UnderstandTab(profile: profile),
              FutureBuilder<PriceContext>(
                future: _priceFuture,
                builder: (context, priceSnap) {
                  if (!priceSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _PriceTab(
                    profile: profile,
                    price: priceSnap.data!,
                  );
                },
              ),
              _CookTab(profile: profile),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.icon(
                onPressed: () => context.push('/cooking'),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Find cooking matches'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UnderstandTab extends StatelessWidget {
  const _UnderstandTab({required this.profile});

  final SeafoodProfile profile;

  @override
  Widget build(BuildContext context) {
    final SustainabilityInfo? sus = profile.sustainability;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          profile.primaryCommonName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(profile.scientificName),
        const SizedBox(height: 10),
        if (sus != null) ClassificationChip(classification: sus.classification),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Fact(label: 'Type', value: profile.fishType),
            _Fact(label: 'Common in', value: profile.commonIn),
            _Fact(label: 'Market', value: profile.marketAvailability),
          ],
        ),
        const SizedBox(height: 18),
        if (sus != null) ...[
          const SectionHeader(title: 'Why this classification'),
          Text(sus.explanation),
          const SizedBox(height: 12),
          const SectionHeader(title: 'Why it matters to you'),
          Text(sus.whyItMatters),
          const SizedBox(height: 8),
          Text(
            'Source: ${sus.sourceName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Origin: ${sus.origin} · Method: ${sus.productionMethod}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        const SectionHeader(title: 'About this seafood'),
        Text(profile.about),
        if (profile.aliases.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Also known as: ${profile.aliases.join(', ')}'),
        ],
      ],
    );
  }
}

class _PriceTab extends StatelessWidget {
  const _PriceTab({required this.profile, required this.price});

  final SeafoodProfile profile;
  final PriceContext price;

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = [];
    for (int i = 0; i < price.history.length; i++) {
      spots.add(FlSpot(i.toDouble(), price.history[i].priceRmPerKg));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(
          title: 'Observed price context',
          subtitle: 'OpenDOSM PriceCatcher — not a national average',
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                price.latestPriceRmPerKg == null
                    ? 'Unavailable'
                    : 'RM ${price.latestPriceRmPerKg!.toStringAsFixed(2)} /kg',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text('Status: ${price.status}'),
              if (price.changeVsRecentPct != null)
                Text(
                  '${price.changeVsRecentPct!.toStringAsFixed(1)}% vs recent window',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (spots.length >= 2) ...[
          const SectionHeader(title: 'Recent trend'),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.teal,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (profile.supply != null) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: 'Supply context'),
          Text(profile.supply!.trendLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(profile.supply!.summary),
          Text(
            'Source: ${profile.supply!.sourceName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        Text(price.disclaimer, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CookTab extends StatelessWidget {
  const _CookTab({required this.profile});

  final SeafoodProfile profile;

  @override
  Widget build(BuildContext context) {
    final List<CookingInfo> cooking = [...profile.cooking]
      ..sort((a, b) => b.suitabilityScore.compareTo(a.suitabilityScore));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(
          title: 'Cooking suitability',
          subtitle: 'Verified Iteration 1 mappings only',
        ),
        ...cooking.map(
          (CookingInfo c) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(c.method),
            subtitle: Text(c.rationale),
            trailing: Text('${(c.suitabilityScore * 100).round()}%'),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
