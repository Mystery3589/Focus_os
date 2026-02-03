import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/models/quest.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  String _formatDuration(int totalMs) {
    final totalSeconds = (totalMs / 1000).floor();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return "$hh:$mm:$ss";
  }

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  int _minutesFromMs(int ms) => max(0, (ms / 60000).floor());

  ({int current, int best}) _computeStreak(Set<int> activeDayKeys) {
    if (activeDayKeys.isEmpty) return (current: 0, best: 0);

    int key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

    final now = DateTime.now();
    var cur = 0;
    var cursor = _dayStart(now);
    while (activeDayKeys.contains(key(cursor))) {
      cur += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final sorted = activeDayKeys.toList()..sort();
    var best = 1;
    var run = 1;
    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curKey = sorted[i];
      if (curKey == prev + 1) {
        run += 1;
        best = max(best, run);
      } else {
        run = 1;
      }
    }

    return (current: cur, best: best);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStats = ref.watch(userProvider);
    final history = userStats.focus.history;
    final questsById = <String, Quest>{
      for (final q in userStats.quests) q.id: q,
    };
    final skillsById = {
      for (final s in userStats.skills) s.id: s,
    };

    final totalSessions = history.length;
    final totalTimeMs = history.fold<int>(0, (sum, e) => sum + e.totalMs);
    final totalMinutes = _minutesFromMs(totalTimeMs);

    // Minutes per day (used for streaks and rollups)
    int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
    final minutesByDay = <int, int>{};
    for (final log in history) {
      final ended = DateTime.fromMillisecondsSinceEpoch(log.endedAt);
      final k = dayKey(_dayStart(ended));
      minutesByDay[k] = (minutesByDay[k] ?? 0) + _minutesFromMs(log.totalMs);
    }
    final activeDays = minutesByDay.entries.where((e) => e.value > 0).map((e) => e.key).toSet();
    final streak = _computeStreak(activeDays);

    final nowDay = _dayStart(DateTime.now());
    int minutesLastNDays(int n) {
      var total = 0;
      for (int i = 0; i < n; i++) {
        final d = nowDay.subtract(Duration(days: i));
        total += minutesByDay[dayKey(d)] ?? 0;
      }
      return total;
    }

    final minutes7d = minutesLastNDays(7);
    final minutes30d = minutesLastNDays(30);

    // Breakdown by skill (minutes)
    final minutesBySkill = <String, int>{};
    for (final log in history) {
      final q = questsById[log.questId];
      String bucket;
      if (log.questId.startsWith('custom-') || (log.difficulty ?? '').toUpperCase() == 'CUSTOM') {
        bucket = 'Custom';
      } else if (q?.skillId != null && skillsById.containsKey(q!.skillId)) {
        bucket = skillsById[q.skillId]!.title;
      } else {
        bucket = 'Unassigned';
      }
      minutesBySkill[bucket] = (minutesBySkill[bucket] ?? 0) + _minutesFromMs(log.totalMs);
    }
    final topSkills = minutesBySkill.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topSkillLabel = topSkills.isEmpty ? '--' : topSkills.first.key;

    // --- Chart data ---
    final Map<String, int> xpByDifficulty = {};
    for (final log in history) {
      final d = (log.difficulty ?? 'Unknown').toUpperCase();
      xpByDifficulty[d] = (xpByDifficulty[d] ?? 0) + log.earnedExp;
    }
    final sortedXpByDifficulty = xpByDifficulty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalXp = sortedXpByDifficulty.fold<int>(0, (sum, e) => sum + e.value);

    const days = 14;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: days - 1));
    final dailyXp = List<int>.filled(days, 0);
    for (final log in history) {
      final d = DateTime.fromMillisecondsSinceEpoch(log.endedAt);
      final day = DateTime(d.year, d.month, d.day);
      final idx = day.difference(start).inDays;
      if (idx >= 0 && idx < days) {
        dailyXp[idx] += log.earnedExp;
      }
    }
    final maxDailyXp = dailyXp.isEmpty ? 0 : dailyXp.reduce(max);

    final Map<String, _MissionAnalytics> analytics = {};
    for (final log in history) {
      final id = log.questId;
      final existing = analytics[id];
      final entry = existing ?? _MissionAnalytics(id: id, title: log.questTitle ?? 'Mission');
      entry.totalMs += log.totalMs;
      entry.sessions += 1;
      if (log.expectedMinutes != null) {
        entry.expectedMinutes += log.expectedMinutes!;
      }
      if (log.deltaMinutes != null) {
        entry.deltaMinutes += log.deltaMinutes!;
      }
      entry.earnedXp += log.earnedExp;
      analytics[id] = entry;
    }

    final list = analytics.values.toList()
      ..sort((a, b) => b.totalMs.compareTo(a.totalMs));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'Analytics',
          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
        ),
      ),
      body: list.isEmpty
          ? const Center(
              child: Text(
                'No focus sessions yet.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CyberCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Overview',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _statChip('Sessions', '$totalSessions'),
                                _statChip('Total time', _formatDuration(totalTimeMs)),
                                _statChip('Minutes', '$totalMinutes'),
                                _statChip('7d minutes', '$minutes7d'),
                                _statChip('30d minutes', '$minutes30d'),
                                _statChip('Current streak', '${streak.current}d'),
                                _statChip('Best streak', '${streak.best}d'),
                                _statChip('Top skill', topSkillLabel),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      CyberCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'By skill (time)',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            if (topSkills.isEmpty)
                              const Text('No data yet.', style: TextStyle(color: AppTheme.textSecondary))
                            else
                              ...topSkills.take(6).map((e) {
                                final pct = topSkills.first.value <= 0 ? 0.0 : (e.value / topSkills.fold<int>(0, (s, x) => s + x.value));
                                final bar = pct.isNaN ? 0.0 : pct.clamp(0.0, 1.0);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              e.key,
                                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text('${e.value}m', style: const TextStyle(color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: bar,
                                          minHeight: 8,
                                          backgroundColor: AppTheme.background,
                                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      CyberCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Visuals',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 900;

                                final pie = _buildXpPie(totalXp, sortedXpByDifficulty);
                                final line = _buildDailyXpLine(days, start, dailyXp, maxDailyXp);

                                if (!wide) {
                                  return Column(
                                    children: [
                                      pie,
                                      const SizedBox(height: 16),
                                      line,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: pie),
                                    const SizedBox(width: 16),
                                    Expanded(child: line),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }

                final entry = list[index - 1];
                final expected = entry.expectedMinutes;
                final delta = entry.deltaMinutes;
                final deltaLabel = delta == 0
                    ? 'On time'
                    : delta > 0
                        ? '${delta}m faster'
                        : '${delta.abs()}m over';
                final deltaColor = delta == 0
                    ? AppTheme.textSecondary
                    : delta > 0
                        ? Colors.greenAccent
                        : Colors.redAccent;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: CyberCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statChip('Sessions', '${entry.sessions}'),
                            _statChip('Time', _formatDuration(entry.totalMs)),
                            _statChip('XP', '${entry.earnedXp}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              expected == 0 ? 'Expected: --' : 'Expected: ${expected}m',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            Text(
                              deltaLabel,
                              style: TextStyle(color: deltaColor, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildXpPie(int totalXp, List<MapEntry<String, int>> data) {
    if (totalXp <= 0 || data.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: Text('No XP data yet.', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    Color colorFor(String d) {
      switch (d) {
        case 'CUSTOM':
          return Colors.pinkAccent;
        case 'S':
          return Colors.redAccent;
        case 'A':
          return Colors.orangeAccent;
        case 'B':
          return Colors.amberAccent;
        case 'C':
          return Colors.greenAccent;
        case 'D':
          return Colors.lightBlueAccent;
        default:
          return Colors.purpleAccent;
      }
    }

    final sections = <PieChartSectionData>[];
    for (final e in data) {
      final pct = (e.value / totalXp) * 100;
      // Hide tiny labels for readability
      final showTitle = pct >= 7;
      sections.add(
        PieChartSectionData(
          value: e.value.toDouble(),
          color: colorFor(e.key),
          title: showTitle ? '${e.key}\n${pct.toStringAsFixed(0)}%' : '',
          radius: 68,
          titleStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('XP by difficulty', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...data.take(6).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colorFor(e.key),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ),
                              Text(
                                '${e.value}',
                                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyXpLine(int days, DateTime start, List<int> dailyXp, int maxDailyXp) {
    final spots = <FlSpot>[];
    for (int i = 0; i < days; i++) {
      spots.add(FlSpot(i.toDouble(), dailyXp[i].toDouble()));
    }

    return SizedBox(
      height: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily XP (last 14 days)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (days - 1).toDouble(),
                minY: 0,
                maxY: max(1, maxDailyXp).toDouble(),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: true, border: Border.all(color: AppTheme.borderColor)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: max(1, (maxDailyXp / 3).floor()).toDouble(),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 3,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days) return const SizedBox.shrink();
                        final d = start.add(Duration(days: idx));
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            '${d.month}/${d.day}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MissionAnalytics {
  final String id;
  final String title;
  int totalMs = 0;
  int sessions = 0;
  int expectedMinutes = 0;
  int deltaMinutes = 0;
  int earnedXp = 0;

  _MissionAnalytics({required this.id, required this.title});
}
