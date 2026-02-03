import 'dart:math';

import '../models/combat.dart';
import '../models/inventory_item.dart';
import '../models/user_stats.dart';

class CombatService {
  const CombatService._();

  /// Procedural daily arena opponents ("Contracts").
  ///
  /// This is an offline-friendly "AI director": it generates opponents scaled
  /// to the player's current power and a date-based seed so the list changes
  /// daily but is stable within a day.
  static List<CombatEnemy> generateDailyArenaContracts({
    required UserStats player,
    DateTime? date,
    int count = 24,
    int? seedOverride,
  }) {
    final d = date ?? DateTime.now();
    final daySeed = seedOverride ?? (d.year * 10000 + d.month * 100 + d.day);

    // Mix in player stats so different builds get slightly different offerings.
    int mix = 0;
    mix ^= player.level * 73856093;
    mix ^= player.stats.str * 19349663;
    mix ^= player.stats.agi * 83492791;
    mix ^= player.stats.per * 2971215073;
    mix ^= player.stats.intStat * 577;
    mix ^= player.stats.vit * 911;

    final rng = Random((daySeed ^ mix) & 0x7fffffff);

    final playerPower = _playerPower(player);
    final n = count.clamp(6, 60);

    final out = <CombatEnemy>[];
    for (int i = 0; i < n; i++) {
      // Target difficulty ratio.
      // Most contracts are fair fights; a few are underdog/high reward.
      final roll = rng.nextDouble();
      final ratio = roll < 0.10
          ? (0.55 + rng.nextDouble() * 0.15) // easy
          : roll < 0.85
              ? (0.75 + rng.nextDouble() * 0.30) // normal
              : (1.05 + rng.nextDouble() * 0.25); // hard

      final targetPower = max(12.0, playerPower * ratio);

      final archetypes = <_Archetype>[
        const _Archetype(
          name: 'Swift Stalker',
          desc: 'A fast hunter that punishes slow reactions.',
          weights: [0.9, 1.35, 0.9, 0.7, 0.85],
        ),
        const _Archetype(
          name: 'Stonehide Brute',
          desc: 'A tanky foe that wins wars of attrition.',
          weights: [1.25, 0.75, 0.8, 0.6, 1.35],
        ),
        const _Archetype(
          name: 'Hex Adept',
          desc: 'A caster-type enemy with trickier patterns.',
          weights: [0.65, 0.85, 0.95, 1.40, 0.85],
        ),
        const _Archetype(
          name: 'Keen-eyed Sniper',
          desc: 'Accurate and punishing when you misstep.',
          weights: [0.75, 0.95, 1.40, 0.7, 0.8],
        ),
        const _Archetype(
          name: 'Balanced Raider',
          desc: 'A solid all-rounder with no clear weakness.',
          weights: [1.0, 1.0, 1.0, 1.0, 1.0],
        ),
      ];

      final arch = archetypes[rng.nextInt(archetypes.length)];
      final tier = _tierForContract(playerPower: playerPower, enemyPower: targetPower);

      // Convert targetPower into a reasonable Stats set.
      // We build a baseline and then apply archetype weights + jitter.
      final baseline = max(6, (targetPower / 5.3).round());
      final jitter = () => 0.85 + rng.nextDouble() * 0.30;

      final str = max(1, (baseline * arch.weights[0] * jitter()).round());
      final agi = max(1, (baseline * arch.weights[1] * jitter()).round());
      final per = max(1, (baseline * arch.weights[2] * jitter()).round());
      final intStat = max(1, (baseline * arch.weights[3] * jitter()).round());
      final vit = max(1, (baseline * arch.weights[4] * jitter()).round());

      // Reward baseline scales with enemy power and tier.
      final baseXp = max(15, (targetPower * 3.8).round());
      final baseGold = max(5, (targetPower * 1.6).round());

      // Tier bumps help signal progression.
      final tierMult = switch (tier.toLowerCase()) {
        'elite' => 1.55,
        'advanced' => 1.25,
        'intermediate' => 1.05,
        _ => 0.90,
      };

      final xp = max(10, (baseXp * tierMult).round());
      final gold = max(0, (baseGold * (tierMult - 0.10)).round());

      out.add(
        CombatEnemy(
          id: 'contract-$daySeed-$i',
          name: arch.name,
          description: arch.desc,
          tier: tier,
          stats: Stats(str: str, agi: agi, per: per, intStat: intStat, vit: vit),
          expReward: xp,
          goldReward: gold,
        ),
      );
    }

    // Stable ordering by tier then xp.
    out.sort((a, b) {
      final ta = _tierRank(a.tier);
      final tb = _tierRank(b.tier);
      if (ta != tb) return ta.compareTo(tb);
      return a.expReward.compareTo(b.expReward);
    });

    return out;
  }

  static int _tierRank(String tier) {
    switch (tier.toLowerCase()) {
      case 'common':
        return 0;
      case 'intermediate':
        return 1;
      case 'advanced':
        return 2;
      case 'elite':
        return 3;
      default:
        return 0;
    }
  }

  static String _tierForContract({required double playerPower, required double enemyPower}) {
    if (playerPower <= 0) return 'Common';
    final ratio = enemyPower / playerPower;
    if (ratio < 0.78) return 'Common';
    if (ratio < 0.98) return 'Intermediate';
    if (ratio < 1.15) return 'Advanced';
    return 'Elite';
  }

  static double _playerPower(UserStats player) {
    double p = 0;
    p += player.stats.str * 1.35;
    p += player.stats.agi * 1.10;
    p += player.stats.vit * 1.25;
    p += player.stats.per * 0.85;
    p += player.stats.intStat * 0.75;
    p += player.level * 3.0;
    return p;
  }

  static double _enemyPower(CombatEnemy enemy) {
    double e = 0;
    e += enemy.stats.str * 1.35;
    e += enemy.stats.agi * 1.10;
    e += enemy.stats.vit * 1.25;
    e += enemy.stats.per * 0.80;
    e += enemy.stats.intStat * 0.75;
    return e;
  }

  static String _rarityForTierRoll(String tier, double r) {
    final t = tier.toLowerCase();
    // Tuned so loot stays special.
    if (t == 'elite') {
      if (r < 0.04) return 'Legendary';
      if (r < 0.14) return 'Epic';
      if (r < 0.34) return 'Rare';
      if (r < 0.70) return 'Uncommon';
      return 'Common';
    }
    if (t == 'advanced') {
      if (r < 0.02) return 'Legendary';
      if (r < 0.08) return 'Epic';
      if (r < 0.22) return 'Rare';
      if (r < 0.60) return 'Uncommon';
      return 'Common';
    }
    if (t == 'intermediate') {
      if (r < 0.01) return 'Legendary';
      if (r < 0.04) return 'Epic';
      if (r < 0.12) return 'Rare';
      if (r < 0.45) return 'Uncommon';
      return 'Common';
    }
    // Common
    if (r < 0.01) return 'Epic';
    if (r < 0.04) return 'Rare';
    if (r < 0.25) return 'Uncommon';
    return 'Common';
  }

  static int _rarityStatBudget(String rarity) {
    switch (rarity) {
      case 'Legendary':
        return 22;
      case 'Epic':
        return 14;
      case 'Rare':
        return 9;
      case 'Uncommon':
        return 5;
      default:
        return 3;
    }
  }

  static Equipment _generateEquipmentDrop({
    required Random rng,
    required String tier,
    required int playerLevel,
  }) {
    final rarity = _rarityForTierRoll(tier, rng.nextDouble());
    final slotOptions = <String>['Weapon', 'Helmet', 'Chest', 'Gloves', 'Boots', 'Ring', 'Amulet'];
    final slot = slotOptions[rng.nextInt(slotOptions.length)];

    final prefixes = <String>['Abyssal', 'Shadow', 'Stormforged', 'Eclipse', 'Ironbound', 'Arcane', 'Vigilant'];
    final bases = <String>['Blade', 'Guard', 'Harness', 'Grips', 'Greaves', 'Band', 'Sigil'];
    final name = '${prefixes[rng.nextInt(prefixes.length)]} ${bases[rng.nextInt(bases.length)]}';

    final budget = _rarityStatBudget(rarity) + (playerLevel / 12).floor();
    final statKeys = <String>['STR', 'AGI', 'PER', 'INT', 'VIT'];
    statKeys.shuffle(rng);
    final chosen = statKeys.take(rng.nextInt(2) + 2).toList(); // 2-3 stats

    var remaining = budget;
    final stats = <String>[];
    for (int i = 0; i < chosen.length; i++) {
      final isLast = i == chosen.length - 1;
      final part = isLast ? remaining : max(1, (remaining * (0.35 + rng.nextDouble() * 0.25)).round());
      remaining = max(0, remaining - part);
      stats.add('+$part ${chosen[i]}');
      if (remaining <= 0) break;
    }

    // Set bonus: rare-ish and mostly cosmetic for now.
    String setBonus = 'None';
    if (rarity != 'Common' && rng.nextDouble() < 0.18) {
      final sets = <String>['Warden', 'Nightstalker', 'Tempest', 'Runebound'];
      setBonus = sets[rng.nextInt(sets.length)];
    }

    return Equipment(
      id: 'eq-${DateTime.now().millisecondsSinceEpoch}-${rng.nextInt(1 << 20)}',
      name: name,
      rarity: rarity,
      stats: stats,
      setBonus: setBonus,
      slot: slot,
      equipped: false,
    );
  }

  /// How much mission progress (%) to award on victory when a mission is selected.
  ///
  /// Kept intentionally small so combat can't fully replace focus work.
  static int missionProgressBoostForTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'common':
        return 5;
      case 'intermediate':
        return 8;
      case 'advanced':
        return 12;
      case 'elite':
        return 15;
      default:
        return 5;
    }
  }

  /// Simulates a single fight attempt.
  ///
  /// This is designed to be deterministic when provided a seeded [rng] (useful for tests).
  static CombatResult simulateFight({
    required UserStats player,
    required CombatEnemy enemy,
    required Random rng,
  }) {
    final hpBefore = player.hp;
    final mpBefore = player.mp;

    if (hpBefore <= 0) {
      return CombatResult(
        executed: false,
        won: false,
        enemyId: enemy.id,
        enemyName: enemy.name,
        hpBefore: hpBefore,
        hpAfter: hpBefore,
        mpBefore: mpBefore,
        mpAfter: mpBefore,
        expGained: 0,
        goldGained: 0,
        itemDrops: const [],
        equipmentDrops: const [],
        winChance: 0,
        message: 'You are down. Recover some HP first.',
      );
    }

    // --- Power model (simple but stable):
    // Player power scales with stats + level; enemy power comes from enemy stats.
    final playerPower = _playerPower(player);
    final enemyPower = _enemyPower(enemy);

    // MP "ability" cost. Low MP reduces win chance.
    final desiredMpSpend = max(0, (enemyPower / 22).round());
    int mpSpend = 0;
    double mpPenalty = 1.0;
    if (desiredMpSpend > 0 && mpBefore > 0) {
      mpSpend = min(mpBefore, desiredMpSpend);
      if (mpSpend < desiredMpSpend) {
        mpPenalty = 0.80;
      }
    }

    // Win chance via sigmoid on (player - enemy).
    final delta = (playerPower - enemyPower) / 30.0;
    double winChance = 1 / (1 + exp(-delta));
    winChance *= mpPenalty;

    // Clamp so fights are never guaranteed.
    winChance = winChance.clamp(0.05, 0.95);

    final won = rng.nextDouble() < winChance;

    // Damage scales with enemy power; player vitality reduces it a bit.
    final mitigation = (player.stats.vit / 200).clamp(0.0, 0.35);
    final baseLoss = max(1, (enemyPower / 18).round());
    final variance = rng.nextInt(max(2, baseLoss ~/ 2 + 1));

    final rawLoss = won
        ? (baseLoss * 0.70).round() + variance
        : (baseLoss * 1.45).round() + variance;

    final hpLoss = max(0, (rawLoss * (1 - mitigation)).round());

    final hpAfter = max(0, hpBefore - hpLoss);
    final mpAfter = max(0, mpBefore - mpSpend);

    // --- Adaptive rewards ("AI" director):
    // - Reward risky wins (low winChance)
    // - Reward efficient wins (low HP loss)
    // - Keep rewards strictly on victory
    int expGained = 0;
    int goldGained = 0;
    if (won) {
      final underdog = ((0.55 - winChance).clamp(0.0, 0.50)) / 0.50; // 0..1
      final hpLossRate = hpBefore <= 0 ? 1.0 : (hpLoss / hpBefore).clamp(0.0, 1.0);
      final efficiency = (1.0 - hpLossRate).clamp(0.0, 1.0);

      // Bonus ranges: underdog up to +40%, efficiency up to +15%.
      final multiplier = 1.0 + underdog * 0.40 + efficiency * 0.15;

      expGained = max(1, (enemy.expReward * multiplier).round());
      goldGained = max(0, (enemy.goldReward * (1.0 + underdog * 0.35)).round());
    }

    final drops = <InventoryItem>[];
    final equipmentDrops = <Equipment>[];
    if (won) {
      // A little loot spice. Keep it simple and deterministic.
      // Chances intentionally modest so inventory doesn't explode.
      final roll = rng.nextDouble();
      if (roll < 0.12) {
        drops.add(_healthPotion(quantity: 1));
      } else if (roll < 0.20) {
        drops.add(_manaPotion(quantity: 1));
      }

      // Rare: "Rune Fragment" (purely sellable for now).
      if (rng.nextDouble() < 0.03) {
        drops.add(
          InventoryItem(
            id: 'item-rune-fragment',
            name: 'Rune Fragment',
            type: 'Material',
            rarity: 'Uncommon',
            description: 'A shimmering shard. Might be useful for crafting later.',
            quantity: 1,
            value: 25,
          ),
        );
      }

      // NEW: occasional equipment drops.
      // Scales with tier and risk (lower winChance -> slightly higher chance).
      final t = enemy.tier.toLowerCase();
      double baseEqChance = 0.0;
      if (t == 'elite') baseEqChance = 0.14;
      else if (t == 'advanced') baseEqChance = 0.09;
      else if (t == 'intermediate') baseEqChance = 0.06;
      else baseEqChance = 0.03;

      final riskBonus = ((0.50 - winChance).clamp(0.0, 0.45)) / 0.45 * 0.06; // up to +6%
      final eqChance = (baseEqChance + riskBonus).clamp(0.0, 0.25);
      if (rng.nextDouble() < eqChance) {
        equipmentDrops.add(
          _generateEquipmentDrop(
            rng: rng,
            tier: enemy.tier,
            playerLevel: player.level,
          ),
        );
      }
    }

    final msg = won
        ? 'Victory against ${enemy.name}!'
        : 'Defeat… ${enemy.name} was too strong.';

    return CombatResult(
      executed: true,
      won: won,
      enemyId: enemy.id,
      enemyName: enemy.name,
      hpBefore: hpBefore,
      hpAfter: hpAfter,
      mpBefore: mpBefore,
      mpAfter: mpAfter,
      expGained: expGained,
      goldGained: goldGained,
      itemDrops: drops,
      equipmentDrops: equipmentDrops,
      winChance: winChance,
      message: msg,
    );
  }

  static InventoryItem _healthPotion({required int quantity}) {
    return InventoryItem(
      id: 'item-health-potion',
      name: 'Health Potion',
      type: 'Consumable',
      rarity: 'Common',
      description: 'Restores 100 HP when consumed.',
      quantity: quantity,
      stats: ItemStats(hp: 100),
      value: 15,
    );
  }

  static InventoryItem _manaPotion({required int quantity}) {
    return InventoryItem(
      id: 'item-mana-potion',
      name: 'Mana Potion',
      type: 'Consumable',
      rarity: 'Common',
      description: 'Restores 50 MP when consumed.',
      quantity: quantity,
      stats: ItemStats(mp: 50),
      value: 12,
    );
  }
}

class _Archetype {
  final String name;
  final String desc;
  /// [STR, AGI, PER, INT, VIT]
  final List<double> weights;

  const _Archetype({
    required this.name,
    required this.desc,
    required this.weights,
  });
}
