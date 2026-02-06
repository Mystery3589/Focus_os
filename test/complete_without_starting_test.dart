import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focus_flutter/shared/models/quest.dart';
import 'package:focus_flutter/shared/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('completeQuestWithoutStarting completes quest and logs a zero-duration entry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    final quest = Quest(
      id: 'q1',
      title: 'Test Mission',
      description: 'A mission completed instantly.',
      reward: 'XP',
      progress: 0,
      difficulty: 'B',
      priority: 'B',
      expiry: '',
      expReward: 0,
      statPointsReward: 0,
      active: true,
      completed: false,
      expectedMinutes: 30,
      createdAt: 0,
    );

    notifier.addQuest(quest);

    final ok = notifier.completeQuestWithoutStarting('q1');
    expect(ok, isTrue);

    final stats = container.read(userProvider);
    final updated = stats.quests.firstWhere((q) => q.id == 'q1');
    expect(updated.completed, isTrue);
    expect(updated.progress, 100);
    expect(updated.completedAt, isNotNull);

    // Should also be tracked in focus history.
    expect(stats.focus.history, isNotEmpty);
    final log = stats.focus.history.last;
    expect(log.questId, 'q1');
    expect(log.totalMs, 0);
    expect(log.earnedExp, greaterThanOrEqualTo(0));
  });

  test('completeQuestWithoutStarting is blocked while mission is running', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    notifier.addQuest(
      Quest(
        id: 'q2',
        title: 'Running Mission',
        description: 'Should block manual completion',
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

    final started = notifier.startFocus('q2');
    expect(started, isTrue);

    final ok = notifier.completeQuestWithoutStarting('q2');
    expect(ok, isFalse);

    final stats = container.read(userProvider);
    final q = stats.quests.firstWhere((q) => q.id == 'q2');
    expect(q.completed, isFalse);
  });

  test('completeQuestWithoutStarting completes even if an abandoned session exists (and cleans it up)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    notifier.addQuest(
      Quest(
        id: 'q3',
        title: 'Abandoned Mission',
        description: 'Has an abandoned session lingering',
        reward: 'XP',
        progress: 0,
        difficulty: 'B',
        priority: 'B',
        expiry: '',
        expReward: 0,
        statPointsReward: 0,
        active: true,
        completed: false,
        expectedMinutes: 5,
        createdAt: 0,
      ),
    );

    final started = notifier.startFocus('q3');
    expect(started, isTrue);

    final activeId = container.read(userProvider).focus.activeSessionId;
    expect(activeId, isNotNull);
    notifier.abandonMission(activeId!);

    final ok = notifier.completeQuestWithoutStarting('q3');
    expect(ok, isTrue);

    final stats = container.read(userProvider);
    final q = stats.quests.firstWhere((q) => q.id == 'q3');
    expect(q.completed, isTrue);

    // No open sessions should remain for this quest.
    expect(stats.focus.openSessions.where((s) => s.questId == 'q3'), isEmpty);
  });
}
