import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/widgets/common_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SectionHeader(
            title: 'Guest mode',
            subtitle: 'Authentication is a supporting I1 function',
          ),
          ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Continue as guest'),
            subtitle: Text('Search and identify work without an account'),
          ),
          ListTile(
            leading: Icon(Icons.location_on_outlined),
            title: Text('Default location'),
            subtitle: Text('Manual / GPS fallback — Kuala Lumpur'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(AppConstants.appName),
            subtitle: Text(AppConstants.tagline),
          ),
          ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('Data sources'),
            subtitle: Text('WWF SOS · OpenDOSM · Fish-Vista · OBIS'),
          ),
        ],
      ),
    );
  }
}
