import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
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

class ClassificationPill extends StatelessWidget {
  const ClassificationPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = AppTheme.classificationColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
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
  });

  final String url;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height ?? 140,
          color: AppColors.tealSoft,
          alignment: Alignment.center,
          child: const Icon(Icons.set_meal, color: AppColors.navy, size: 36),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height ?? 140,
            color: AppColors.line,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
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
  });

  final Widget child;
  final double height;
  final String? backgroundUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundUrl != null)
            Image.network(
              backgroundUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.navy),
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
