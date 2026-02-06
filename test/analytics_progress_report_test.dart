import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/models/focus_event.dart';
import 'package:focus_flutter/shared/models/focus_session.dart';
import 'package:focus_flutter/shared/services/progress_report_service.dart';

void main() {
  test('daily report aggregates sessions and events into buckets', () {
    final now = DateTime(2026, 2, 4, 12);

    final history = <FocusSessionLogEntry>[
      FocusSessionLogEntry(
        id: 's1',
        questId: 'q1',
        startedAt: now.subtract(const Duration(days: 1, minutes: 30)).millisecondsSinceEpoch,
        endedAt: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        segments: const [],
        totalMs: 30 * 60000,
        earnedExp: 60,
      ),
      FocusSessionLogEntry(
        id: 's2',
        questId: 'q1',
        startedAt: now.subtract(const Duration(minutes: 25)).millisecondsSinceEpoch,
        endedAt: now.millisecondsSinceEpoch,
        segments: const [],
        totalMs: 25 * 60000,
        earnedExp: 50,
      ),
    ];

    final events = <FocusEvent>[
      FocusEvent(id: 'e1', type: 'focus_pause', atMs: now.millisecondsSinceEpoch, questId: 'q1', sessionId: 's2'),
      FocusEvent(id: 'e2', type: 'mission_abandon', atMs: now.millisecondsSinceEpoch, questId: 'q1', sessionId: 's2'),
      FocusEvent(id: 'e3', type: 'break_offer', atMs: now.millisecondsSinceEpoch, questId: 'q1', sessionId: 's2'),
      FocusEvent(id: 'e4', type: 'break_skipped', atMs: now.millisecondsSinceEpoch, questId: 'q1', sessionId: 's2'),
      FocusEvent(id: 'e5', type: 'bonus_xp', atMs: now.millisecondsSinceEpoch, questId: 'q1', sessionId: 's2', value: 15),
    ];

    final report = ProgressReportService.generate(
      history: history,
      events: events,
      period: ReportPeriod.day,
      now: now,
    );

    expect(report.buckets, isNotEmpty);

    // Current bucket is "today".
    expect(report.current.focusMinutes, 25);
    expect(report.current.sessions, 1);
    expect(report.current.earnedXp, 50);

    // Events in today bucket.
    expect(report.current.pauses, 1);
    expect(report.current.abandons, 1);
    expect(report.current.breakOffers, 1);
    expect(report.current.breakSkipped, 1);
    expect(report.current.bonusXp, 15);

    // Previous bucket is "yesterday".
    expect(report.previous.focusMinutes, 30);
    expect(report.previous.sessions, 1);
    expect(report.previous.earnedXp, 60);
  });

  test('weekly report uses Monday as week start and compares against previous week', () {
    // Feb 4, 2026 is Wednesday.
    final now = DateTime(2026, 2, 4, 12);
    final monday = DateTime(2026, 2, 2, 0);
    final prevMonday = monday.subtract(const Duration(days: 7));

    final history = <FocusSessionLogEntry>[
      FocusSessionLogEntry(
        id: 'w_cur',
        questId: 'q1',
        startedAt: monday.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        endedAt: monday.add(const Duration(hours: 2)).millisecondsSinceEpoch,
        segments: const [],
        totalMs: 60 * 60000,
        earnedExp: 100,
      ),
      FocusSessionLogEntry(
        id: 'w_prev',
        questId: 'q1',
        startedAt: prevMonday.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        endedAt: prevMonday.add(const Duration(hours: 2)).millisecondsSinceEpoch,
        segments: const [],
        totalMs: 30 * 60000,
        earnedExp: 40,
      ),
    ];

    final report = ProgressReportService.generate(
      history: history,
      events: const [],
      period: ReportPeriod.week,
      now: now,
    );

    expect(report.current.start, monday);
    expect(report.current.focusMinutes, 60);

    expect(report.previous.start, prevMonday);
    expect(report.previous.focusMinutes, 30);
  });
}
