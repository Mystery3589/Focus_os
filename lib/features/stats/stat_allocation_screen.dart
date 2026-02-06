import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';

class StatAllocationScreen extends ConsumerWidget {
  const StatAllocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final canSpend = user.statPoints > 0;

    Widget statRow({
      required String label,
      required String keyName,
      required int value,
      required String hint,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label: $value',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: canSpend ? 'Allocate 1 point' : 'No points available',
              onPressed: canSpend ? () => ref.read(userProvider.notifier).allocateStat(keyName) : null,
              icon: Icon(
                LucideIcons.plusCircle,
                color: canSpend ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Allocate Points',
          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CyberCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Available points',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                Text(
                  '${user.statPoints}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CyberCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Stats',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                statRow(
                  label: 'STR',
                  keyName: 'str',
                  value: user.stats.str,
                  hint: 'Physical power and grit.',
                ),
                statRow(
                  label: 'AGI',
                  keyName: 'agi',
                  value: user.stats.agi,
                  hint: 'Speed and nimbleness.',
                ),
                statRow(
                  label: 'PER',
                  keyName: 'per',
                  value: user.stats.per,
                  hint: 'Awareness and precision.',
                ),
                statRow(
                  label: 'INT',
                  keyName: 'int',
                  value: user.stats.intStat,
                  hint: 'Increases Max MP.',
                ),
                statRow(
                  label: 'VIT',
                  keyName: 'vit',
                  value: user.stats.vit,
                  hint: 'Increases Max HP.',
                ),
                if (!canSpend) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Earn points by leveling up (1 point every 5 levels) or from mission rewards.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
