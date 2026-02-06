import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Text('Instructions', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: const [
          AiInboxBellAction(),
        ],
      ),
      body: PageEntrance(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CyberCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('How to use Disciplo', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text(
                  '• Missions (Quests): Create missions and track progress.\n'
                  '• Focus: Start a mission focus session. Only one mission can be active at a time.\n'
                  '• Pause/Resume: You can pause a mission and continue later.\n'
                  '• Abandon/Rejoin: Abandoned missions can be rejoined (when no other mission is open).\n'
                  '• Custom sessions: Use Custom Session when you want to focus without a mission. XP is earned at 1 XP/min.\n'
                  '• Analytics: Review your recent focus sessions and XP trends.\n\n'
                  'Progression:\n'
                  '• XP needed to level up increases after every level.\n'
                  '• On each level up, the AI allocates 2–3 stat points automatically based on what you did that level.\n'
                  '• Every 5 levels, you earn +1 stat point you can allocate manually.\n',
                  style: TextStyle(color: AppTheme.textPrimary, height: 1.5),
                ),
                SizedBox(height: 8),
                Text(
                  'Tip: If you feel stuck, make missions smaller and time-box them with Pomodoro.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
