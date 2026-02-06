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
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';
import '../../shared/services/progress_report_service.dart';
import '../../shared/services/focus_insights_service.dart';
import '../../shared/services/mission_rollup_service.dart';
import '../../shared/widgets/cyber_progress.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  ReportPeriod _period = ReportPeriod.week;

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
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);
    final history = userStats.focus.history;
    final focusEvents = userStats.focusEvents;
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
      final isCustom = MissionRollupService.isCustomLog(log);
      final rolledUpId = isCustom
          ? log.questId
          : MissionRollupService.rolledUpMissionIdFor(questId: log.questId, questsById: questsById);

      final q = questsById[rolledUpId] ?? questsById[log.questId];
      String bucket;
      if (isCustom) {
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
      final isCustom = MissionRollupService.isCustomLog(log);
      final id = isCustom
          ? log.questId
          : MissionRollupService.rolledUpMissionIdFor(questId: log.questId, questsById: questsById);
      final existing = analytics[id];
      final entry = existing ?? _MissionAnalytics(
        id: id,
        title: MissionRollupService.rolledUpMissionTitleForLog(log: log, questsById: questsById),
      );
      entry.totalMs += log.totalMs;
      entry.sessions += 1;
      if (log.expectedMinutes != null) {
        entry.sessionsWithExpected += 1;
        entry.expectedMinutesSum += log.expectedMinutes!;
      } else {
        entry.sessionsWithoutExpected += 1;
      }
      if (log.deltaMinutes != null) {
        entry.deltaMinutesSum += log.deltaMinutes!;
      }
      entry.earnedXp += log.earnedExp;
      analytics[id] = entry;
    }

    final list = analytics.values.toList()
      ..sort((a, b) => b.totalMs.compareTo(a.totalMs));

    final report = ProgressReportService.generate(
      history: history,
      events: focusEvents,
      period: _period,
    );

    final coach = FocusInsightsService.generate(
      history: history,
      events: focusEvents,
    );

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
        actions: const [
          AiInboxBellAction(),
        ],
      ),
      body: PageEntrance(
        child: list.isEmpty
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
                      _buildProgressReport(report),
                      const SizedBox(height: 16),
                      _buildCoach(coach),
                      const SizedBox(height: 16),
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
                final expected = entry.avgExpectedMinutes;
                final delta = entry.avgDeltaMinutes;

                final bool hasExpected = entry.sessionsWithExpected > 0;
                final deltaLabel = !hasExpected
                  ? 'No expected length'
                  : delta == 0
                    ? 'On time'
                    : delta > 0
                      ? '${delta}m faster'
                      : '${delta.abs()}m over';
                final deltaColor = !hasExpected
                  ? AppTheme.textSecondary
                  : delta == 0
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _statChip('Sessions', '${entry.sessions}'),
                            _statChip('Time', _formatDuration(entry.totalMs)),
                            _statChip('XP', '${entry.earnedXp}'),
                            _statChip('With expected', '${entry.sessionsWithExpected}'),
                            _statChip('No expected', '${entry.sessionsWithoutExpected}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              expected == 0 ? 'Expected: --' : 'Expected (avg): ${expected}m',
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
      ),
    );
  }

  Widget _buildProgressReport(ProgressReport report) {
    final current = report.current;
    final previous = report.previous;

    String periodLabel(ReportPeriod p) {
      switch (p) {
        case ReportPeriod.day:
          return 'Daily';
        case ReportPeriod.week:
          return 'Weekly';
        case ReportPeriod.month:
          return 'Monthly';
        case ReportPeriod.year:
          return 'Yearly';
      }
    }

    return CyberCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progress report',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ReportPeriod>(
                    value: _period,
                    dropdownColor: AppTheme.background,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                    iconEnabledColor: AppTheme.textSecondary,
                    items: ReportPeriod.values
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(periodLabel(p)),
                          ),
                        )
                        .toList(),
                    onChanged: (next) {
                      if (next == null || next == _period) return;
                      setState(() => _period = next);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This ${_periodNoun(_period)} vs previous ${_periodNoun(_period)} • includes pauses, abandons, and breaks.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _deltaChip('Focus (min)', current.focusMinutes, previous.focusMinutes),
              _deltaChip('Sessions', current.sessions, previous.sessions),
              _deltaChip('XP', current.earnedXp, previous.earnedXp),
              _deltaChip('Pauses', current.pauses, previous.pauses),
              _deltaChip('Abandons', current.abandons, previous.abandons),
              _deltaChip('Break offers', current.breakOffers + current.breakIssued, previous.breakOffers + previous.breakIssued),
              _deltaChip('Taken', current.breakTaken, previous.breakTaken),
              _deltaChip('Skipped', current.breakSkipped, previous.breakSkipped),
              _deltaChip('Bonus XP', current.bonusXp, previous.bonusXp),
            ],
          ),
          const SizedBox(height: 16),
          _buildFocusTrend(report),
          const SizedBox(height: 14),
          _buildInsights(report.insights),
        ],
      ),
    );
  }

  Widget _buildCoach(FocusInsights insights) {
    Color burnoutColor(int score) {
      if (score <= 35) return Colors.greenAccent;
      if (score <= 65) return Colors.amberAccent;
      return Colors.redAccent;
    }

    String weekdayLabel(int idx) {
      const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      if (idx < 0 || idx >= labels.length) return '--';
      return labels[idx];
    }

    String bestWindowLabel() {
      if (insights.bestHour == null) return '--';
      final h = insights.bestHour!;
      String fmt(int hour24) {
        final suffix = hour24 >= 12 ? 'pm' : 'am';
        final twelve = hour24 % 12 == 0 ? 12 : hour24 % 12;
        return '$twelve$suffix';
      }

      return '${fmt(h)}–${fmt((h + 1) % 24)}';
    }

    final bestDay = insights.bestWeekday == null ? '--' : weekdayLabel(insights.bestWeekday!);

    return CyberCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coach report',
            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'A blend of motivation + KPI signals (last 28 days).',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statChip('Best day', bestDay),
              _statChip('Best hour', bestWindowLabel()),
              _statChip('Motivation', '${insights.motivationScore}/100'),
              _statChip('Productivity', '${insights.productivityScore}/100'),
              _statChip('Burnout risk', '${insights.burnoutRiskScore}/100'),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Scores', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              _scoreRow('Motivation', insights.motivationScore, AppTheme.primary),
              const SizedBox(height: 10),
              _scoreRow('Productivity', insights.productivityScore, AppTheme.primary),
              const SizedBox(height: 10),
              _scoreRow('Burnout risk', insights.burnoutRiskScore, burnoutColor(insights.burnoutRiskScore)),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeatmap(insights),
          const SizedBox(height: 14),
          if (insights.highlights.isNotEmpty) ...[
            const Text('Highlights', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...insights.highlights.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: AppTheme.textSecondary)),
                    Expanded(child: Text(t, style: const TextStyle(color: AppTheme.textPrimary, height: 1.3))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (insights.recommendations.isNotEmpty) ...[
            const Text('Recommendations', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...insights.recommendations.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: AppTheme.textSecondary)),
                    Expanded(child: Text(t, style: const TextStyle(color: AppTheme.textPrimary, height: 1.3))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreRow(String label, int score, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ),
        Expanded(
          child: CyberProgress(
            value: score.toDouble(),
            progressColor: color,
            backgroundColor: AppTheme.background,
            height: 10,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$score',
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHeatmap(FocusInsights insights) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxCell = max(1, insights.heatmapMaxCellMinutes);

    Color cellColor(int minutes) {
      if (minutes <= 0) return AppTheme.background;
      final t = (minutes / maxCell).clamp(0.0, 1.0);
      final opacity = (0.10 + 0.75 * t).clamp(0.0, 0.85);
      return AppTheme.primary.withOpacity(opacity);
    }

    Widget hourTick(String label) {
      return SizedBox(
        width: 18,
        child: Center(
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Focus heatmap (weekday × hour)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 34),
                  hourTick('0'),
                  const SizedBox(width: 90),
                  hourTick('6'),
                  const SizedBox(width: 90),
                  hourTick('12'),
                  const SizedBox(width: 90),
                  hourTick('18'),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(7, (wd) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(labels[wd], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      ),
                      ...List.generate(24, (h) {
                        final m = insights.heatmapMinutes[wd][h];
                        return Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: cellColor(m),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.borderColor.withOpacity(0.6), width: 0.6),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Darker = more focus minutes. Max cell: ${insights.heatmapMaxCellMinutes}m',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  String _periodNoun(ReportPeriod p) {
    switch (p) {
      case ReportPeriod.day:
        return 'day';
      case ReportPeriod.week:
        return 'week';
      case ReportPeriod.month:
        return 'month';
      case ReportPeriod.year:
        return 'year';
    }
  }

  Widget _deltaChip(String label, int current, int previous) {
    final diff = current - previous;
    final pct = (diff / max(1, previous)) * 100;

    final up = diff > 0;
    final flat = diff == 0;
    final color = flat
        ? AppTheme.textSecondary
        : up
            ? Colors.greenAccent
            : Colors.redAccent;

    final arrow = flat
        ? '•'
        : up
            ? '▲'
            : '▼';

    final suffix = flat
        ? '0%'
        : '${pct.abs().toStringAsFixed(pct.abs() >= 10 ? 0 : 1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            '$current',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '$arrow ${diff.abs()} • $suffix',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusTrend(ProgressReport report) {
    if (report.buckets.isEmpty) {
      return const SizedBox.shrink();
    }

    final buckets = report.buckets;
    final spots = <FlSpot>[];
    int maxY = 0;
    for (int i = 0; i < buckets.length; i++) {
      final y = buckets[i].focusMinutes;
      maxY = max(maxY, y);
      spots.add(FlSpot(i.toDouble(), y.toDouble()));
    }

    String xLabel(int i) {
      if (i < 0 || i >= buckets.length) return '';
      final d = buckets[i].start;
      switch (report.period) {
        case ReportPeriod.day:
          return '${d.month}/${d.day}';
        case ReportPeriod.week:
          return '${d.month}/${d.day}';
        case ReportPeriod.month:
          return '${d.month}/${d.year % 100}';
        case ReportPeriod.year:
          return '${d.year}';
      }
    }

    return SizedBox(
      height: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Focus trend', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (buckets.length - 1).toDouble(),
                minY: 0,
                maxY: max(1, maxY).toDouble(),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: true, border: Border.all(color: AppTheme.borderColor)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: max(1, (maxY / 3).floor()).toDouble(),
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
                      interval: report.period == ReportPeriod.year
                          ? 1
                          : report.period == ReportPeriod.month
                              ? 2
                              : 3,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= buckets.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            xLabel(idx),
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

  Widget _buildInsights(List<String> insights) {
    if (insights.isEmpty) {
      return const Text('No insights yet — do a few sessions and I\'ll start spotting patterns.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Smart insights', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...insights.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(color: AppTheme.textSecondary)),
                Expanded(
                  child: Text(t, style: const TextStyle(color: AppTheme.textPrimary, height: 1.3)),
                ),
              ],
            ),
          ),
        ),
      ],
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
  int sessionsWithExpected = 0;
  int sessionsWithoutExpected = 0;
  int expectedMinutesSum = 0;
  int deltaMinutesSum = 0;
  int earnedXp = 0;

  int get avgExpectedMinutes {
    if (sessionsWithExpected <= 0) return 0;
    return (expectedMinutesSum / sessionsWithExpected).round();
  }

  int get avgDeltaMinutes {
    if (sessionsWithExpected <= 0) return 0;
    return (deltaMinutesSum / sessionsWithExpected).round();
  }

  _MissionAnalytics({required this.id, required this.title});
}
