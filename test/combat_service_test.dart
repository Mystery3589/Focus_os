import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/models/combat.dart';
import 'package:focus_flutter/shared/models/user_stats.dart';
import 'package:focus_flutter/shared/services/combat_service.dart';

void main() {
  test('Mission progress boost mapping is stable', () {
    expect(CombatService.missionProgressBoostForTier('Common'), 5);
    expect(CombatService.missionProgressBoostForTier('Intermediate'), 8);
    expect(CombatService.missionProgressBoostForTier('Advanced'), 12);
    expect(CombatService.missionProgressBoostForTier('Elite'), 15);
    expect(CombatService.missionProgressBoostForTier('unknown'), 5);
  });

  test('CombatService never produces negative HP/MP', () {
    final player = UserStats.initial().copyWith(
      level: 10,
      hp: 25,
      mp: 3,
      stats: Stats(str: 10, agi: 10, per: 10, intStat: 10, vit: 10),
    );

    final enemy = CombatEnemy(
      id: 'enemy-test',
      name: 'Test Dummy',
      description: 'A harmless training target.',
      tier: 'Common',
      stats: Stats(str: 1, agi: 1, per: 1, intStat: 1, vit: 1),
      expReward: 10,
      goldReward: 5,
    );

    final result = CombatService.simulateFight(player: player, enemy: enemy, rng: Random(1));

    expect(result.executed, isTrue);
    expect(result.hpAfter, greaterThanOrEqualTo(0));
    expect(result.mpAfter, greaterThanOrEqualTo(0));
    expect(result.hpAfter, lessThanOrEqualTo(result.hpBefore));
    expect(result.mpAfter, lessThanOrEqualTo(result.mpBefore));
  });

  test('Rewards are only granted on victory', () {
    final strongPlayer = UserStats.initial().copyWith(
      level: 60,
      hp: 100,
      mp: 50,
      stats: Stats(str: 200, agi: 200, per: 150, intStat: 150, vit: 200),
    );

    final weakPlayer = UserStats.initial().copyWith(
      level: 1,
      hp: 100,
      mp: 0,
      stats: Stats(str: 5, agi: 5, per: 5, intStat: 5, vit: 5),
    );

    final easyEnemy = CombatEnemy(
      id: 'enemy-easy',
      name: 'Goblin Scout',
      description: 'Weak enemy for testing.',
      tier: 'Common',
      stats: Stats(str: 10, agi: 10, per: 10, intStat: 5, vit: 10),
      expReward: 100,
      goldReward: 50,
    );

    final hardEnemy = CombatEnemy(
      id: 'enemy-hard',
      name: 'Beru',
      description: 'Overpowered enemy for testing.',
      tier: 'Elite',
      stats: Stats(str: 180, vit: 280, agi: 350, intStat: 200, per: 230),
      expReward: 150000,
      goldReward: 100000,
    );

    // Seed chosen to be stable. If this ever flakes, the assertions below still
    // validate the reward invariant.
    final winResult = CombatService.simulateFight(player: strongPlayer, enemy: easyEnemy, rng: Random(7));
    if (winResult.won) {
      expect(winResult.expGained, greaterThanOrEqualTo(easyEnemy.expReward));
      expect(winResult.goldGained, greaterThanOrEqualTo(easyEnemy.goldReward));
    } else {
      expect(winResult.expGained, 0);
      expect(winResult.goldGained, 0);
    }

    final lossResult = CombatService.simulateFight(player: weakPlayer, enemy: hardEnemy, rng: Random(3));
    if (lossResult.won) {
      expect(lossResult.expGained, greaterThanOrEqualTo(hardEnemy.expReward));
      expect(lossResult.goldGained, greaterThanOrEqualTo(hardEnemy.goldReward));
    } else {
      expect(lossResult.expGained, 0);
      expect(lossResult.goldGained, 0);
    }
  });

  test('Daily arena contracts are deterministic for a fixed date/seed', () {
    final player = UserStats.initial().copyWith(
      name: 'Tester',
      level: 12,
      stats: Stats(str: 18, agi: 12, per: 11, intStat: 9, vit: 16),
    );

    final a = CombatService.generateDailyArenaContracts(
      player: player,
      date: DateTime(2026, 2, 3),
      count: 24,
      seedOverride: 20260203,
    );
    final b = CombatService.generateDailyArenaContracts(
      player: player,
      date: DateTime(2026, 2, 3),
      count: 24,
      seedOverride: 20260203,
    );

    expect(a.length, 24);
    expect(b.length, 24);
    expect(a.first.id, b.first.id);
    expect(a.first.name, b.first.name);
    expect(a.first.expReward, b.first.expReward);

    // Sanity: tiers and rewards are present.
    for (final e in a) {
      expect(e.name, isNotEmpty);
      expect(e.description, isNotEmpty);
      expect(e.expReward, greaterThan(0));
      expect(e.goldReward, greaterThanOrEqualTo(0));
      expect(
        ['Common', 'Intermediate', 'Advanced', 'Elite'].map((t) => t.toLowerCase()).contains(e.tier.toLowerCase()),
        isTrue,
      );
    }
  });
}
