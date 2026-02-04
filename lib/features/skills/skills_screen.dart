import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/models/quest.dart';
import '../../shared/models/skill.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/mission_dialog.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/local_backup_service.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStats = ref.watch(userProvider);
    final focusState = userStats.focus;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Skills', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: [
          const AiInboxBellAction(),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showAddSkillDialog(context, ref),
          ),
        ],
      ),
      body: PageEntrance(
        child: userStats.skills.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: CyberCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        const Icon(LucideIcons.target, color: AppTheme.primary, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'No long-term skills yet',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Add a skill goal, then attach missions to it to track progress over time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () => _showAddSkillDialog(context, ref),
                            icon: const Icon(LucideIcons.plus, size: 18),
                            label: const Text('Add Skill'),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: userStats.skills.length,
                itemBuilder: (context, index) {
                final skill = userStats.skills[index];
                final linkedQuests = userStats.quests
                    .where((q) => q.skillId == skill.id)
                    .toList()
                  ..sort((a, b) {
                    // Uncompleted first, then latest.
                    if (a.completed != b.completed) return a.completed ? 1 : -1;
                    final tA = a.completed ? (a.completedAt ?? 0) : (a.createdAt ?? 0);
                    final tB = b.completed ? (b.completedAt ?? 0) : (b.createdAt ?? 0);
                    return tB.compareTo(tA);
                  });

                final completedCount = linkedQuests.where((m) => m.completed).length;
                final totalCount = linkedQuests.length;
                final progress = totalCount == 0 ? 0 : (completedCount / totalCount * 100).floor();
                final progressValue = totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0);

                final skillXpToNext = skill.expToNextLevel;
                final skillXpProgress = skillXpToNext <= 0 ? 0.0 : (skill.exp / skillXpToNext).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: CyberCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.target, size: 18, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          skill.title,
                                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((skill.description ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      skill.description!,
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppTheme.borderColor),
                                  ),
                                  child: Text(
                                    'LV ${skill.level}',
                                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppTheme.borderColor),
                                  ),
                                  child: Text(
                                    '$progress%',
                                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(LucideIcons.edit, size: 16, color: AppTheme.textSecondary),
                              onPressed: () => _showEditSkillDialog(context, ref, skill),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.trash2, size: 16, color: AppTheme.textSecondary),
                              onPressed: () => _showDeleteSkillDialog(context, ref, skill.id),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progressValue,
                                  minHeight: 8,
                                  backgroundColor: AppTheme.background,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$completedCount/$totalCount',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: skillXpProgress,
                                  minHeight: 8,
                                  backgroundColor: AppTheme.background,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary.withOpacity(0.55)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${skill.exp}/$skillXpToNext XP',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (linkedQuests.isEmpty)
                          const Text(
                            'No missions yet. Add milestones to track progress.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          )
                        else
                          ...linkedQuests.map(
                            (quest) {
                              String? status;
                              try {
                                status = focusState.openSessions
                                    .firstWhere((s) => s.questId == quest.id && s.status != 'abandoned')
                                    .status;
                              } catch (_) {}
                              final isRunning = status == 'running';
                              final isPaused = status == 'paused';

                              String? label;
                              Color? color;
                              if (isRunning) {
                                label = 'RUNNING';
                                color = Colors.greenAccent;
                              } else if (isPaused) {
                                label = 'PAUSED';
                                color = Colors.amberAccent;
                              }

                              return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: quest.completed,
                                    onChanged: quest.completed
                                        ? null
                                        : (isRunning || isPaused)
                                            ? null
                                            : (_) => ref.read(userProvider.notifier).completeQuest(quest.id),
                                    activeColor: AppTheme.primary,
                                    checkColor: Colors.black,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          quest.title,
                                          style: TextStyle(
                                            color: quest.completed ? AppTheme.textSecondary : AppTheme.textPrimary,
                                            decoration: quest.completed ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        if (label != null) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: color!.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(color: color.withOpacity(0.6)),
                                            ),
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.edit, size: 16, color: AppTheme.textSecondary),
                                    onPressed: () => showMissionDialog(context, ref, quest: quest),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.trash2, size: 16, color: AppTheme.textSecondary),
                                    onPressed: () => _showDeleteQuestDialog(context, ref, quest.id),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            );
                            },
                          ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => showMissionDialog(context, ref, presetSkillId: skill.id),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Add Mission'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(color: AppTheme.borderColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                },
              ),
      ),
    );
  }

  void _showAddSkillDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Add Skill Goal', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Skill Title',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              ref.read(userProvider.notifier).addSkillGoal(
                    titleController.text.trim(),
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  );
              Navigator.pop(context);
            },
            child: const Text('Add Skill'),
          ),
        ],
      ),
    );
  }

  void _showEditSkillDialog(BuildContext context, WidgetRef ref, SkillGoal skill) {
    final titleController = TextEditingController(text: skill.title);
    final descController = TextEditingController(text: skill.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Edit Skill', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Skill Title',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              ref.read(userProvider.notifier).updateSkillGoal(
                    skill.id,
                    title: titleController.text.trim(),
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSkillDialog(BuildContext context, WidgetRef ref, String skillId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Delete Skill', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Delete this skill goal? Missions linked to it will be unassigned (not deleted).',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              final localBefore = ref.read(userProvider.notifier).exportUserStatsJson(pretty: false);
              unawaited(LocalBackupService.instance.saveRestorePoint(
                json: localBefore,
                reason: 'delete_skill_goal',
              ));

              ref.read(userProvider.notifier).deleteSkillGoal(skillId);
              Navigator.pop(dialogContext);

              final messenger = ScaffoldMessenger.of(context);
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('Skill deleted.'),
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      unawaited(ref.read(userProvider.notifier).importUserStatsJson(localBefore));
                    },
                  ),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteQuestDialog(BuildContext context, WidgetRef ref, String questId) {
    final stats = ref.read(userProvider);
    Quest? quest;
    int? questIndex;
    try {
      questIndex = stats.quests.indexWhere((q) => q.id == questId);
      if (questIndex != -1) quest = stats.quests[questIndex];
    } catch (_) {}

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Delete Mission', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Delete this mission? You can Undo right after deletion.',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(userProvider.notifier).deleteQuest(questId);
              Navigator.pop(dialogContext);

              if (quest != null) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Deleted “${quest.title}”.'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        ref.read(userProvider.notifier).restoreQuest(quest!, index: questIndex);
                      },
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
