
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/cyber_button.dart';
import '../../shared/models/inventory_item.dart';
import '../../shared/widgets/page_container.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // All, Mat, Consum, Equip
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<InventoryItem> _filterItems(List<InventoryItem> items, String? type) {
    return items.filter((item) {
      bool typeMatch = true;
      if (type != null) {
        if (type == 'Equipment') {
           typeMatch = ['Weapon', 'Armor', 'Accessory', 'Rune'].contains(item.type);
        } else {
           typeMatch = item.type == type;
        }
      }
      
      if (_searchController.text.isNotEmpty) {
        final term = _searchController.text.toLowerCase();
        return typeMatch && (item.name.toLowerCase().contains(term) || item.description.toLowerCase().contains(term));
      }
      return typeMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);
    final inventory = userStats.inventory;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: const Text("Inventory", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e2a3a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text("Gold: ", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Text("${userStats.gold}", style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      body: PageContainer(
        child: Column(
          children: [
            CyberCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(LucideIcons.search, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: "Search items...",
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tabs (match the wide segmented look)
            CyberCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "All"),
                  Tab(text: "Materials"),
                  Tab(text: "Consumables"),
                  Tab(text: "Equipment"),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGrid(_filterItems(inventory, null)),
                  _buildGrid(_filterItems(inventory, 'Material')),
                  _buildGrid(_filterItems(inventory, 'Consumable')),
                  _buildGrid(_filterItems(inventory, 'Equipment')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<InventoryItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isNotEmpty 
             ? "No items match your search." 
             : "No items in this category.",
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide, web-like cards: prefer fewer columns with large max extent.
        final maxExtent = constraints.maxWidth >= 980 ? 520.0 : 420.0;
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            childAspectRatio: 2.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _InventoryItemCard(item: item);
          },
        );
      },
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  
  const _InventoryItemCard({required this.item});

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case "Common": return Colors.grey;
      case "Uncommon": return Colors.greenAccent;
      case "Rare": return AppTheme.primary;
      case "Epic": return Colors.purpleAccent;
      case "Legendary": return Colors.yellowAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(item.rarity);

    return CyberCard(
      padding: EdgeInsets.zero,
      onTap: () {
        // Show details dialog
        showDialog(
          context: context,
          builder: (context) => _ItemDetailsDialog(item: item),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rarity Strip
          Container(height: 4, color: rarityColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: rarityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.quantity > 1)
                        Text(
                          "x${item.quantity}",
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1e2a3a),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.type,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: const [
                      Icon(LucideIcons.info, size: 14, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text(
                        "Details",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemDetailsDialog extends ConsumerWidget {
  final InventoryItem item;
  const _ItemDetailsDialog({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
       backgroundColor: AppTheme.background,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(8),
         side: const BorderSide(color: AppTheme.borderColor),
       ),
       child: Padding(
         padding: const EdgeInsets.all(24.0),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(item.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
             const SizedBox(height: 8),
             Text(item.description, style: const TextStyle(color: AppTheme.textSecondary)),
             const SizedBox(height: 24),
             
             // Actions
             Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 TextButton(
                   onPressed: () => Navigator.of(context).pop(),
                   child: const Text("Close"),
                 ),
                 if (item.type == 'Consumable') ...[
                   const SizedBox(width: 8),
                   CyberButton(
                     text: "Use",
                     onPressed: () {
                        ref.read(userProvider.notifier).useItem(item.id);
                        Navigator.of(context).pop();
                     },
                   ),
                 ],
               ],
             )
           ],
         ),
       ),
    );
  }
}

extension ListFilter<E> on List<E> {
  List<E> filter(bool Function(E) test) => where(test).toList();
}
