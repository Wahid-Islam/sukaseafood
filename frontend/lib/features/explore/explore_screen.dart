import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog/catalog_controller.dart';
import '../../data/models/seafood.dart';
import '../../shared/widgets/catalogue_fish_art.dart';
import '../../shared/widgets/ui_kit.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<SeafoodSummary> _results = const <SeafoodSummary>[];
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final String q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const <SeafoodSummary>[];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final List<SeafoodSummary> found = await context
            .read<CatalogController>()
            .search(q);
        if (!mounted) return;
        setState(() {
          _results = found;
          _searching = false;
          _searchError = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _results = const <SeafoodSummary>[];
          _searching = false;
          _searchError = error.toString();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = context.watch<CatalogController>();
    final List<SeafoodSummary> popular = catalog.items.take(8).toList();
    final bool showResults = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      BrandLogo(size: 36),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SukaSeafood',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Better choices. Healthier oceans.',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(
                        context,
                      ).textTheme.displayLarge?.copyWith(fontSize: 34),
                      children: const [
                        TextSpan(text: 'Cari '),
                        TextSpan(
                          text: 'seafood',
                          style: TextStyle(color: AppColors.teal),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find. Understand. Choose better.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.foam,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  TextField(
                    controller: _controller,
                    onChanged: _onQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Search seafood by name',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (showResults) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Results',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_searchError != null)
                      SoftCard(child: Text(_searchError!))
                    else if (_results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No species matched that name in the live catalogue.',
                        ),
                      )
                    else
                      ..._results.map(
                        (SeafoodSummary item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: CatalogueFishArt(
                              fishId: item.fishId,
                              networkUrl: item.imageUrl,
                              width: 48,
                              height: 48,
                              borderRadius: 10,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(item.shortName),
                          subtitle: Text(item.scientificName),
                          trailing: ClassificationPill(
                            label: item.classification ?? 'UNDETERMINED',
                          ),
                          onTap: () => context.push('/seafood/${item.fishId}'),
                        ),
                      ),
                  ] else ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Catalogue',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 118,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: popular.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final SeafoodSummary item = popular[index];
                          return SizedBox(
                            width: 100,
                            child: SoftCard(
                              padding: const EdgeInsets.all(8),
                              onTap: () =>
                                  context.push('/seafood/${item.fishId}'),
                              child: Column(
                                children: [
                                  CatalogueFishArt(
                                    fishId: item.fishId,
                                    networkUrl: item.imageUrl,
                                    width: 84,
                                    height: 64,
                                    borderRadius: 12,
                                    fit: BoxFit.cover,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.shortName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SoftCard(
                      onTap: () => context.push('/seafood/SF001'),
                      child: const Row(
                        children: [
                          Icon(Icons.set_meal, color: AppColors.tealDark),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(color: AppColors.ink),
                                children: [
                                  TextSpan(text: 'Are you looking for '),
                                  TextSpan(
                                    text: 'Kembung',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' (Rastrelliger kanagurta)?',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
