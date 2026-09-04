import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'ui_kit.dart';

/// Local catalogue plates from the 12-fish photo set.
class CatalogueFishArt extends StatelessWidget {
  const CatalogueFishArt({
    super.key,
    required this.fishId,
    this.networkUrl,
    this.width = 140,
    this.height = 140,
    this.borderRadius = 16,
    this.fit = BoxFit.contain,
  });

  static const Map<String, String> photos = <String, String>{
    'SF001': 'assets/images/catalogue/sf001.jpg',
    'SF002': 'assets/images/catalogue/sf002.jpg',
    'SF006': 'assets/images/catalogue/sf006.jpg',
    'SF007': 'assets/images/catalogue/sf007.jpg',
    'SF008': 'assets/images/catalogue/sf008.jpg',
    'SF009': 'assets/images/catalogue/sf009.jpg',
    'SF011': 'assets/images/catalogue/sf011.jpg',
    'SF012': 'assets/images/catalogue/sf012.jpg',
  };

  final String fishId;
  final String? networkUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  static String? assetFor(String fishId) => photos[fishId.toUpperCase()];

  static String? photoAssetFor(String fishId) => assetFor(fishId);

  static bool hasLocalPlate(String fishId) => assetFor(fishId) != null;

  @override
  Widget build(BuildContext context) {
    final String? asset = assetFor(fishId);
    final int? cacheWidth = width.isFinite
        ? (width * MediaQuery.devicePixelRatioOf(context)).round()
        : null;
    final Widget image = asset != null
        ? Image.asset(
            asset,
            fit: fit,
            width: width.isFinite ? width : null,
            height: height.isFinite ? height : null,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.medium,
            semanticLabel: 'Catalogue photo of $fishId',
            errorBuilder: (context, error, stack) {
              return const ColoredBox(
                color: AppColors.tealSoft,
                child: Icon(Icons.set_meal, color: AppColors.navy, size: 36),
              );
            },
          )
        : NetworkFishImage(
            url: networkUrl,
            height: height.isFinite ? height : null,
            borderRadius: 0,
            fit: fit,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: const Color(0xFF1B3A4A),
        child: SizedBox(width: width, height: height, child: image),
      ),
    );
  }
}

/// Full-width plate used on the home highlight and the species identity card.
class CatalogueFishBanner extends StatelessWidget {
  const CatalogueFishBanner({
    super.key,
    required this.fishId,
    this.networkUrl,
    this.fit = BoxFit.contain,
    this.aspectRatio = 16 / 9,
  });

  final String fishId;
  final String? networkUrl;
  final BoxFit fit;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = (width / aspectRatio).clamp(140.0, 240.0);
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: CatalogueFishArt(
            fishId: fishId,
            networkUrl: networkUrl,
            width: width,
            height: height,
            borderRadius: 0,
            fit: fit,
          ),
        );
      },
    );
  }
}
