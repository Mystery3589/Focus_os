import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../models/quest.dart';
import '../providers/user_provider.dart';
import '../services/local_backup_service.dart';

int _baseXpPerMinute(String difficulty) {
  switch (difficulty.toUpperCase()) {
    case 'S':
      return 12;
    case 'A':
      return 10;
    case 'B':
      return 8;
    case 'C':
      return 6;
    case 'D':
      return 4;
    default:
      return 5;
  }
}

int _estimateXp(String difficulty, int expectedMinutes) {
  final safeMinutes = expectedMinutes <= 0 ? 1 : expectedMinutes;
  return _baseXpPerMinute(difficulty) * safeMinutes;
}

/// Unified create/edit mission dialog used by both Missions and Skills.
///
/// - If [quest] is provided, edits it.
/// - If [presetSkillId] is provided and [quest] is null, the dialog preselects that skill.
Future<void> showMissionDialog(
  BuildContext context,
  WidgetRef ref, {
  Quest? quest,
  String? presetSkillId,
}) async {
  final rootContext = context;
  final skills = ref.read(userProvider).skills;
  final isEdit = quest != null;

  final titleController = TextEditingController(text: quest?.title ?? '');
  final descController = TextEditingController(text: quest?.description ?? '');

  String difficulty = quest?.difficulty ?? 'B';
  String priority = quest?.priority ?? 'B';
  String frequency = quest?.frequency ?? 'none';
  String? selectedSkillId = quest?.skillId ?? presetSkillId;

  bool useExpectedLength = quest?.expectedMinutes != null || !isEdit;
  int expectedValue = (quest?.expectedMinutes ?? 60);
  String expectedUnit = 'minutes';
  if (expectedValue >= 60 && expectedValue % 60 == 0) {
    expectedUnit = 'hours';
    expectedValue = expectedValue ~/ 60;
  }
  final expectedController = TextEditingController(text: expectedValue.toString());

  DateTime? startDate = quest?.startDateMs != null ? DateTime.fromMillisecondsSinceEpoch(quest!.startDateMs!) : null;
  DateTime? dueDate = quest?.dueDateMs != null ? DateTime.fromMillisecondsSinceEpoch(quest!.dueDateMs!) : null;

  final scrollController = ScrollController();
  bool showValidationErrors = false;

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final media = MediaQuery.of(context);
        // When the keyboard is open, the usable height shrinks. If we keep a fixed
        // dialog height, the internal Column will overflow (commonly on Android).
        final availableH = (media.size.height - media.viewInsets.bottom).clamp(0.0, double.infinity);
        final dialogMaxH = (availableH * 0.88).clamp(420.0, 820.0).toDouble();

        final titleTrim = titleController.text.trim();

        final parsedExpected = int.tryParse(expectedController.text.trim()) ?? 0;
        final expectedMinutes = expectedUnit == 'hours' ? (parsedExpected * 60) : parsedExpected;

        String? titleError;
        String? expectedError;
        String? dateError;

        if (titleTrim.isEmpty) {
          titleError = 'Title is required';
        }

        if (useExpectedLength) {
          if (parsedExpected <= 0) {
            expectedError = 'Enter a number greater than 0';
          } else if (expectedMinutes > 24 * 60) {
            expectedError = 'Keep expected length under 24 hours';
          }
        }

        if (startDate != null && dueDate != null) {
          final startDay = DateTime(startDate!.year, startDate!.month, startDate!.day);
          final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
          if (dueDay.isBefore(startDay)) {
            dateError = 'Due date must be on or after start date';
          }
        }

        final isValid = titleError == null && expectedError == null && dateError == null;
        final previewXp = (!useExpectedLength || expectedMinutes <= 0) ? 0 : _estimateXp(difficulty, expectedMinutes);

        Widget sectionLabel(String text) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          );
        }

        InputDecoration fieldDecoration(String label, {String? hint, String? errorText}) {
          return InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: errorText,
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary),
            ),
          );
        }

        Widget dateRow({required String label, required DateTime? value, required VoidCallback onPick}) {
          final text = value == null
              ? 'Not set'
              : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
          return Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onPick,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.borderColor),
                ),
                child: Text(label),
              ),
            ],
          );
        }

        return AnimatedPadding(
          padding: media.viewInsets + const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 560, maxHeight: dialogMaxH),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? 'Edit Mission' : 'Create New Mission',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add a new mission to track your real-life progress',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 18, color: AppTheme.textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderColor),

                    // Body
                    Flexible(
                      child: Scrollbar(
                        controller: scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              sectionLabel('Mission Title'),
                              TextField(
                                controller: titleController,
                                style: const TextStyle(color: AppTheme.textPrimary),
                                onChanged: (_) {
                                  if (showValidationErrors) setState(() {});
                                },
                                decoration: fieldDecoration(
                                  'Title',
                                  errorText: showValidationErrors ? titleError : null,
                                ),
                              ),
                              const SizedBox(height: 14),

                              sectionLabel('Description'),
                              TextField(
                                controller: descController,
                                style: const TextStyle(color: AppTheme.textPrimary),
                                maxLines: 4,
                                decoration: fieldDecoration('Description'),
                              ),

                              const SizedBox(height: 16),

                              // Difficulty + Priority
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        sectionLabel('Difficulty'),
                                        DropdownButtonFormField<String>(
                                          value: difficulty,
                                          dropdownColor: AppTheme.background,
                                          decoration: fieldDecoration('Difficulty'),
                                          style: const TextStyle(color: AppTheme.textPrimary),
                                          items: const [
                                            DropdownMenuItem(value: 'S', child: Text('S (Highest)')),
                                            DropdownMenuItem(value: 'A', child: Text('A')),
                                            DropdownMenuItem(value: 'B', child: Text('B')),
                                            DropdownMenuItem(value: 'C', child: Text('C')),
                                            DropdownMenuItem(value: 'D', child: Text('D (Lowest)')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setState(() => difficulty = val);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        sectionLabel('Priority'),
                                        DropdownButtonFormField<String>(
                                          value: priority,
                                          dropdownColor: AppTheme.background,
                                          decoration: fieldDecoration('Priority'),
                                          style: const TextStyle(color: AppTheme.textPrimary),
                                          items: const [
                                            DropdownMenuItem(value: 'S', child: Text('S (Highest)')),
                                            DropdownMenuItem(value: 'A', child: Text('A')),
                                            DropdownMenuItem(value: 'B', child: Text('B')),
                                            DropdownMenuItem(value: 'C', child: Text('C')),
                                            DropdownMenuItem(value: 'D', child: Text('D (Lowest)')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setState(() => priority = val);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              sectionLabel('Frequency'),
                              DropdownButtonFormField<String>(
                                value: frequency,
                                dropdownColor: AppTheme.background,
                                decoration: fieldDecoration('Frequency'),
                                style: const TextStyle(color: AppTheme.textPrimary),
                                items: const [
                                  DropdownMenuItem(value: 'none', child: Text('One-time')),
                                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => frequency = val);
                                },
                              ),

                              const SizedBox(height: 14),

                              sectionLabel('Expected Length (optional)'),
                              Row(
                                children: [
                                  Expanded(
                                    child: CheckboxListTile(
                                      value: useExpectedLength,
                                      onChanged: (v) {
                                        setState(() {
                                          useExpectedLength = v ?? false;
                                          if (!useExpectedLength) {
                                            // Keep the input around (in case the user toggles back on),
                                            // but clear errors immediately.
                                            showValidationErrors = false;
                                          } else {
                                            if ((int.tryParse(expectedController.text.trim()) ?? 0) <= 0) {
                                              expectedController.text = expectedValue <= 0 ? '60' : expectedValue.toString();
                                            }
                                          }
                                        });
                                      },
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'Use expected length',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      ),
                                      controlAffinity: ListTileControlAffinity.leading,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: expectedController,
                                      enabled: useExpectedLength,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: AppTheme.textPrimary),
                                      onChanged: (val) {
                                        setState(() {
                                          expectedValue = int.tryParse(val) ?? 0;
                                        });
                                      },
                                      decoration: fieldDecoration(
                                        'Length',
                                        hint: '60',
                                        errorText: showValidationErrors ? expectedError : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 160,
                                    child: DropdownButtonFormField<String>(
                                      value: expectedUnit,
                                      dropdownColor: AppTheme.background,
                                      decoration: fieldDecoration('Unit'),
                                      style: const TextStyle(color: AppTheme.textPrimary),
                                      items: const [
                                        DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                                        DropdownMenuItem(value: 'hours', child: Text('Hours')),
                                      ],
                                      onChanged: useExpectedLength
                                          ? (val) {
                                              if (val != null) setState(() => expectedUnit = val);
                                            }
                                          : null,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              sectionLabel('Assign to Skill (optional)'),
                              DropdownButtonFormField<String?>(
                                value: selectedSkillId,
                                dropdownColor: AppTheme.background,
                                decoration: fieldDecoration('Skill'),
                                style: const TextStyle(color: AppTheme.textPrimary),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('None')),
                                  ...skills.map(
                                    (s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.title)),
                                  ),
                                ],
                                onChanged: (val) {
                                  setState(() => selectedSkillId = val);
                                },
                              ),

                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        sectionLabel('Start Date'),
                                        dateRow(
                                          label: 'Pick',
                                          value: startDate,
                                          onPick: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: startDate ?? DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) setState(() => startDate = picked);
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () => setState(() => startDate = DateTime.now()),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.textSecondary,
                                                side: const BorderSide(color: AppTheme.borderColor),
                                              ),
                                              child: const Text('Today'),
                                            ),
                                            OutlinedButton(
                                              onPressed: () => setState(() => startDate = DateTime.now().add(const Duration(days: 1))),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.textSecondary,
                                                side: const BorderSide(color: AppTheme.borderColor),
                                              ),
                                              child: const Text('Tomorrow'),
                                            ),
                                            TextButton(
                                              onPressed: () => setState(() => startDate = null),
                                              child: const Text('Clear', style: TextStyle(color: AppTheme.textSecondary)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        sectionLabel('Due Date'),
                                        dateRow(
                                          label: 'Pick',
                                          value: dueDate,
                                          onPick: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: dueDate ?? DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) setState(() => dueDate = picked);
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () => setState(() => dueDate = DateTime.now()),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.textSecondary,
                                                side: const BorderSide(color: AppTheme.borderColor),
                                              ),
                                              child: const Text('Today'),
                                            ),
                                            OutlinedButton(
                                              onPressed: () => setState(() => dueDate = DateTime.now().add(const Duration(days: 1))),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.textSecondary,
                                                side: const BorderSide(color: AppTheme.borderColor),
                                              ),
                                              child: const Text('Tomorrow'),
                                            ),
                                            OutlinedButton(
                                              onPressed: () => setState(() => dueDate = DateTime.now().add(const Duration(days: 7))),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.textSecondary,
                                                side: const BorderSide(color: AppTheme.borderColor),
                                              ),
                                              child: const Text('+7d'),
                                            ),
                                            TextButton(
                                              onPressed: () => setState(() => dueDate = null),
                                              child: const Text('Clear', style: TextStyle(color: AppTheme.textSecondary)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              if (showValidationErrors && dateError != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  dateError,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                ),
                              ],

                              const SizedBox(height: 12),
                              Text(
                                useExpectedLength
                                    ? 'XP is estimated from difficulty and expected time: $previewXp XP'
                                    : 'XP is calculated from difficulty and actual time (no expected length).',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Divider(height: 1, color: AppTheme.borderColor),

                    // Footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 180,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () {
                                if (!isValid) {
                                  setState(() => showValidationErrors = true);
                                  return;
                                }

                                final int? expectedMinutesSave = useExpectedLength
                                    ? (expectedUnit == 'hours' ? expectedValue * 60 : expectedValue)
                                    : null;
                                final expReward = expectedMinutesSave == null ? 0 : _estimateXp(difficulty, expectedMinutesSave);
                                final rewardText = expectedMinutesSave == null ? 'XP based on time' : '$expReward XP';

                                if (isEdit) {
                                  final wasLinkedToSkill = quest.skillId != null;
                                  final isNowLinkedToSkill = selectedSkillId != null;
                                  final didUnlinkFromSkill = wasLinkedToSkill && !isNowLinkedToSkill;
                                  final localBefore = didUnlinkFromSkill
                                      ? ref.read(userProvider.notifier).exportUserStatsJson(pretty: false)
                                      : null;

                                  ref.read(userProvider.notifier).updateQuest(
                                        quest.copyWith(
                                          title: titleController.text.trim(),
                                          description: descController.text.trim(),
                                          difficulty: difficulty,
                                          reward: rewardText,
                                          expReward: expReward,
                                          priority: priority,
                                          skillId: selectedSkillId,
                                          startDateMs: startDate?.millisecondsSinceEpoch,
                                          dueDateMs: dueDate?.millisecondsSinceEpoch,
                                          expectedMinutes: expectedMinutesSave,
                                          frequency: frequency,
                                        ),
                                      );

                                  if (didUnlinkFromSkill && localBefore != null) {
                                    unawaited(LocalBackupService.instance.saveRestorePoint(
                                      json: localBefore,
                                      reason: 'unlink_mission_from_skill',
                                    ));

                                    // Show after the dialog closes so it doesn't sit behind the modal barrier.
                                    Future.delayed(Duration.zero, () {
                                      final messenger = ScaffoldMessenger.of(rootContext);
                                      messenger.hideCurrentSnackBar();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: const Text('Mission unlinked from skill.'),
                                          duration: const Duration(seconds: 8),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            onPressed: () {
                                              unawaited(ref.read(userProvider.notifier).importUserStatsJson(localBefore));
                                            },
                                          ),
                                        ),
                                      );
                                    });
                                  }
                                } else {
                                  ref.read(userProvider.notifier).addQuest(
                                        Quest(
                                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                                          title: titleController.text.trim(),
                                          description: descController.text.trim(),
                                          reward: rewardText,
                                          difficulty: difficulty,
                                          priority: priority,
                                          progress: 0,
                                          completed: false,
                                          active: false,
                                          createdAt: DateTime.now().millisecondsSinceEpoch,
                                          expReward: expReward,
                                          statPointsReward: 0,
                                          expiry: '',
                                          skillId: selectedSkillId,
                                          startDateMs: startDate?.millisecondsSinceEpoch,
                                          dueDateMs: dueDate?.millisecondsSinceEpoch,
                                          expectedMinutes: expectedMinutesSave,
                                          frequency: frequency,
                                          lastPenaltyDate: null,
                                        ),
                                      );
                                }

                                Navigator.pop(context);
                              },
                              child: Text(isEdit ? 'Save Mission' : 'Create Mission'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  // showDialog's Future completes when Navigator.pop is called, but the route
  // may still be animating out. Delay disposal to avoid controllers being
  // referenced during the dismiss animation.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  scrollController.dispose();
  titleController.dispose();
  descController.dispose();
  expectedController.dispose();
}
