import 'dart:math';

import '../models/focus_event.dart';
import '../models/focus_session.dart';

class FocusInsights {
  /// Minutes of focus by [weekdayIndex][hour], where weekdayIndex is 0=Mon..6=Sun.
  final List<List<int>> heatmapMinutes;

  /// Max minutes in any heatmap cell (for normalizing intensity).
  final int heatmapMaxCellMinutes;

  /// Best hour of day (0-23). Null when there is no data.
  final int? bestHour;

  /// Best weekday (0=Mon..6=Sun). Null when there is no data.
  final int? bestWeekday;

  /// 0..100 (higher is better)
  final int motivationScore;

  /// 0..100 (higher is better)
  final int productivityScore;

  /// 0..100 (higher means higher risk)
  final int burnoutRiskScore;

  /// Positive, celebratory callouts.
  final List<String> highlights;

  /// Actionable suggestions.
  final List<String> recommendations;

  const FocusInsights({
    required this.heatmapMinutes,
    required this.heatmapMaxCellMinutes,
    required this.bestHour,
    required this.bestWeekday,
    required this.motivationScore,
    required this.productivityScore,
    required this.burnoutRiskScore,
    required this.highlights,
    required this.recommendations,
  });
}

class FocusInsightsService {
  static FocusInsights generate({
    required List<FocusSessionLogEntry> history,
    required List<FocusEvent> events,
    DateTime? now,
    int windowDays = 28,
  }) {
    final anchor = now ?? DateTime.now();
    final cutoff = DateTime(anchor.year, anchor.month, anchor.day).subtract(Duration(days: windowDays - 1));

    final heatmap = List.generate(7, (_) => List<int>.filled(24, 0));

    // Build heatmap minutes. We distribute time across hour boundaries to avoid
    // misleading “all minutes go to the start hour” artifacts.
    for (final log in history) {
      final end = DateTime.fromMillisecondsSinceEpoch(log.endedAt);
      final start = DateTime.fromMillisecondsSinceEpoch(log.startedAt);
      if (end.isBefore(cutoff)) continue;

      _accumulateHeatmap(
        heatmapMinutes: heatmap,
        start: start,
        endExclusive: end,
      );
    }

    int maxCell = 0;
    int? bestHour;
    int? bestWeekday;
    for (int wd = 0; wd < 7; wd++) {
      for (int h = 0; h < 24; h++) {
        final v = heatmap[wd][h];
        if (v > maxCell) {
          maxCell = v;
          bestHour = h;
          bestWeekday = wd;
        }
      }
    }

    // Rollups (last 7d + previous 7d) for the scores.
    final start7 = DateTime(anchor.year, anchor.month, anchor.day).subtract(const Duration(days: 6));
    final prev7Start = start7.subtract(const Duration(days: 7));
    final prev7EndExclusive = start7;

    int focusMs7 = 0;
    int focusMsPrev7 = 0;
    int sessions7 = 0;
    int earnedXp7 = 0;

    final activeDayKeys14 = <int>{};
    final start14 = DateTime(anchor.year, anchor.month, anchor.day).subtract(const Duration(days: 13));

    for (final log in history) {
      final ended = DateTime.fromMillisecondsSinceEpoch(log.endedAt);
      if (!ended.isBefore(start7) && !ended.isAfter(anchor)) {
        focusMs7 += log.totalMs;
        sessions7 += 1;
        earnedXp7 += log.earnedExp;
      }
      if (!ended.isBefore(prev7Start) && ended.isBefore(prev7EndExclusive)) {
        focusMsPrev7 += log.totalMs;
      }

      if (!ended.isBefore(start14)) {
        final k = _dayKey(DateTime(ended.year, ended.month, ended.day));
        if (log.totalMs > 0) activeDayKeys14.add(k);
      }
    }

    final streak = _computeStreak(activeDayKeys14, anchor: anchor);

    int pauses7 = 0;
    int abandons7 = 0;
    int breakOffers7 = 0;
    int breakSkipped7 = 0;
    int breakTaken7 = 0;

    for (final e in events) {
      final t = DateTime.fromMillisecondsSinceEpoch(e.atMs);
      if (t.isBefore(start7) || t.isAfter(anchor)) continue;

      switch (e.type) {
        case 'focus_pause':
          pauses7 += 1;
          break;
        case 'mission_abandon':
          abandons7 += 1;
          break;
        case 'break_offer':
        case 'break_issued':
          breakOffers7 += 1;
          break;
        case 'break_skipped':
          breakSkipped7 += 1;
          break;
        case 'break_taken':
          breakTaken7 += 1;
          break;
      }
    }

    final focusMin7 = _minutesFromMs(focusMs7);
    final focusMinPrev7 = _minutesFromMs(focusMsPrev7);
    final avgSessionMin7 = sessions7 <= 0 ? 0.0 : focusMin7 / sessions7;

    final pauseRatePerHour = focusMin7 <= 0 ? 0.0 : pauses7 / max(1, focusMin7) * 60;
    final abandonRate = sessions7 <= 0 ? 0.0 : abandons7 / sessions7;
    final breakSkipRate = breakSkipped7 / max(1, breakOffers7);

    final motivationScore = _computeMotivationScore(
      activeDays14: activeDayKeys14.length,
      streakCurrent: streak.current,
      focusMinutes7: focusMin7,
    );

    final productivityScore = _computeProductivityScore(
      focusMinutes7: focusMin7,
      sessions7: sessions7,
      earnedXp7: earnedXp7,
      avgSessionMinutes7: avgSessionMin7,
    );

    final burnoutRiskScore = _computeBurnoutRiskScore(
      focusMinutes7: focusMin7,
      pauseRatePerHour: pauseRatePerHour,
      breakOffers7: breakOffers7,
      breakSkipRate: breakSkipRate,
      abandonRate: abandonRate,
      sessions7: sessions7,
    );

    final highlights = <String>[];
    final recommendations = <String>[];

    // Extra context signals
    if (activeDayKeys14.length >= 10) {
      highlights.add('Consistency: active on ${activeDayKeys14.length}/14 days. That’s strong momentum.');
    }

    if (focusMin7 >= 300) {
      highlights.add('Big week: $focusMin7 focus minutes in the last 7 days.');
    }

    if (streak.current >= 3) {
      highlights.add('Streak: ${streak.current} day(s) active. Keep the chain alive.');
    }
    if (focusMin7 - focusMinPrev7 >= 30) {
      highlights.add('Uptrend: +${focusMin7 - focusMinPrev7} focus minutes vs the previous 7 days.');
    }
    if (productivityScore >= 75 && focusMin7 >= 60) {
      highlights.add('Efficiency is strong right now — your sessions are landing clean.');
    }

    if (breakOffers7 >= 2 && breakTaken7 >= 1 && breakSkipRate <= 0.4) {
      highlights.add('Good recovery: you’re actually taking breaks when prompted. Nice discipline.');
    }

    if (bestHour != null && bestWeekday != null && focusMin7 >= 60) {
      highlights.add('Peak window: ${_formatHourRange(bestHour)} on ${_weekdayLabel(bestWeekday)} looks like your sweet spot.');
    }

    if (burnoutRiskScore >= 70) {
      recommendations.add('Burnout risk is high. Try taking the next suggested break (even a 3–5 min reset helps).');
    }

    if (burnoutRiskScore >= 55 && motivationScore <= 40) {
      recommendations.add('Energy looks strained. Consider a shorter “minimum viable” session today and prioritize rest after.');
    }

    if (pauseRatePerHour >= 3.0 && focusMin7 >= 60) {
      recommendations.add('Lots of pauses lately. Consider shorter focus sprints (15–25 min) to reduce context switching.');
    }

    if (sessions7 >= 8 && avgSessionMin7 > 0 && avgSessionMin7 < 15) {
      recommendations.add('Many short sessions. Try one longer “anchor” session (25–40 min) to reduce restart overhead.');
    }

    if (abandonRate >= 0.30 && sessions7 >= 3) {
      recommendations.add('High abandon rate. Before starting, write a 1-sentence target and the first concrete action.');
    }

    if (breakOffers7 >= 2 && breakSkipRate >= 0.7) {
      recommendations.add('You skip most breaks. Try taking 1 in 3 breaks to keep performance stable.');
    }

    if (activeDayKeys14.length <= 4) {
      recommendations.add('Consistency is low. Set a tiny daily minimum (5–10 min) to rebuild momentum.');
    }

    if (focusMin7 < 60) {
      recommendations.add('Warm-up idea: do 1 short session today to get back into the groove.');
    }

    if (bestHour != null && focusMin7 < 120) {
      recommendations.add('Your best focus window is around ${_formatHourRange(bestHour)}. Try scheduling a session there.');
    }

    return FocusInsights(
      heatmapMinutes: heatmap,
      heatmapMaxCellMinutes: maxCell,
      bestHour: bestHour,
      bestWeekday: bestWeekday,
      motivationScore: motivationScore,
      productivityScore: productivityScore,
      burnoutRiskScore: burnoutRiskScore,
      highlights: highlights.take(4).toList(),
      recommendations: recommendations.take(5).toList(),
    );
  }

  static void _accumulateHeatmap({
    required List<List<int>> heatmapMinutes,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    if (!start.isBefore(endExclusive)) return;

    var cursor = start;
    while (cursor.isBefore(endExclusive)) {
      final nextHour = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour).add(const Duration(hours: 1));
      final segEnd = nextHour.isBefore(endExclusive) ? nextHour : endExclusive;

      final ms = segEnd.difference(cursor).inMilliseconds;
      final minutes = (ms / 60000.0);

      // weekday: Mon=1..Sun=7
      final wd = cursor.weekday - DateTime.monday;
      if (wd >= 0 && wd < 7) {
        heatmapMinutes[wd][cursor.hour] += minutes.round();
      }

      cursor = segEnd;
    }
  }

  static int _minutesFromMs(int ms) => max(0, (ms / 60000).floor());

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static ({int current, int best}) _computeStreak(Set<int> activeDayKeys, {required DateTime anchor}) {
    if (activeDayKeys.isEmpty) return (current: 0, best: 0);

    DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
    int key(DateTime d) => _dayKey(dayStart(d));

    var cur = 0;
    var cursor = dayStart(anchor);
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

  static int _computeMotivationScore({
    required int activeDays14,
    required int streakCurrent,
    required int focusMinutes7,
  }) {
    final consistency = (activeDays14 / 14.0 * 60.0);
    final streak = min(25.0, streakCurrent * 5.0);
    final progress = min(15.0, (focusMinutes7 / 180.0) * 15.0);
    return (consistency + streak + progress).round().clamp(0, 100);
  }

  static int _computeProductivityScore({
    required int focusMinutes7,
    required int sessions7,
    required int earnedXp7,
    required double avgSessionMinutes7,
  }) {
    final volume = min(50.0, (focusMinutes7 / 300.0) * 50.0); // 5h/week target
    final cadence = min(25.0, (avgSessionMinutes7 / 25.0) * 25.0);
    final xpPerMin = focusMinutes7 <= 0 ? 0.0 : earnedXp7 / max(1, focusMinutes7);
    final efficiency = min(25.0, (xpPerMin / 1.5) * 25.0);

    // Slight penalty if lots of sessions but very low minutes (fragmentation).
    final fragmentationPenalty = (sessions7 >= 8 && focusMinutes7 < 120) ? 10.0 : 0.0;

    return (volume + cadence + efficiency - fragmentationPenalty).round().clamp(0, 100);
  }

  static int _computeBurnoutRiskScore({
    required int focusMinutes7,
    required double pauseRatePerHour,
    required int breakOffers7,
    required double breakSkipRate,
    required double abandonRate,
    required int sessions7,
  }) {
    var risk = 0.0;

    if (focusMinutes7 >= 600) risk += 25; // 10h/week
    if (pauseRatePerHour >= 3.0 && focusMinutes7 >= 60) risk += 25;

    if (breakOffers7 >= 2 && breakSkipRate >= 0.7) risk += 20;

    if (sessions7 >= 4 && abandonRate >= 0.25) risk += 15;

    if (focusMinutes7 >= 900) risk += 15; // 15h/week

    return risk.round().clamp(0, 100);
  }

  static String _weekdayLabel(int weekdayIndex) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weekdayIndex < 0 || weekdayIndex >= labels.length) return '--';
    return labels[weekdayIndex];
  }

  static String _formatHourRange(int hour24) {
    String h(int x) {
      final hour = x % 24;
      final suffix = hour >= 12 ? 'pm' : 'am';
      final twelve = hour % 12 == 0 ? 12 : hour % 12;
      return '$twelve$suffix';
    }

    return '${h(hour24)}–${h(hour24 + 1)}';
  }
}
