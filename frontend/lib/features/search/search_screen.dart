import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/sukaseafood_api.dart';
import '../../data/models/seafood_models.dart';
import '../../shared/widgets/common_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.api});

  final SukaseafoodApi api;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<SeafoodSummary> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<SeafoodSummary> results = await widget.api.search(query);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search seafood')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'What fish is this?',
              subtitle: 'Type a local, English, or scientific name',
            ),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _runSearch,
              decoration: InputDecoration(
                hintText: 'e.g. kembung, tilapia, red snapper',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _runSearch(_controller.text),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.go('/identify'),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Not sure? Use camera'),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final SeafoodSummary item = _results[index];
                  return SeafoodListTile(
                    title: item.primaryCommonName,
                    subtitle: item.scientificName,
                    classification: item.classification,
                    onTap: () => context.push('/seafood/${item.fishId}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
