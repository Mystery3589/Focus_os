import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/quests/quests_screen.dart';
import '../features/equipment/equipment_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/focus/focus_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/profile_screen.dart';
import '../features/settings/instructions_screen.dart';
import '../features/settings/cloud_sync_screen.dart';
import '../features/skills/skills_screen.dart';
import '../features/combat/combat_screen.dart';
import '../shared/widgets/app_shell.dart';

// Placeholder screens for other routes to prevent errors until implemented
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text("$title Screen")),
    );
  }
}

final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(
          currentRoute: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/quests',
          builder: (context, state) => const QuestsScreen(),
        ),
        GoRoute(
          path: '/equipment',
          builder: (context, state) => const EquipmentScreen(),
        ),
        GoRoute(
          path: '/inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
        GoRoute(
          path: '/focus',
          builder: (context, state) {
            final missionId = state.uri.queryParameters['missionId'];
            final heading = state.uri.queryParameters['heading'];
            final autoStart = state.uri.queryParameters['autostart'];
            final extraId = state.extra as String?;
            return FocusScreen(
              initialMissionId: missionId ?? extraId,
              initialCustomHeading: heading,
              autoStartCustom: autoStart == '1' || autoStart == 'true',
            );
          },
        ),
        GoRoute(
          path: '/stats',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/combat',
          builder: (context, state) => const CombatScreen(),
        ),
        GoRoute(
          path: '/skills',
          builder: (context, state) => const SkillsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/settings/instructions',
          builder: (context, state) => const InstructionsScreen(),
        ),
        GoRoute(
          path: '/settings/sync',
          builder: (context, state) => const CloudSyncScreen(),
        ),
      ],
    ),
  ],
);
