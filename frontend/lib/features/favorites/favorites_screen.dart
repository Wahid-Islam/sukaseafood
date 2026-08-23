import 'package:flutter/material.dart';

import '../../shared/widgets/common_widgets.dart';

/// Placeholder favourites surface for Iteration 1 supporting functions.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Saved seafood',
              subtitle: 'Account favourites wire-up lands with auth (I1 supporting)',
            ),
            Text(
              'No favourites yet. Open a seafood profile and save it once '
              'authentication is enabled.',
            ),
          ],
        ),
      ),
    );
  }
}
