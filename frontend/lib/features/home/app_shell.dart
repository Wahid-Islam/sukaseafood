import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Bottom navigation for I1: Home / Explore / Favourites / Profile.
/// The scanner route still exists; it is not in this chrome.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int branch) {
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int branch = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: AppConstants.showScanner
          ? FloatingActionButton(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.navy,
              elevation: 6,
              shape: const CircleBorder(),
              onPressed: () => _go(2),
              child: const Icon(Icons.photo_camera_outlined, size: 28),
            )
          : null,
      floatingActionButtonLocation: AppConstants.showScanner
          ? FloatingActionButtonLocation.centerDocked
          : null,
      bottomNavigationBar: BottomAppBar(
        shape: AppConstants.showScanner
            ? const CircularNotchedRectangle()
            : null,
        color: Colors.white,
        elevation: 12,
        notchMargin: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  selected: branch == 0,
                  onTap: () => _go(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: 'Explore',
                  selected: branch == 1,
                  onTap: () => _go(1),
                ),
              ),
              if (AppConstants.showScanner) const SizedBox(width: 56),
              Expanded(
                child: _NavItem(
                  icon: Icons.favorite_border,
                  activeIcon: Icons.favorite,
                  label: 'Favourites',
                  selected: branch == 3,
                  onTap: () => _go(3),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  selected: branch == 4,
                  onTap: () => _go(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.tealDark : AppColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? activeIcon : icon, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
