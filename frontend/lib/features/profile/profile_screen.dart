import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_kit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.foam,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        children: [
          DarkHeader(
            height: 180,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hai, Amir',
                    style: TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    'Prototype profile — PocketBase auth comes next.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Column(
              children: [
                SoftCard(
                  child: Column(
                    children: const [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.location_on_outlined),
                        title: Text('Default location'),
                        subtitle: Text('Kuala Lumpur'),
                      ),
                      Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.notifications_none),
                        title: Text('Notifications'),
                        subtitle: Text('Price drops & better choices'),
                      ),
                      Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.menu_book_outlined),
                        title: Text('Data sources'),
                        subtitle: Text('WWF SOS · OpenDOSM · Fish-Vista · OBIS'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SoftCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.cloud_outlined),
                    title: Text('Backend plan'),
                    subtitle: Text(
                      'PocketBase + HF Space + GitHub Actions for OpenDOSM refresh',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
