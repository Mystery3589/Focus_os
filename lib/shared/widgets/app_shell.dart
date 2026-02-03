import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final items = [
      _NavItem(icon: LucideIcons.home, label: 'Home', route: '/'),
      _NavItem(icon: LucideIcons.target, label: 'Missions', route: '/quests'),
      _NavItem(icon: LucideIcons.focus, label: 'Focus', route: '/focus'),
      _NavItem(icon: LucideIcons.lineChart, label: 'Analytics', route: '/stats'),
      _NavItem(icon: LucideIcons.package, label: 'Inventory', route: '/inventory'),
      _NavItem(icon: LucideIcons.shield, label: 'Equipment', route: '/equipment'),
      _NavItem(icon: LucideIcons.swords, label: 'Combat', route: '/combat'),
      _NavItem(icon: LucideIcons.bookOpen, label: 'Skills', route: '/skills'),
      _NavItem(icon: LucideIcons.settings, label: 'Settings', route: '/settings'),
    ];

    int currentIndex = items.indexWhere((item) => item.route == currentRoute);
    if (currentIndex == -1) currentIndex = 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor.withOpacity(0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 70),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: IntrinsicHeight(
              child: Row(
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isActive = index == currentIndex;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap: () => context.go(item.route),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? AppTheme.primary.withOpacity(0.1) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isActive
                              ? Border.all(color: AppTheme.primary.withOpacity(0.3))
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 9,
                                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  _NavItem({required this.icon, required this.label, required this.route});
}
