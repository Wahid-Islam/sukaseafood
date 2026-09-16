import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/cooking_intent.dart';
import '../../shared/widgets/catalogue_fish_art.dart';

/// Badge colour for a recipe's cuisine (Malay, Chinese, Indian).
Color cuisineColor(String? cuisine) {
  switch (cuisine) {
    case 'Malay':
      return const Color(0xFF0E8F84);
    case 'Chinese':
      return const Color(0xFFC0392B);
    case 'Indian':
      return const Color(0xFFD9822B);
    default:
      return AppColors.tealDark;
  }
}

/// The AI photo for a generated recipe.
///
/// The first request for a photo can take 10-30 seconds while the backend
/// generates it, so this shows a soft "plating" placeholder rather than a bare
/// spinner, and falls back to the catalogue fish art if generation fails or
/// photos are switched off on the server.
class RecipeImage extends StatelessWidget {
  const RecipeImage({
    super.key,
    required this.recipe,
    this.height = 160,
    this.borderRadius = BorderRadius.zero,
    this.fallbackImageUrl,
  });

  final Recipe recipe;
  final double height;
  final BorderRadius borderRadius;
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    final String? url = recipe.imageUrl;
    final Widget fallback = CatalogueFishArt(
      fishId: recipe.fishId,
      networkUrl: fallbackImageUrl,
      width: double.infinity,
      height: height,
      borderRadius: 0,
      fit: BoxFit.cover,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: height,
                gaplessPlayback: true,
                semanticLabel: 'Photo of ${recipe.title}',
                loadingBuilder:
                    (BuildContext context, Widget child, ImageChunkEvent? progress) {
                      if (progress == null) return child;
                      return const _PlatingPlaceholder();
                    },
                frameBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      int? frame,
                      bool wasSynchronouslyLoaded,
                    ) {
                      if (wasSynchronouslyLoaded || frame != null) return child;
                      return const _PlatingPlaceholder();
                    },
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                    fallback,
              ),
      ),
    );
  }
}

class _PlatingPlaceholder extends StatelessWidget {
  const _PlatingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE8F6F4), Color(0xFFF4F7F9)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.tealDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Plating your dish…',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
