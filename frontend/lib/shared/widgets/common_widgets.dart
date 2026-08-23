import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Pill showing WWF-style sustainability classification.
class ClassificationChip extends StatelessWidget {
  const ClassificationChip({super.key, required this.classification});

  final String classification;

  @override
  Widget build(BuildContext context) {
    final Color color = AppTheme.classificationColor(classification);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        classification.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Reusable seafood list tile for search / cooking results.
class SeafoodListTile extends StatelessWidget {
  const SeafoodListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.classification,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? classification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppTheme.teal.withValues(alpha: 0.2),
        child: const Icon(Icons.set_meal, color: AppTheme.navy),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: classification == null
          ? const Icon(Icons.chevron_right)
          : ClassificationChip(classification: classification!),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.navy.withValues(alpha: 0.65),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
