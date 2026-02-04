import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/models/combat.dart';
import '../../shared/models/user_stats.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/combat_service.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';

class CombatScreen extends ConsumerStatefulWidget {
  const CombatScreen({super.key});

  @override
  ConsumerState<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends ConsumerState<CombatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _enemySearch = TextEditingController();
  String? _boostQuestId;
  late TabController _tabController;

  static const _tabContracts = 0;
  static const _tabBosses = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _enemySearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);

    final contracts = CombatService.generateDailyArenaContracts(player: userStats, count: 24);
    final bosses = _enemyData;

    final allEnemies = _tabController.index == _tabBosses ? bosses : contracts;

    final query = _enemySearch.text.trim().toLowerCase();
    final enemies = query.isEmpty
        ? allEnemies
        : allEnemies
            .where((e) =>
                e.name.toLowerCase().contains(query) ||
                e.description.toLowerCase().contains(query) ||
                e.tier.toLowerCase().contains(query))
            .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Combat Arena', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: [
          const AiInboxBellAction(),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Chip(
              backgroundColor: AppTheme.cardBg,
              label: Text('Gold: ${userStats.gold}', style: const TextStyle(color: AppTheme.textPrimary)),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ],
      ),
      body: PageEntrance(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            CyberCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: const [
                  Icon(LucideIcons.heartPulse, color: AppTheme.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Automatic Recovery System: Restores 10% HP/MP every 5 minutes. Works offline.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CyberCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select an Enemy', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Choose an enemy to fight in the arena', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 10),
                  CyberCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppTheme.primary,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondary,
                      dividerColor: Colors.transparent,
                      onTap: (_) => setState(() {}),
                      tabs: const [
                        Tab(text: 'Contracts'),
                        Tab(text: 'Bosses'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _enemySearch,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search enemies...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _TierChip(label: 'Common (0-20)', tierColor: Colors.blueGrey),
                      _TierChip(label: 'Intermediate (21-40)', tierColor: Colors.indigo),
                      _TierChip(label: 'Advanced (41-60)', tierColor: Colors.deepPurple),
                      _TierChip(label: 'Elite (61+)', tierColor: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tabController.index == _tabBosses
                        ? 'Bosses are fixed. Contracts refresh daily and scale to you.'
                        : 'Contracts refresh daily and scale to you. Rewards are adaptive.'
                    ,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  _buildMissionBoostPicker(userStats),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // On narrow screens the tiles become too short to hold the full
                // enemy card content, causing vertical overflows. Prefer a
                // single column list-like layout on phones.
                final crossAxisCount = width >= 900
                    ? 4
                    : width >= 650
                        ? 3
                        : width >= 520
                            ? 2
                            : 1;

                final childAspectRatio = width >= 900
                    ? 1.28
                    : width >= 650
                        ? 1.22
                        : width >= 520
                            ? 1.12
                            : 1.05;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: enemies.length,
                  itemBuilder: (context, index) {
                    final enemy = enemies[index];
                    final tierColor = _tierColor(enemy.tier);
                    return CyberCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  enemy.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _TierPill(label: enemy.tier, color: tierColor),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            enemy.description,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _statChip('STR', enemy.stats.str),
                              _statChip('VIT', enemy.stats.vit),
                              _statChip('AGI', enemy.stats.agi),
                              _statChip('INT', enemy.stats.intStat),
                              _statChip('PER', enemy.stats.per),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('EXP Reward', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                    Text('${enemy.expReward}', style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Gold Reward', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                    Text('${enemy.goldReward}', style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                final result = ref.read(userProvider.notifier).fightEnemy(enemy);

                                int boosted = 0;
                                if (result.executed && result.won && _boostQuestId != null) {
                                  boosted = ref.read(userProvider.notifier).boostQuestProgressFromCombat(
                                        questId: _boostQuestId!,
                                        enemy: enemy,
                                      );
                                }

                                final dropsText = result.itemDrops.isEmpty
                                    ? ''
                                    : ' Drops: ${result.itemDrops.map((d) => d.name).join(', ')}.';

                                final eqText = result.equipmentDrops.isEmpty
                                  ? ''
                                  : ' Gear: ${result.equipmentDrops.map((e) => e.name).join(', ')}.';

                                final rewardText = result.won
                                    ? ' +${result.expGained} XP, +${result.goldGained} gold.'
                                    : '';

                                final resourceText = result.executed
                                    ? ' (-${result.hpLost} HP, -${result.mpSpent} MP.)'
                                    : '';

                                final boostText = boosted > 0 ? ' Mission progress +$boosted%.' : '';

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${result.message}$resourceText$rewardText$boostText$dropsText$eqText'),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                side: const BorderSide(color: AppTheme.borderColor),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('Fight'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            CyberCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Stats', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _barRow('HP', userStats.hp, userStats.maxHp, AppTheme.primary),
                  const SizedBox(height: 8),
                  _barRow('MP', userStats.mp, userStats.maxMp, AppTheme.primary),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _statChip('STR', userStats.stats.str),
                      _statChip('VIT', userStats.stats.vit),
                      _statChip('AGI', userStats.stats.agi),
                      _statChip('INT', userStats.stats.intStat),
                      _statChip('PER', userStats.stats.per),
                    ],
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text('$label $value', style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _barRow(String label, int current, int max, Color color) {
    final percent = max <= 0 ? 0.0 : current / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            Text('$current/$max', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percent,
          minHeight: 6,
          backgroundColor: AppTheme.borderColor,
          color: color,
        ),
      ],
    );
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'common':
        return Colors.blueGrey;
      case 'intermediate':
        return Colors.indigo;
      case 'advanced':
        return Colors.deepPurple;
      case 'elite':
        return Colors.orange;
      default:
        return AppTheme.textSecondary;
    }
  }

  Widget _buildMissionBoostPicker(UserStats userStats) {
    final available = userStats.quests.where((q) => !q.completed).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Optional: boost a mission on victory',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (available.isEmpty)
          const Text(
            'No active missions found.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          )
        else
          DropdownButtonFormField<String?>(
            value: _boostQuestId,
            dropdownColor: AppTheme.background,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
            ),
            hint: const Text('No mission boost', style: TextStyle(color: AppTheme.textSecondary)),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No mission boost'),
              ),
              ...available.map(
                (q) => DropdownMenuItem<String?>(
                  value: q.id,
                  child: Text(
                    q.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (val) => setState(() => _boostQuestId = val),
          ),
      ],
    );
  }
}

class _TierChip extends StatelessWidget {
  final String label;
  final Color tierColor;

  const _TierChip({required this.label, required this.tierColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(label, style: TextStyle(color: tierColor, fontSize: 11)),
    );
  }
}

class _TierPill extends StatelessWidget {
  final String label;
  final Color color;

  const _TierPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

final _enemyData = <CombatEnemy>[
  CombatEnemy(
    id: 'enemy-goblin-scout',
    name: 'Goblin Scout',
    description: 'A small, green-skinned creature. Weak individually but dangerous in groups.',
    tier: 'Common',
    stats: Stats(str: 12, vit: 10, agi: 12, intStat: 5, per: 10),
    expReward: 100,
    goldReward: 50,
  ),
  CombatEnemy(
    id: 'enemy-steel-fanged-lycan',
    name: 'Steel-fanged Lycan',
    description: 'A wolf-like creature with fangs as hard as steel. They hunt in packs.',
    tier: 'Intermediate',
    stats: Stats(str: 22, vit: 18, agi: 28, intStat: 5, per: 15),
    expReward: 400,
    goldReward: 200,
  ),
  CombatEnemy(
    id: 'enemy-giant-swamp-spider',
    name: 'Giant Swamp Spider',
    description: 'A massive arachnid that lurks in the shadows of dungeons.',
    tier: 'Intermediate',
    stats: Stats(str: 15, vit: 40, agi: 20, intStat: 10, per: 25),
    expReward: 1000,
    goldReward: 500,
  ),
  CombatEnemy(
    id: 'enemy-cerberus',
    name: 'Cerberus, Keeper of Hell',
    description: 'A three-headed guardian of the Demon Castle lower floors.',
    tier: 'Elite',
    stats: Stats(str: 60, vit: 80, agi: 35, intStat: 20, per: 40),
    expReward: 2500,
    goldReward: 1200,
  ),
  CombatEnemy(
    id: 'enemy-igris',
    name: 'Blood-Red Commander Igris',
    description: 'The commander of the undead army and the final trial of the job change quest.',
    tier: 'Elite',
    stats: Stats(str: 110, vit: 90, agi: 120, intStat: 50, per: 80),
    expReward: 10000,
    goldReward: 5600,
  ),
  CombatEnemy(
    id: 'enemy-kargalgan',
    name: 'Kargalgan, High Orc Shaman',
    description: 'Leader of the High Orcs and a master of dark magic. His curses weaken even the strongest.',
    tier: 'Elite',
    stats: Stats(str: 90, vit: 100, agi: 70, intStat: 200, per: 130),
    expReward: 25000,
    goldReward: 15000,
  ),
  CombatEnemy(
    id: 'enemy-baran',
    name: 'Baran, the Demon King',
    description: 'The ruler of the Demon Castle. He commands lightning and fire.',
    tier: 'Elite',
    stats: Stats(str: 130, vit: 180, agi: 130, intStat: 220, per: 140),
    expReward: 50000,
    goldReward: 30000,
  ),
  CombatEnemy(
    id: 'enemy-beru',
    name: 'Beru, the Ant King',
    description: 'A predator evolved for hunting. Terrifying speed and strength.',
    tier: 'Elite',
    stats: Stats(str: 180, vit: 280, agi: 350, intStat: 200, per: 230),
    expReward: 150000,
    goldReward: 100000,
  ),
];
