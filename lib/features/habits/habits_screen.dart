import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/models/habit.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/page_container.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  DateTime _selectedDay = DateTime.now();
  bool _showArchived = false;

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  String _fmtDay(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<void> _addHabitDialog() async {
    final controller = TextEditingController();

    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('New habit', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Meditate',
              hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.borderColor.withOpacity(0.35)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.9)),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    final t = (title ?? '').trim();
    if (t.isEmpty) return;

    ref.read(userProvider.notifier).addHabit(t);
  }

  int _currentStreak(Habit h) {
    final completed = h.completedDays.toSet();
    var streak = 0;
    var d = _dayStart(DateTime.now());
    while (completed.contains(_dayKey(d))) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _completedLastNDays(Habit h, int n) {
    final completed = h.completedDays.toSet();
    var count = 0;
    var d = _dayStart(DateTime.now());
    for (var i = 0; i < n; i++) {
      if (completed.contains(_dayKey(d))) count++;
      d = d.subtract(const Duration(days: 1));
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(userProvider);

    final selectedDay = _dayStart(_selectedDay);
    final selectedKey = _dayKey(selectedDay);

    final habits = stats.habits.where((h) => _showArchived ? true : !h.archived).toList();
    habits.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Habits', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: [
          const AiInboxBellAction(),
          IconButton(
            tooltip: 'Analytics',
            onPressed: () => context.go('/habits/analytics'),
            icon: const Icon(LucideIcons.lineChart),
          ),
          IconButton(
            tooltip: 'Add habit',
            onPressed: _addHabitDialog,
            icon: const Icon(LucideIcons.plusCircle),
          ),
        ],
      ),
      body: PageEntrance(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              CyberCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.calendar, color: AppTheme.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _fmtDay(selectedDay),
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Previous day',
                          onPressed: () => setState(() => _selectedDay = selectedDay.subtract(const Duration(days: 1))),
                          icon: const Icon(LucideIcons.chevronLeft, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Next day',
                          onPressed: () => setState(() => _selectedDay = selectedDay.add(const Duration(days: 1))),
                          icon: const Icon(LucideIcons.chevronRight, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Switch(
                          value: _showArchived,
                          onChanged: (v) => setState(() => _showArchived = v),
                          activeColor: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Show archived', style: TextStyle(color: AppTheme.textSecondary)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() => _selectedDay = DateTime.now()),
                          icon: const Icon(LucideIcons.rotateCcw, size: 16, color: AppTheme.textSecondary),
                          label: const Text('Today', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (habits.isEmpty)
                CyberCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'No habits yet.',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add one and start building your streak — your future self will high-five you.',
                        style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.95)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _addHabitDialog,
                        icon: const Icon(LucideIcons.plusCircle, size: 18),
                        label: const Text('Add habit'),
                      ),
                    ],
                  ),
                )
              else
                ...habits.map((h) {
                  final isDone = h.completedDays.contains(selectedKey);
                  final streak = _currentStreak(h);
                  final last7 = _completedLastNDays(h, 7);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CyberCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: h.archived
                                ? null
                                : () => ref.read(userProvider.notifier).toggleHabitCompletion(h.id, day: selectedDay),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone ? AppTheme.primary : Colors.transparent,
                                border: Border.all(
                                  color: isDone ? AppTheme.primary : AppTheme.borderColor.withOpacity(0.45),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                isDone ? LucideIcons.check : LucideIcons.circle,
                                size: 18,
                                color: isDone ? Colors.black : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        h.title,
                                        style: TextStyle(
                                          color: h.archived ? AppTheme.textSecondary : AppTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (h.archived)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.textSecondary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: AppTheme.borderColor.withOpacity(0.25)),
                                        ),
                                        child: const Text('Archived', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Streak: $streak  •  Last 7 days: $last7/7',
                                  style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.95), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            color: AppTheme.cardBg,
                            icon: const Icon(LucideIcons.moreVertical, color: AppTheme.textSecondary, size: 18),
                            onSelected: (v) {
                              final notifier = ref.read(userProvider.notifier);
                              if (v == 'archive') notifier.archiveHabit(h.id, archived: true);
                              if (v == 'unarchive') notifier.archiveHabit(h.id, archived: false);
                              if (v == 'delete') notifier.deleteHabit(h.id);
                            },
                            itemBuilder: (context) {
                              return [
                                if (!h.archived)
                                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
                                if (h.archived)
                                  const PopupMenuItem(value: 'unarchive', child: Text('Unarchive')),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ];
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
