import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focus_flutter/shared/models/quest.dart';
import 'package:focus_flutter/shared/providers/user_provider.dart';
import 'package:focus_flutter/shared/services/mission_rollup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Quest quest({
    required String id,
    required String title,
    String? parentQuestId,
  }) {
    return Quest(
      id: id,
      title: title,
      description: 'desc',
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
      parentQuestId: parentQuestId,
    );
  }

  test('Quest JSON roundtrip preserves parentQuestId', () {
    final q = quest(id: 'c1', title: 'Child', parentQuestId: 'p1');
    final json = q.toJson();
    final re = Quest.fromJson(json);
    expect(re.parentQuestId, 'p1');
  });

  test('startFocus is blocked for parent missions with sub-missions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);
    notifier.addQuest(quest(id: 'p1', title: 'Parent'));
    notifier.addQuest(quest(id: 'c1', title: 'Child 1', parentQuestId: 'p1'));

    final ok = notifier.startFocus('p1');
    expect(ok, isFalse);
  });

  test('completing last sub-mission auto-completes parent mission', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);
    notifier.addQuest(quest(id: 'p1', title: 'Parent'));
    notifier.addQuest(quest(id: 'c1', title: 'Child 1', parentQuestId: 'p1'));
    notifier.addQuest(quest(id: 'c2', title: 'Child 2', parentQuestId: 'p1'));

    notifier.completeQuest('c1', totalMinutes: 5, earnedExpOverride: 0);
    var stats = container.read(userProvider);
    expect(stats.quests.firstWhere((q) => q.id == 'p1').completed, isFalse);

    notifier.completeQuest('c2', totalMinutes: 6, earnedExpOverride: 0);
    stats = container.read(userProvider);
    expect(stats.quests.firstWhere((q) => q.id == 'p1').completed, isTrue);
  });

  test('deleteQuest cascades to sub-missions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);
    notifier.addQuest(quest(id: 'p1', title: 'Parent'));
    notifier.addQuest(quest(id: 'c1', title: 'Child 1', parentQuestId: 'p1'));

    notifier.deleteQuest('p1');
    final stats = container.read(userProvider);
    expect(stats.quests.where((q) => q.id == 'p1'), isEmpty);
    expect(stats.quests.where((q) => q.id == 'c1'), isEmpty);
  });

  test('analytics rollup groups sub-mission focus time under parent', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);
    notifier.addQuest(quest(id: 'p1', title: 'Parent'));
    notifier.addQuest(quest(id: 'c1', title: 'Child 1', parentQuestId: 'p1'));
    notifier.addQuest(quest(id: 'c2', title: 'Child 2', parentQuestId: 'p1'));

    expect(notifier.startFocus('c1'), isTrue);
    notifier.completeMission('c1', 2 * 60 * 1000);

    expect(notifier.startFocus('c2'), isTrue);
    notifier.completeMission('c2', 3 * 60 * 1000);

    final stats = container.read(userProvider);
    final questsById = {for (final q in stats.quests) q.id: q};

    final totalsByMission = <String, int>{};
    for (final log in stats.focus.history) {
      if (MissionRollupService.isCustomLog(log)) continue;
      final id = MissionRollupService.rolledUpMissionIdFor(questId: log.questId, questsById: questsById);
      totalsByMission[id] = (totalsByMission[id] ?? 0) + log.totalMs;
    }

    expect(totalsByMission['p1'], 5 * 60 * 1000);
  });
}
