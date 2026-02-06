import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/models/focus_event.dart';
import 'package:focus_flutter/shared/models/focus_session.dart';
import 'package:focus_flutter/shared/models/quest.dart';
import 'package:focus_flutter/shared/models/skill.dart';
import 'package:focus_flutter/shared/models/user_event.dart';
import 'package:focus_flutter/shared/models/user_stats.dart';
import 'package:focus_flutter/shared/services/job_title_unlock_service.dart';

const _jobCatalog = <String>[
  'Novice',
  'Apprentice',
  'Adventurer',
  'Scout',
  'Tactician',
  'Artisan',
  'Scholar',
  'Sentinel',
  'Pathfinder',
  'Strategist',
  'Warden',
  'Chronomancer',
  'Seeker',
  'Craftmaster',
  'Field Medic',
  'Navigator',
  'Archivist',
  'Vanguard',
  'Ranger',
  'Commander',
];

const _titleCatalog = <String>[
  'Rookie',
  'The Focused',
  'The Patient',
  'The Persistent',
  'The Steady',
  'Task Breaker',
  'Timekeeper',
  'Momentum Builder',
  'Mindful Worker',
  'Storm Calmer',
  'The Unshaken',
  'The Reliable',
  'The Determined',
  'The Prepared',
  'The Unstoppable',
  'The Disciplined',
  'The Strategist',
  'The Builder',
  'The Finisher',
  'The Quiet Force',
];

Quest _q({
  required String id,
  bool completed = false,
  int? completedAt,
  String difficulty = 'B',
  String priority = 'Medium',
  String? frequency,
  int? expectedMinutes,
  int? dueDateMs,
}) {
  return Quest(
    id: id,
    title: 'Quest $id',
    description: 'desc',
    reward: 'reward',
    progress: completed ? 100 : 0,
    difficulty: difficulty,
    priority: priority,
    expiry: '',
    expReward: 0,
    statPointsReward: 0,
    active: false,
    completed: completed,
    frequency: frequency,
    expectedMinutes: expectedMinutes,
    dueDateMs: dueDateMs,
    completedAt: completedAt,
  );
}

FocusSessionLogEntry _log({
  required String id,
  required int endedAt,
  required int totalMs,
}) {
  return FocusSessionLogEntry(
    id: id,
    questId: 'q-$id',
    startedAt: endedAt - totalMs,
    endedAt: endedAt,
    segments: const [],
    totalMs: totalMs,
    earnedExp: 0,
  );
}

FocusEvent _ev(String type, int atMs) {
  return FocusEvent(id: 'e-$type-$atMs', type: type, atMs: atMs);
}

SkillGoal _skill(String id) {
  return SkillGoal(id: id, title: 'Skill $id', missions: const [], level: 1, exp: 0);
}

UserEvent _uev(String id, int atMs) {
  return UserEvent(
    id: id,
    title: 'Event $id',
    startAtMs: atMs,
    allDay: true,
    remind: false,
    remindMinutesBefore: 0,
  );
}

void main() {
  test('level 3 unlocks Apprentice job', () {
    final stats = UserStats.initial().copyWith(
      level: 3,
      unlockedJobs: const ['Novice'],
      unlockedTitles: const ['Rookie'],
      nextJobTitleGrantAtMs: null,
    );

    final unlocks = JobTitleUnlockService.computeUnlocks(
      stats: stats,
      jobCatalog: _jobCatalog,
      titleCatalog: _titleCatalog,
      nowMs: 1,
    );

    expect(unlocks.any((u) => u.type == UnlockType.job && u.name == 'Apprentice'), isTrue);
    expect(unlocks.any((u) => u.type == UnlockType.title), isFalse);
  });

  test('2 hours total focus unlocks The Focused title', () {
    final now = 1000000;
    final focus = UserStats.initial().focus.copyWith(
      history: [_log(id: '1', endedAt: now, totalMs: 2 * 60 * 60 * 1000)],
    );

    final stats = UserStats.initial().copyWith(
      focus: focus,
      unlockedJobs: const ['Novice'],
      unlockedTitles: const ['Rookie'],
    );

    final unlocks = JobTitleUnlockService.computeUnlocks(
      stats: stats,
      jobCatalog: _jobCatalog,
      titleCatalog: _titleCatalog,
      nowMs: now,
    );

    expect(unlocks.any((u) => u.type == UnlockType.title && u.name == 'The Focused'), isTrue);
  });

  test('5 completed missions unlocks Adventurer job', () {
    final now = 2000000;
    final quests = List.generate(
      5,
      (i) => _q(id: 'c$i', completed: true, completedAt: now),
    );

    final stats = UserStats.initial().copyWith(
      quests: quests,
      completedQuests: quests.map((q) => q.id).toList(),
      unlockedJobs: const ['Novice'],
      unlockedTitles: const ['Rookie'],
    );

    final unlocks = JobTitleUnlockService.computeUnlocks(
      stats: stats,
      jobCatalog: _jobCatalog,
      titleCatalog: _titleCatalog,
      nowMs: now,
    );

    expect(unlocks.any((u) => u.type == UnlockType.job && u.name == 'Adventurer'), isTrue);
    expect(unlocks.any((u) => u.type == UnlockType.job && u.name == 'Scout'), isFalse);
  });

  test('late-game snapshot unlocks Commander job', () {
    final now = 3000000;

    final quests = List.generate(
      120,
      (i) => _q(id: 'q$i', completed: true, completedAt: now),
    );

    // 6000 focus minutes == 100 hours.
    final focus = UserStats.initial().focus.copyWith(
      history: [_log(id: 'big', endedAt: now, totalMs: 6000 * 60 * 1000)],
    );

    final stats = UserStats.initial().copyWith(
      level: 25,
      quests: quests,
      completedQuests: quests.map((q) => q.id).toList(),
      focus: focus,
      skills: [_skill('s1'), _skill('s2'), _skill('s3'), _skill('s4'), _skill('s5'), _skill('s6')],
      userEvents: List.generate(30, (i) => _uev('e$i', now)),
      focusEvents: [
        for (var i = 0; i < 30; i++) _ev('break_taken', now),
      ],
      unlockedJobs: const ['Novice'],
      unlockedTitles: const ['Rookie'],
    );

    final unlocks = JobTitleUnlockService.computeUnlocks(
      stats: stats,
      jobCatalog: _jobCatalog,
      titleCatalog: _titleCatalog,
      nowMs: now,
    );

    expect(unlocks.any((u) => u.type == UnlockType.job && u.name == 'Commander'), isTrue);
  });
}
