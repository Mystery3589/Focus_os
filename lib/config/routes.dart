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
import '../features/calendar/calendar_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/habits/habit_analytics_screen.dart';
import '../features/ai_inbox/ai_inbox_screen.dart';
import '../features/stats/stat_allocation_screen.dart';
import '../shared/widgets/app_shell.dart';

CustomTransitionPage<void> _fadeSlidePage(GoRouterState state, Widget child) {
  final tween = Tween<Offset>(
    begin: const Offset(0.06, 0.0),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(tween),
          child: child,
        ),
      );
    },
  );
}

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
          pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/quests',
          pageBuilder: (context, state) => _fadeSlidePage(state, const QuestsScreen()),
        ),
        GoRoute(
          path: '/equipment',
          pageBuilder: (context, state) => _fadeSlidePage(state, const EquipmentScreen()),
        ),
        GoRoute(
          path: '/inventory',
          pageBuilder: (context, state) => _fadeSlidePage(state, const InventoryScreen()),
        ),
        GoRoute(
          path: '/focus',
          pageBuilder: (context, state) {
            final missionId = state.uri.queryParameters['missionId'];
            final heading = state.uri.queryParameters['heading'];
            final autoStart = state.uri.queryParameters['autostart'];
            final extraId = state.extra as String?;
            return _fadeSlidePage(
              state,
              FocusScreen(
              initialMissionId: missionId ?? extraId,
              initialCustomHeading: heading,
              autoStartCustom: autoStart == '1' || autoStart == 'true',
              ),
            );
          },
        ),
        GoRoute(
          path: '/stats',
          pageBuilder: (context, state) => _fadeSlidePage(state, const AnalyticsScreen()),
        ),
        GoRoute(
          path: '/calendar',
          pageBuilder: (context, state) => _fadeSlidePage(state, const CalendarScreen()),
        ),
        GoRoute(
          path: '/habits',
          pageBuilder: (context, state) => _fadeSlidePage(state, const HabitsScreen()),
        ),
        GoRoute(
          path: '/habits/analytics',
          pageBuilder: (context, state) => _fadeSlidePage(state, const HabitAnalyticsScreen()),
        ),
        GoRoute(
          path: '/combat',
          pageBuilder: (context, state) => _fadeSlidePage(state, const CombatScreen()),
        ),
        GoRoute(
          path: '/skills',
          pageBuilder: (context, state) => _fadeSlidePage(state, const SkillsScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _fadeSlidePage(state, const SettingsScreen()),
        ),
        GoRoute(
          path: '/settings/profile',
          pageBuilder: (context, state) => _fadeSlidePage(state, const ProfileScreen()),
        ),
        GoRoute(
          path: '/settings/instructions',
          pageBuilder: (context, state) => _fadeSlidePage(state, const InstructionsScreen()),
        ),
        GoRoute(
          path: '/settings/sync',
          pageBuilder: (context, state) => _fadeSlidePage(state, const CloudSyncScreen()),
        ),
        GoRoute(
          path: '/ai-inbox',
          pageBuilder: (context, state) => _fadeSlidePage(state, const AiInboxScreen()),
        ),
        GoRoute(
          path: '/allocate-stats',
          pageBuilder: (context, state) => _fadeSlidePage(state, const StatAllocationScreen()),
        ),
      ],
    ),
  ],
);
