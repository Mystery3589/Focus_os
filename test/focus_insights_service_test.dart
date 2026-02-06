import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/models/focus_event.dart';
import 'package:focus_flutter/shared/models/focus_session.dart';
import 'package:focus_flutter/shared/services/focus_insights_service.dart';

void main() {
  test('heatmap distributes minutes across hour boundaries', () {
    final now = DateTime(2026, 2, 4, 12);

    // Monday: Feb 2, 2026.
    final start = DateTime(2026, 2, 2, 9, 30);
    final end = DateTime(2026, 2, 2, 10, 30);

    final history = <FocusSessionLogEntry>[
      FocusSessionLogEntry(
        id: 's1',
        questId: 'q1',
        startedAt: start.millisecondsSinceEpoch,
        endedAt: end.millisecondsSinceEpoch,
        segments: const [],
        totalMs: 60 * 60000,
        earnedExp: 60,
      ),
    ];

    final insights = FocusInsightsService.generate(
      history: history,
      events: const [],
      now: now,
      windowDays: 28,
    );

    // weekdayIndex: 0=Mon.
    expect(insights.heatmapMinutes[0][9], 30);
    expect(insights.heatmapMinutes[0][10], 30);

    // For ties, the first max cell found is kept.
    expect(insights.bestWeekday, 0);
    expect(insights.bestHour, 9);
  });

  test('burnout risk increases with high focus, pauses, break skipping, and abandons', () {
    final now = DateTime(2026, 2, 4, 12);

    final history = <FocusSessionLogEntry>[
      FocusSessionLogEntry(
        id: 's1',
        questId: 'q1',
        startedAt: DateTime(2026, 2, 4, 10).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 2, 4, 11).millisecondsSinceEpoch,
        segments: const [],
        totalMs: 60 * 60000,
        earnedExp: 100,
      ),
      FocusSessionLogEntry(
        id: 's2',
        questId: 'q1',
        startedAt: DateTime(2026, 2, 3, 9).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 2, 3, 11).millisecondsSinceEpoch,
        segments: const [],
        totalMs: 120 * 60000,
        earnedExp: 200,
      ),
      FocusSessionLogEntry(
        id: 's3',
        questId: 'q1',
        startedAt: DateTime(2026, 2, 2, 7).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 2, 2, 11).millisecondsSinceEpoch,
        segments: const [],
        totalMs: 240 * 60000,
        earnedExp: 300,
      ),
      FocusSessionLogEntry(
        id: 's4',
        questId: 'q1',
        startedAt: DateTime(2026, 1, 31, 6, 20).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 1, 31, 11).millisecondsSinceEpoch,
        segments: const [],
        totalMs: 280 * 60000,
        earnedExp: 400,
      ),
    ];

    final events = <FocusEvent>[
      // Many pauses in the last 7 days.
      for (int i = 0; i < 50; i++)
        FocusEvent(
          id: 'p$i',
          type: 'focus_pause',
          atMs: DateTime(2026, 2, 4, 11, 30).millisecondsSinceEpoch,
          questId: 'q1',
          sessionId: 's1',
        ),
      // Skipped breaks.
      FocusEvent(id: 'bo1', type: 'break_offer', atMs: DateTime(2026, 2, 4, 11, 40).millisecondsSinceEpoch, questId: 'q1', sessionId: 's1'),
      FocusEvent(id: 'bo2', type: 'break_offer', atMs: DateTime(2026, 2, 4, 11, 41).millisecondsSinceEpoch, questId: 'q1', sessionId: 's1'),
      FocusEvent(id: 'bs1', type: 'break_skipped', atMs: DateTime(2026, 2, 4, 11, 42).millisecondsSinceEpoch, questId: 'q1', sessionId: 's1'),
      FocusEvent(id: 'bs2', type: 'break_skipped', atMs: DateTime(2026, 2, 4, 11, 43).millisecondsSinceEpoch, questId: 'q1', sessionId: 's1'),
      // Abandon signal.
      FocusEvent(id: 'a1', type: 'mission_abandon', atMs: DateTime(2026, 2, 4, 11, 50).millisecondsSinceEpoch, questId: 'q1', sessionId: 's1'),
    ];

    final insights = FocusInsightsService.generate(
      history: history,
      events: events,
      now: now,
      windowDays: 28,
    );

    expect(insights.burnoutRiskScore, greaterThanOrEqualTo(70));

    final recText = insights.recommendations.join(' | ');
    expect(recText, contains('Burnout risk'));
    expect(recText, contains('pauses'));
    expect(recText, contains('skip most breaks'));
  });
}
