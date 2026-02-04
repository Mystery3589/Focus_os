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

class HabitAnalyticsScreen extends ConsumerWidget {
  const HabitAnalyticsScreen({super.key});

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  int _currentStreak(Habit h) {
    final set = h.completedDays.toSet();
    var streak = 0;
    var d = _dayStart(DateTime.now());
    while (set.contains(_dayKey(d))) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _bestStreak(Habit h) {
    final days = List<int>.from(h.completedDays)..sort();
    if (days.isEmpty) return 0;

    int best = 1;
    int cur = 1;

    DateTime fromKey(int key) {
      final y = key ~/ 10000;
      final m = (key % 10000) ~/ 100;
      final d = key % 100;
      return DateTime(y, m, d);
    }

    for (var i = 1; i < days.length; i++) {
      final prev = fromKey(days[i - 1]);
      final now = fromKey(days[i]);
      final diff = _dayStart(now).difference(_dayStart(prev)).inDays;
      if (diff == 1) {
        cur++;
        if (cur > best) best = cur;
      } else if (diff == 0) {
        // duplicate day key (shouldn't happen, but be resilient)
        continue;
      } else {
        cur = 1;
      }
    }

    return best;
  }

  int _completedLastNDays(Habit h, int n) {
    final set = h.completedDays.toSet();
    var count = 0;
    var d = _dayStart(DateTime.now());
    for (var i = 0; i < n; i++) {
      if (set.contains(_dayKey(d))) count++;
      d = d.subtract(const Duration(days: 1));
    }
    return count;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userProvider);

    final habits = List<Habit>.from(stats.habits);
    habits.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final activeCount = habits.where((h) => !h.archived).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/habits'),
        ),
        title: const Text('Habit analytics', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: const [
          AiInboxBellAction(),
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
                child: Row(
                  children: [
                    const Icon(LucideIcons.activity, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Habits: $activeCount active • ${habits.length - activeCount} archived',
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                      ),
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
                      const Text('No data yet.', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'Create a habit and come back after a few checkmarks. Science says it only takes… well… more than one day.',
                        style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.95)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/habits'),
                        icon: const Icon(LucideIcons.plusCircle, size: 18),
                        label: const Text('Add a habit'),
                      ),
                    ],
                  ),
                )
              else
                ...habits.map((h) {
                  final current = _currentStreak(h);
                  final best = _bestStreak(h);
                  final last7 = _completedLastNDays(h, 7);
                  final last30 = _completedLastNDays(h, 30);

                  final total = h.completedDays.length;
                  final created = DateTime.fromMillisecondsSinceEpoch(h.createdAtMs);
                  final daysSince = _dayStart(DateTime.now()).difference(_dayStart(created)).inDays + 1;
                  final completionRate = daysSince <= 0 ? 0.0 : (total / daysSince).clamp(0.0, 1.0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CyberCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  h.title,
                                  style: TextStyle(
                                    color: h.archived ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
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
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _MetricChip(label: 'Current streak', value: '$current'),
                              _MetricChip(label: 'Best streak', value: '$best'),
                              _MetricChip(label: 'Last 7 days', value: '$last7/7'),
                              _MetricChip(label: 'Last 30 days', value: '$last30/30'),
                              _MetricChip(label: 'Total', value: '$total'),
                              _MetricChip(label: 'Rate', value: '${(completionRate * 100).round()}%'),
                            ],
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

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.95), fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
