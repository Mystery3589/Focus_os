
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/equipment_card.dart';
import '../../shared/models/user_stats.dart'; // import for accessing equipment model helper if needed
import '../../shared/widgets/page_container.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({super.key});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);
    final equippedItems = userStats.equipment.where((e) => e.equipped).toList();
    // Assuming inventory logic is stored differently or we filter plain inventory items that are equipment
    // For now using the same 'equipment' list but unequipped, or userStats.inventory (which are InventoryItems)
    // The web app had 'equippedItems' separate from 'inventoryItems' mock data.
    // In our model `UserStats` has `equipment` list (Equipment objects) and `inventory` (InventoryItem objects).
    // Let's assume for this UI we display `userStats.equipment` filtered by equipped status.
    // Real implementation requires linking InventoryItems to Equipment slots.
    
    // Fallback display if empty
    final unequippedItems = userStats.equipment.where((e) => !e.equipped).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: const Text("Equipment", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: const [
          AiInboxBellAction(),
        ],
      ),
      body: PageEntrance(
        child: SingleChildScrollView(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "EQUIPMENT STATS",
                      style: TextStyle(
                        color: AppTheme.primary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 18,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _buildStatBonus(LucideIcons.shield, "STR", userStats.stats.str, 0),
                        _buildStatBonus(LucideIcons.zap, "AGI", userStats.stats.agi, 0),
                        _buildStatBonus(LucideIcons.eye, "PER", userStats.stats.per, 0),
                        _buildStatBonus(LucideIcons.brain, "INT", userStats.stats.intStat, 0),
                        _buildStatBonus(LucideIcons.heart, "VIT", userStats.stats.vit, 0),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              CyberCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primary,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "Equipped"),
                    Tab(text: "Inventory"),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // NOTE: This screen is wrapped in a SingleChildScrollView.
              // TabBarView is a horizontal viewport and requires a bounded height,
              // otherwise Flutter throws: "Horizontal viewport was given unbounded height".
              // Since our tab contents are already non-scrollable + shrink-wrapped,
              // we can swap the content manually based on the TabController.
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  final idx = _tabController.index;
                  if (idx == 0) return _equipmentGrid(equippedItems);
                  return _equipmentGrid(unequippedItems);
                },
              ),

              const SizedBox(height: 16),
              _SetBonusSection(setBonuses: _collectSetBonuses(userStats.equipment)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_SetBonusInfo> _collectSetBonuses(List<Equipment> items) {
    final bySet = <String, List<Equipment>>{};
    for (final e in items) {
      final key = e.setBonus.trim();
      if (key.isEmpty || key.toLowerCase() == 'none') continue;
      bySet.putIfAbsent(key, () => []).add(e);
    }

    return bySet.entries.map((entry) {
      final equippedCount = entry.value.where((e) => e.equipped).length;
      return _SetBonusInfo(
        title: entry.key,
        equippedCount: equippedCount,
        totalCount: entry.value.length,
      );
    }).toList()
      ..sort((a, b) => b.equippedCount.compareTo(a.equippedCount));
  }

  Widget _equipmentGrid(List<Equipment> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: CyberCard(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              "No items",
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxExtent = constraints.maxWidth >= 980 ? 560.0 : 520.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            childAspectRatio: 1.35,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return EquipmentCard(
              name: item.name,
              rarity: item.rarity,
              stats: item.stats,
              setBonus: item.setBonus,
              slot: item.slot,
            );
          },
        );
      },
    );
  }

  Widget _buildStatBonus(IconData icon, String name, int base, int bonus) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            children: [
              TextSpan(text: "$base"),
              if (bonus > 0)
                TextSpan(text: " +$bonus", style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
            ],
          ),
        )
      ],
    );
  }
}

class _SetBonusInfo {
  final String title;
  final int equippedCount;
  final int totalCount;

  const _SetBonusInfo({
    required this.title,
    required this.equippedCount,
    required this.totalCount,
  });
}

class _SetBonusSection extends StatelessWidget {
  final List<_SetBonusInfo> setBonuses;

  const _SetBonusSection({required this.setBonuses});

  @override
  Widget build(BuildContext context) {
    if (setBonuses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "SET BONUSES",
          style: TextStyle(
            color: AppTheme.primary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final tileWidth = wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: setBonuses.map((b) {
                return SizedBox(
                  width: tileWidth,
                  child: CyberCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${b.title} (${b.equippedCount}/${b.totalCount})",
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Equip more pieces to unlock bonuses.",
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
