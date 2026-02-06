import 'dart:math';

import '../models/focus_event.dart';
import '../models/focus_session.dart';

enum ReportPeriod {
  day,
  week,
  month,
  year,
}

class ReportBucket {
  final DateTime start;
  final DateTime endExclusive;

  int focusMs;
  int sessions;
  int earnedXp;

  int pauses;
  int abandons;

  int breakOffers;
  int breakIssued;
  int breakTaken;
  int breakSkipped;
  int bonusXp;

  ReportBucket({
    required this.start,
    required this.endExclusive,
    this.focusMs = 0,
    this.sessions = 0,
    this.earnedXp = 0,
    this.pauses = 0,
    this.abandons = 0,
    this.breakOffers = 0,
    this.breakIssued = 0,
    this.breakTaken = 0,
    this.breakSkipped = 0,
    this.bonusXp = 0,
  });

  int get focusMinutes => max(0, (focusMs / 60000).floor());

  double get avgSessionMinutes {
    if (sessions <= 0) return 0;
    return focusMinutes / sessions;
  }
}

class ReportDelta {
  final int current;
  final int previous;

  const ReportDelta({required this.current, required this.previous});

  int get diff => current - previous;

  double get pct {
    final denom = max(1, previous);
    return (diff / denom) * 100;
  }
}

class ProgressReport {
  final ReportPeriod period;
  final List<ReportBucket> buckets;
  final ReportBucket current;
  final ReportBucket previous;

  /// High-level insights for a “smart” report.
  final List<String> insights;

  const ProgressReport({
    required this.period,
    required this.buckets,
    required this.current,
    required this.previous,
    required this.insights,
  });
}

class ProgressReportService {
  static ProgressReport generate({
    required List<FocusSessionLogEntry> history,
    required List<FocusEvent> events,
    required ReportPeriod period,
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();

    final buckets = _buildBuckets(period: period, now: anchor);
    if (buckets.isEmpty) {
      final empty = ReportBucket(start: anchor, endExclusive: anchor);
      return ProgressReport(period: period, buckets: const [], current: empty, previous: empty, insights: const []);
    }

    // Aggregate sessions by endedAt.
    for (final log in history) {
      final t = DateTime.fromMillisecondsSinceEpoch(log.endedAt);
      final idx = _bucketIndex(buckets, t);
      if (idx == null) continue;
      final b = buckets[idx];
      b.focusMs += log.totalMs;
      b.sessions += 1;
      b.earnedXp += log.earnedExp;
    }

    // Aggregate events by atMs.
    for (final e in events) {
      final t = DateTime.fromMillisecondsSinceEpoch(e.atMs);
      final idx = _bucketIndex(buckets, t);
      if (idx == null) continue;
      final b = buckets[idx];

      switch (e.type) {
        case 'focus_pause':
          b.pauses += 1;
          break;
        case 'mission_abandon':
          b.abandons += 1;
          break;
        case 'break_offer':
          b.breakOffers += 1;
          break;
        case 'break_issued':
          b.breakIssued += 1;
          break;
        case 'break_taken':
          b.breakTaken += 1;
          break;
        case 'break_skipped':
          b.breakSkipped += 1;
          break;
        case 'bonus_xp':
          b.bonusXp += e.value ?? 0;
          break;
      }
    }

    final current = buckets.last;
    final previous = buckets.length >= 2 ? buckets[buckets.length - 2] : ReportBucket(start: buckets.first.start, endExclusive: buckets.first.endExclusive);

    final insights = _buildInsights(period: period, buckets: buckets, current: current, previous: previous);

    return ProgressReport(
      period: period,
      buckets: buckets,
      current: current,
      previous: previous,
      insights: insights,
    );
  }

  static List<ReportBucket> _buildBuckets({required ReportPeriod period, required DateTime now}) {
    final count = switch (period) {
      ReportPeriod.day => 14,
      ReportPeriod.week => 12,
      ReportPeriod.month => 12,
      ReportPeriod.year => 5,
    };

    DateTime bucketStart(DateTime d) {
      switch (period) {
        case ReportPeriod.day:
          return DateTime(d.year, d.month, d.day);
        case ReportPeriod.week:
          return _startOfWeek(d);
        case ReportPeriod.month:
          return DateTime(d.year, d.month, 1);
        case ReportPeriod.year:
          return DateTime(d.year, 1, 1);
      }
    }

    DateTime addStep(DateTime d, int steps) {
      switch (period) {
        case ReportPeriod.day:
          return d.add(Duration(days: steps));
        case ReportPeriod.week:
          return d.add(Duration(days: 7 * steps));
        case ReportPeriod.month:
          return _addMonths(d, steps);
        case ReportPeriod.year:
          return DateTime(d.year + steps, 1, 1);
      }
    }

    final base = bucketStart(now);
    final first = addStep(base, -(count - 1));

    final out = <ReportBucket>[];
    for (int i = 0; i < count; i++) {
      final s = addStep(first, i);
      final e = addStep(first, i + 1);
      out.add(ReportBucket(start: s, endExclusive: e));
    }
    return out;
  }

  static int? _bucketIndex(List<ReportBucket> buckets, DateTime t) {
    // Buckets are sorted ascending and count is small.
    for (int i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      if (!t.isBefore(b.start) && t.isBefore(b.endExclusive)) return i;
    }
    return null;
  }

  static DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    // DateTime.weekday: Mon=1..Sun=7
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime _addMonths(DateTime d, int deltaMonths) {
    final y0 = d.year;
    final m0 = d.month;

    final total = (y0 * 12 + (m0 - 1)) + deltaMonths;
    final y = total ~/ 12;
    final m = (total % 12) + 1;
    return DateTime(y, m, 1);
  }

  static List<String> _buildInsights({
    required ReportPeriod period,
    required List<ReportBucket> buckets,
    required ReportBucket current,
    required ReportBucket previous,
  }) {
    final insights = <String>[];

    final focusDelta = ReportDelta(current: current.focusMinutes, previous: previous.focusMinutes);
    if (focusDelta.diff >= 15) {
      insights.add('Nice: focus time is up by ${focusDelta.diff}m vs the previous ${_periodLabel(period)}.');
    } else if (focusDelta.diff <= -15) {
      insights.add('Heads up: focus time is down by ${focusDelta.diff.abs()}m vs the previous ${_periodLabel(period)}.');
    }

    final pauseRate = current.focusMinutes <= 0 ? 0.0 : (current.pauses / max(1, current.focusMinutes)) * 60;
    if (pauseRate >= 2.0 && current.focusMinutes >= 30) {
      insights.add('You paused a lot (${current.pauses}). Consider shorter sessions or taking breaks earlier.');
    }

    final breakOffers = current.breakOffers + current.breakIssued;
    if (breakOffers > 0) {
      final skipRate = current.breakSkipped / max(1, breakOffers);
      if (skipRate >= 0.7) {
        insights.add('You skipped most breaks (${(skipRate * 100).round()}%). Great willpower—just don\'t burn out.');
      } else if (skipRate <= 0.3) {
        insights.add('Good balance: you took most suggested breaks.');
      }
    }

    // Consistency: active buckets in window.
    final active = buckets.where((b) => b.focusMinutes > 0).length;
    final pct = (active / max(1, buckets.length) * 100).round();
    if (pct >= 70) {
      insights.add('Consistency is strong: active in $pct% of recent ${_plural(period)}.');
    } else if (pct <= 30) {
      insights.add('Consistency is low ($pct%). Try aiming for a tiny daily minimum to build momentum.');
    }

    // XP efficiency.
    final xpPerMin = current.focusMinutes <= 0 ? 0.0 : current.earnedXp / max(1, current.focusMinutes);
    if (xpPerMin >= 2.0 && current.focusMinutes >= 20) {
      insights.add('High XP/min (${xpPerMin.toStringAsFixed(1)}). You\'re picking high-value sessions.');
    }

    // Abandon signal.
    if (current.abandons >= 1) {
      insights.add('You abandoned ${current.abandons} mission(s). Consider pausing instead if you plan to return.');
    }

    return insights.take(6).toList();
  }

  static String _periodLabel(ReportPeriod p) {
    return switch (p) {
      ReportPeriod.day => 'day',
      ReportPeriod.week => 'week',
      ReportPeriod.month => 'month',
      ReportPeriod.year => 'year',
    };
  }

  static String _plural(ReportPeriod p) {
    return switch (p) {
      ReportPeriod.day => 'days',
      ReportPeriod.week => 'weeks',
      ReportPeriod.month => 'months',
      ReportPeriod.year => 'years',
    };
  }
}
