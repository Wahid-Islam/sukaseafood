import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_kit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const String headerAsset =
      'assets/images/explore/favourites_header.png';
  static const String avatarAsset = 'assets/images/auth/avatar_source.png';
  static const String shoreAsset = 'assets/images/auth/profile_shore.png';

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final String name = auth.displayName;
    final String email = auth.profile?.email ?? '';
    final String location = auth.forecastLocationName;

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: ContentWidth(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _ProfileHero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.set_meal_outlined,
                      iconBackground: const Color(0xFFD8F5F1),
                      iconColor: AppColors.tealDark,
                      title: 'Fish Avatar',
                      subtitle: 'Choose your avatar',
                      trailing: ClipOval(
                        child: Image.asset(
                          avatarAsset,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const CircleAvatar(
                            radius: 28,
                            backgroundColor: Color(0xFFD8F5F1),
                            child: Icon(
                              Icons.set_meal,
                              color: AppColors.tealDark,
                            ),
                          ),
                        ),
                      ),
                      onTap: () => _info(
                        context,
                        'Fish Avatar',
                        'This illustrated avatar is the profile picture for your account on this device.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProfileTile(
                      icon: Icons.person_outline,
                      title: 'Name',
                      subtitle: name,
                      onTap: () => _info(
                        context,
                        'Name',
                        'This is the name on your SukaSeafood account.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProfileTile(
                      icon: Icons.mail_outline,
                      title: 'Email',
                      subtitle: email.isEmpty ? '—' : email,
                      onTap: () => _info(
                        context,
                        'Email',
                        'This is the email you use to sign in.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProfileTile(
                      icon: Icons.place_outlined,
                      title: 'Forecast location',
                      subtitle: location,
                      onTap: () => _info(
                        context,
                        'Forecast location',
                        'Price outlooks use $location — the forecasting engine’s production scope. Other states are not modelled yet.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProfileTile(
                      icon: Icons.output,
                      iconBackground: const Color(0xFFFDE4E4),
                      iconColor: const Color(0xFFD46767),
                      background: const Color(0xFFFDECEC),
                      title: 'Sign out',
                      subtitle: 'Return to onboarding',
                      onTap: () async {
                        await context.read<AuthController>().signOut();
                        if (context.mounted) context.go('/onboarding');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(
              child: ShoreFooter(
                asset: shoreAsset,
                height: 148,
                fit: BoxFit.cover,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
    );
  }

  static void _info(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero();

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: SizedBox(
        height: top + 168,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              ProfileScreen.headerAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0.35, -0.72),
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.navy),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Color(0x99051A28),
                    Color(0x33051A28),
                    Color(0x00051A28),
                  ],
                  stops: <double>[0, 0.42, 0.82],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, top + 18, 18, 28),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      height: 1.05,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Your seafood journey,\nyour way.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.background = Colors.white,
    this.iconBackground = const Color(0xFFE8F2F8),
    this.iconColor = AppColors.navy,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color background;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconBackground,
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
