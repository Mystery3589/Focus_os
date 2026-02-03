
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'cyber_card.dart';

class EquipmentCard extends StatelessWidget {
  final String name;
  final String rarity; // "Common", "Uncommon", "Rare", "Epic", "Legendary"
  final List<String> stats;
  final String setBonus;
  final String slot;

  const EquipmentCard({
    super.key,
    required this.name,
    required this.rarity,
    required this.stats,
    required this.setBonus,
    required this.slot,
  });

  Color get _rarityColor {
    switch (rarity) {
      case "Common": return Colors.grey;
      case "Uncommon": return Colors.greenAccent;
      case "Rare": return AppTheme.primary;
      case "Epic": return Colors.purpleAccent;
      case "Legendary": return Colors.yellowAccent;
      default: return Colors.grey;
    }
  }

  LinearGradient get _gradient {
     switch (rarity) {
      case "Common": return LinearGradient(colors: [Colors.grey[700]!, Colors.grey[800]!]);
      case "Uncommon": return LinearGradient(colors: [Colors.green, Colors.green[800]!]);
      case "Rare": return LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.6)]);
      case "Epic": return LinearGradient(colors: [Colors.purple, Colors.purple[800]!]);
      case "Legendary": return LinearGradient(colors: [Colors.amber, Colors.amber[800]!]);
      default: return const LinearGradient(colors: [Colors.grey, Colors.black]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CyberCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               // Rarity Bar
               Container(
                 height: 4,
                 decoration: BoxDecoration(
                   gradient: _gradient,
                 ),
               ),
               Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Header
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Expanded(
                           child: Text(
                             name,
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                               color: _rarityColor,
                             ),
                           ),
                         ),
                         Text(
                           slot,
                           style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                         ),
                       ],
                     ),
                     Text(
                       rarity,
                       style: TextStyle(color: _rarityColor, fontSize: 12),
                     ),
                     const SizedBox(height: 12),
                     
                     // Stats
                     ...stats.map((stat) => Padding(
                       padding: const EdgeInsets.only(bottom: 4.0),
                       child: Text(stat, style: const TextStyle(fontSize: 12)),
                     )),
                     
                     const Padding(
                       padding: EdgeInsets.symmetric(vertical: 8.0),
                       child: Divider(color: AppTheme.borderColor),
                     ),
                     
                     Text(
                       setBonus,
                       style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                     ),
                   ],
                 ),
               ),
            ],
          ),
        ),
      ],
    );
  }
}
