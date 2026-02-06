import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focus_flutter/shared/models/focus_session.dart';
import 'package:focus_flutter/shared/models/quest.dart';
import 'package:focus_flutter/shared/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('pause logs a focus_pause event', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    notifier.addQuest(
      Quest(
        id: 'q_break_1',
        title: 'Break Quest',
        description: 'Test',
        reward: 'XP',
        progress: 0,
        difficulty: 'B',
        priority: 'B',
        expiry: '',
        expReward: 0,
        statPointsReward: 0,
        active: true,
        completed: false,
        expectedMinutes: 10,
        createdAt: 0,
      ),
    );

    expect(notifier.startFocus('q_break_1'), isTrue);
    notifier.pauseFocus();

    final stats = container.read(userProvider);
    expect(stats.focusEvents.any((e) => e.type == 'focus_pause' && e.questId == 'q_break_1'), isTrue);
  });

  test('offerBreakForSession offers when due, reschedules, logs, and skip grants bonus XP', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    notifier.addQuest(
      Quest(
        id: 'q_break_2',
        title: 'Break Quest 2',
        description: 'Test',
        reward: 'XP',
        progress: 0,
        difficulty: 'B',
        priority: 'B',
        expiry: '',
        expReward: 0,
        statPointsReward: 0,
        active: true,
        completed: false,
        expectedMinutes: 10,
        createdAt: 0,
      ),
    );

    expect(notifier.startFocus('q_break_2'), isTrue);
    notifier.pauseFocus();

    final before = container.read(userProvider);
    final session = before.focus.openSessions.firstWhere((s) => s.questId == 'q_break_2');

    // Make the session look like it already has a lot of focus time.
    final now = DateTime.now().millisecondsSinceEpoch;
    final longPaused = FocusOpenSession(
      id: session.id,
      questId: session.questId,
      heading: session.heading,
      createdAt: session.createdAt,
      status: 'paused',
      segments: [
        FocusSegment(startMs: now - 120 * 60000, endMs: now),
      ],
      nextBreakAtTotalMinutes: 60,
      breakOffers: 0,
      breaksTaken: 0,
      breaksSkipped: 0,
    );

    notifier.restoreOpenSession(longPaused);

    final offer = notifier.offerBreakForSession(session.id);
    expect(offer, isNotNull);
    expect(offer!.breakMinutes, greaterThan(0));

    final afterOffer = container.read(userProvider);
    final updated = afterOffer.focus.openSessions.firstWhere((s) => s.id == session.id);
    expect(updated.breakOffers, 1);
    expect(updated.nextBreakAtTotalMinutes, greaterThan(120));

    expect(
      afterOffer.focusEvents.any((e) => e.type == 'break_offer' && e.sessionId == session.id),
      isTrue,
    );

    notifier.recordBreakSkipped(session.id);

    final afterSkip = container.read(userProvider);
    expect(afterSkip.focusEvents.any((e) => e.type == 'break_skipped' && e.sessionId == session.id), isTrue);
    expect(afterSkip.focusEvents.any((e) => e.type == 'bonus_xp' && e.sessionId == session.id), isTrue);

    final skippedSession = afterSkip.focus.openSessions.firstWhere((s) => s.id == session.id);
    expect(skippedSession.breaksSkipped, 1);
  });

  test('abandonMission logs mission_abandon event', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    notifier.addQuest(
      Quest(
        id: 'q_break_3',
        title: 'Break Quest 3',
        description: 'Test',
        reward: 'XP',
        progress: 0,
        difficulty: 'B',
        priority: 'B',
        expiry: '',
        expReward: 0,
        statPointsReward: 0,
        active: true,
        completed: false,
        expectedMinutes: 10,
        createdAt: 0,
      ),
    );

    expect(notifier.startFocus('q_break_3'), isTrue);
    final activeId = container.read(userProvider).focus.activeSessionId;
    expect(activeId, isNotNull);

    notifier.abandonMission(activeId!);

    final stats = container.read(userProvider);
    expect(stats.focusEvents.any((e) => e.type == 'mission_abandon' && e.sessionId == activeId), isTrue);
  });
}
