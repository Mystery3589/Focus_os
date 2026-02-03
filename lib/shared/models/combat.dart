import 'inventory_item.dart';
import 'user_stats.dart';

/// A combat-ready enemy template.
///
/// This is intentionally UI-agnostic (no Colors) so it can be used by services/tests.
class CombatEnemy {
  final String id;
  final String name;
  final String description;
  /// Common / Intermediate / Advanced / Elite
  final String tier;
  final Stats stats;
  final int expReward;
  final int goldReward;

  const CombatEnemy({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.stats,
    required this.expReward,
    required this.goldReward,
  });
}

/// Result of attempting a single fight.
class CombatResult {
  final bool executed;
  final bool won;

  final String enemyId;
  final String enemyName;

  final int hpBefore;
  final int hpAfter;
  final int mpBefore;
  final int mpAfter;

  final int expGained;
  final int goldGained;
  final List<InventoryItem> itemDrops;
  final List<Equipment> equipmentDrops;

  /// For UI/debugging.
  final double winChance;
  final String message;

  const CombatResult({
    required this.executed,
    required this.won,
    required this.enemyId,
    required this.enemyName,
    required this.hpBefore,
    required this.hpAfter,
    required this.mpBefore,
    required this.mpAfter,
    required this.expGained,
    required this.goldGained,
    required this.itemDrops,
    this.equipmentDrops = const [],
    required this.winChance,
    required this.message,
  });

  int get hpLost => (hpBefore - hpAfter).clamp(0, 1 << 30);
  int get mpSpent => (mpBefore - mpAfter).clamp(0, 1 << 30);
}
