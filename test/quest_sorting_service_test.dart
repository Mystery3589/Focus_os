import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/models/focus_session.dart';
import 'package:focus_flutter/shared/models/quest.dart';
import 'package:focus_flutter/shared/services/quest_sorting_service.dart';

Quest _q({
  required String id,
  required String title,
  String difficulty = 'B',
  String priority = 'B',
  int? dueDateMs,
  int? expectedMinutes,
  String? frequency,
  int createdAt = 0,
  bool completed = false,
  int? completedAt,
}) {
  return Quest(
    id: id,
    title: title,
    description: 'desc $id',
    reward: 'reward',
    progress: 0,
    difficulty: difficulty,
    priority: priority,
    expiry: '',
    expReward: 0,
    statPointsReward: 0,
    active: false,
    completed: completed,
    dueDateMs: dueDateMs,
    expectedMinutes: expectedMinutes,
    frequency: frequency,
    createdAt: createdAt,
    completedAt: completedAt,
  );
}

void main() {
  test('sort by priority desc supports legacy High/Medium/Low', () {
    final quests = <Quest>[
      _q(id: 'low', title: 'Low', priority: 'Low', createdAt: 1),
      _q(id: 'high', title: 'High', priority: 'High', createdAt: 2),
      _q(id: 'med', title: 'Medium', priority: 'Medium', createdAt: 3),
    ];

    final sorted = filterAndSortQuests(
      quests: quests,
      isCompleted: false,
      openSessions: const <FocusOpenSession>[],
      sortRules: const [QuestSortRule('priority', false)],
    );

    expect(sorted.map((q) => q.id).toList(), ['high', 'med', 'low']);
  });

  test('sort by priority desc supports mixed legacy + S/A/B', () {
    final quests = <Quest>[
      _q(id: 'a', title: 'A', priority: 'A', createdAt: 1),
      _q(id: 'high', title: 'High', priority: 'High', createdAt: 2),
      _q(id: 'low', title: 'Low', priority: 'Low', createdAt: 3),
      _q(id: 'b', title: 'B', priority: 'B', createdAt: 4),
    ];

    final sorted = filterAndSortQuests(
      quests: quests,
      isCompleted: false,
      openSessions: const <FocusOpenSession>[],
      sortRules: const [QuestSortRule('priority', false)],
    );

    // High should rank with S, then A, then B, then Low(D)
    expect(sorted.map((q) => q.id).toList(), ['high', 'a', 'b', 'low']);
  });

  test('multi-sort: priority desc, due asc, difficulty desc', () {
    final quests = <Quest>[
      _q(
        id: 'q1',
        title: 'Quest 1',
        priority: 'S',
        difficulty: 'A',
        dueDateMs: 100,
        createdAt: 100,
      ),
      _q(
        id: 'q2',
        title: 'Quest 2',
        priority: 'A',
        difficulty: 'S',
        dueDateMs: 50,
        createdAt: 200,
      ),
      _q(
        id: 'q3',
        title: 'Quest 3',
        priority: 'S',
        difficulty: 'B',
        dueDateMs: 200,
        createdAt: 150,
      ),
    ];

    final sorted = filterAndSortQuests(
      quests: quests,
      isCompleted: false,
      openSessions: const <FocusOpenSession>[],
      sortRules: const [
        QuestSortRule('priority', false),
        QuestSortRule('due', true),
        QuestSortRule('difficulty', false),
      ],
    );

    expect(sorted.map((q) => q.id).toList(), ['q1', 'q3', 'q2']);
  });

  test('sort by length asc keeps nulls last', () {
    final quests = <Quest>[
      _q(id: 'a', title: 'A', expectedMinutes: null, createdAt: 1),
      _q(id: 'b', title: 'B', expectedMinutes: 45, createdAt: 2),
      _q(id: 'c', title: 'C', expectedMinutes: 15, createdAt: 3),
    ];

    final sorted = filterAndSortQuests(
      quests: quests,
      isCompleted: false,
      openSessions: const <FocusOpenSession>[],
      sortRules: const [QuestSortRule('length', true)],
    );

    expect(sorted.map((q) => q.id).toList(), ['c', 'b', 'a']);
  });

  test('type filter: weekly only', () {
    final quests = <Quest>[
      _q(id: 'd1', title: 'Daily', frequency: 'daily', createdAt: 1),
      _q(id: 'w1', title: 'Weekly', frequency: 'weekly', createdAt: 4),
      _q(id: 'o1', title: 'One-time', frequency: 'none', createdAt: 2),
      _q(id: 'm1', title: 'Monthly', frequency: 'monthly', createdAt: 3),
    ];

    final filtered = filterAndSortQuests(
      quests: quests,
      isCompleted: false,
      openSessions: const <FocusOpenSession>[],
      sortRules: const [QuestSortRule('latest', false)],
      typeFilter: 'weekly',
    );

    expect(filtered.map((q) => q.id).toList(), ['w1']);
  });
}
