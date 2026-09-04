import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_kit.dart';

/// In-app alerts for price outlook, landings and species to watch.
///
/// These are product notices, not push notifications. Each row opens the
/// screen that can actually help — outlook, profile or the scanner.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static int get noticeCount => _notices.length;

  static const List<_Notice> _notices = <_Notice>[
    _Notice(
      title: 'Kembung outlook, Selangor',
      body:
          'The 4-week model sees no strong directional signal. '
          'Price is expected around current levels, not a spike or a drop.',
      when: 'Today',
      icon: Icons.trending_flat,
      route: '/price/SF001',
    ),
    _Notice(
      title: 'Open the four-week outlook',
      body:
          'Observed PriceCatcher prices and the modelled outlook are different series. '
          'Open Price to compare them.',
      when: 'Today',
      icon: Icons.show_chart,
      route: '/price/SF001',
    ),
    _Notice(
      title: 'Tenggiri is in the live catalogue',
      body:
          'Open the profile for the API sustainability rating, price outlook and cooking scores.',
      when: 'Yesterday',
      icon: Icons.check_circle_outline,
      route: '/seafood/SF012',
    ),
    _Notice(
      title: 'Ikan Merah — check the rating',
      body:
          'See the WWF classification from the live catalogue, and what to cook instead.',
      when: 'This week',
      icon: Icons.warning_amber_rounded,
      route: '/seafood/SF003',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        title: const Text('Alerts'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _notices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final _Notice notice = _notices[index];
          return SoftCard(
            onTap: () => context.push(notice.route),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.tealSoft,
                  child: Icon(notice.icon, color: AppColors.tealDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.body,
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notice.when,
                        style: const TextStyle(
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Notice {
  const _Notice({
    required this.title,
    required this.body,
    required this.when,
    required this.icon,
    required this.route,
  });

  final String title;
  final String body;
  final String when;
  final IconData icon;
  final String route;
}
