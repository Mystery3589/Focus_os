import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/widgets/cyber_card.dart';

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
          onPressed: () => context.pop(),
        ),
        title: const Text('Instructions', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: CyberCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('How to use Focus GG', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text(
                '• Missions (Quests): Create missions and track progress.\n'
                '• Focus: Start a mission focus session. Only one mission can be active at a time.\n'
                '• Pause/Resume: You can pause a mission and continue later.\n'
                '• Abandon/Rejoin: Abandoned missions can be rejoined (when no other mission is open).\n'
                '• Custom sessions: Use Custom Session when you want to focus without a mission. XP is earned at 1 XP/min.\n'
                '• Analytics: Review your recent focus sessions and XP trends.\n',
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
    );
  }
}
