import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Wikimedia FilePath URLs need a User-Agent on Android. On web, custom
/// headers force a CORS fetch that Commons does not allow, so CanvasKit
/// falls back to the placeholder icon. HTML `<img>` tags load them instead.
Map<String, String>? _networkImageHeaders() {
  if (kIsWeb) return null;
  return const <String, String>{
    'User-Agent': 'SukaSeafood/1.0 (Flutter; educational)',
  };
}

WebHtmlElementStrategy get _webImageStrategy =>
    kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never;

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 16),
    this.color = AppColors.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 34});

  static const String asset = 'assets/images/suka_logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'SukaSeafood',
    );
  }
}

class WwfLogo extends StatelessWidget {
  const WwfLogo({super.key, this.height = 28});

  static const String asset = 'assets/images/wwf_logo.webp';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'WWF',
    );
  }
}

class ClassificationPill extends StatelessWidget {
  const ClassificationPill({super.key, required this.label, this.caption});

  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final String code = label.toUpperCase();
    return CaptionedPill(
      color: AppTheme.classificationColor(label),
      icon: switch (code) {
        'GOOD CHOICE' || 'BEST CHOICE' => Icons.check_circle,
        'REDUCE' => Icons.remove_circle,
        'AVOID' => Icons.cancel,
        _ => Icons.help,
      },
      label: label,
      caption: caption,
    );
  }
}

class CaptionedPill extends StatelessWidget {
  const CaptionedPill({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    this.caption,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final bool hasCaption = caption != null && caption!.isNotEmpty;
    final Widget labelText = Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 0.3,
      ),
    );
    final Widget body = hasCaption
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelText,
              Text(
                caption!,
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          )
        : labelText;

    return Container(
      width: hasCaption ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(hasCaption ? 14 : 999),
      ),
      child: Row(
        mainAxisSize: hasCaption ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          if (hasCaption) Expanded(child: body) else body,
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.title,
    this.trailing,
    this.icon,
  });

  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.tealDark),
          const SizedBox(width: 6),
        ],
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.tealDark,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class NetworkFishImage extends StatelessWidget {
  const NetworkFishImage({
    super.key,
    required this.url,
    this.height,
    this.borderRadius = 16,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = Container(
      height: height ?? 140,
      color: AppColors.tealSoft,
      alignment: Alignment.center,
      child: const Icon(Icons.set_meal, color: AppColors.navy, size: 36),
    );
    if (url == null || url!.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: placeholder,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url!,
        height: height,
        width: double.infinity,
        fit: fit,
        webHtmlElementStrategy: _webImageStrategy,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height ?? 140,
            color: AppColors.line,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
        headers: _networkImageHeaders(),
      ),
    );
  }
}

class DarkHeader extends StatelessWidget {
  const DarkHeader({
    super.key,
    required this.child,
    this.height = 220,
    this.backgroundUrl,
    this.backgroundAsset,
  });

  final Widget child;
  final double height;
  final String? backgroundUrl;
  final String? backgroundAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundAsset != null)
            Image.asset(
              backgroundAsset!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.navy),
            )
          else if (backgroundUrl != null)
            Image.network(
              backgroundUrl!,
              fit: BoxFit.cover,
              webHtmlElementStrategy: _webImageStrategy,
              headers: _networkImageHeaders(),
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.navy),
            )
          else
            const ColoredBox(color: AppColors.navy),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.navyDeep.withValues(alpha: 0.55),
                  AppColors.navy.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          SafeArea(bottom: false, child: child),
        ],
      ),
    );
  }
}

/// Tappable (i) control. Hover tooltips are easy to miss on phones and web.
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Show info',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
      iconSize: 16,
      color: AppColors.muted.withValues(alpha: 0.9),
      icon: const Icon(Icons.info_outline),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Info'),
              content: Text(message),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.child, this.topPadding = 20});

  final Widget child;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -24),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.foam,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, 24),
        child: child,
      ),
    );
  }
}

/// Keeps phone layouts on desktop without stretching copy edge-to-edge.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
