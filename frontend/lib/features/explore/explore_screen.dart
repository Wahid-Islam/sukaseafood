import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock/mock_catalog.dart';
import '../../shared/widgets/ui_kit.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _recent = List<String>.from(MockCatalog.recentSearches);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<SeafoodItem> popular = MockCatalog.items.take(4).toList();
    final List<SeafoodItem> results = MockCatalog.search(_controller.text);

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
                  Row(
                    children: [
                      const Icon(Icons.waves, color: AppColors.teal),
                      const SizedBox(width: 8),
                      const Expanded(
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
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.info_outline, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 34,
                          ),
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
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
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search seafood by name',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () => context.go('/scan'),
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
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
                  SoftCard(
                    color: const Color(0xFFEAF4F8),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_camera_outlined, color: AppColors.navy),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Not sure what fish it is? Snap a photo of the fish in front of you to identify it and get smarter choices.',
                            style: TextStyle(color: AppColors.ink, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => context.go('/scan'),
                          child: const Text('Use camera'),
                        ),
                      ],
                    ),
                  ),
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Results',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    ...results.map(
                      (SeafoodItem item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: NetworkFishImage(url: item.imageUrl, borderRadius: 10),
                        ),
                        title: Text(item.commonName),
                        subtitle: Text(item.scientificName),
                        trailing: ClassificationPill(label: item.classification),
                        onTap: () => context.push('/seafood/${item.id}'),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Text(
                          'Recent searches',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _recent = <String>[]),
                          style: TextButton.styleFrom(foregroundColor: AppColors.avoid),
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recent
                          .map(
                            (String name) => InputChip(
                              avatar: const Icon(Icons.history, size: 16),
                              label: Text(name),
                              onDeleted: () => setState(() => _recent.remove(name)),
                              onPressed: () {
                                _controller.text = name;
                                setState(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Popular searches',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 118,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: popular.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final SeafoodItem item = popular[index];
                          return SizedBox(
                            width: 100,
                            child: SoftCard(
                              padding: const EdgeInsets.all(8),
                              onTap: () => context.push('/seafood/${item.id}'),
                              child: Column(
                                children: [
                                  NetworkFishImage(
                                    url: item.imageUrl,
                                    height: 64,
                                    borderRadius: 12,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.commonName,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
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
                      onTap: () => context.push('/seafood/kembung'),
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
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  TextSpan(
                                    text: ' (Rastrelliger spp.)?',
                                    style: TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Search suggestions',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    ...MockCatalog.suggestions.map(
                      (String s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.search, color: AppColors.muted),
                        title: Text(s),
                        trailing: const Icon(Icons.north_east, size: 16),
                        onTap: () {
                          _controller.text = s;
                          setState(() {});
                        },
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
