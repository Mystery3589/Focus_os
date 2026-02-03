
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import 'cyber_card.dart';
import 'cyber_progress.dart';

class QuestCard extends StatelessWidget {
  final String title;
  final String description;
  final String reward;
  final int progress;
  final String difficulty; // "S", "A", "B"...
  final String? statusLabel; // "RUNNING", "PAUSED"...
  final Color? statusColor;
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onStart;
  final VoidCallback? onAbandon;
  final String startLabel;
  final IconData startIcon;
  final bool showOverdue;
  final String? overdueLabel;

  const QuestCard({
    super.key,
    required this.title,
    required this.description,
    required this.reward,
    required this.progress,
    required this.difficulty,
    this.statusLabel,
    this.statusColor,
    this.onComplete,
    this.onEdit,
    this.onDelete,
    this.onStart,
    this.onAbandon,
    this.startLabel = 'Start',
    this.startIcon = LucideIcons.play,
    this.showOverdue = false,
    this.overdueLabel,
  });

  Color get _difficultyColor {
    switch (difficulty) {
      case "S": return Colors.red;
      case "A": return Colors.orange;
      case "B": return Colors.amber;
      case "C": return Colors.green;
      case "D": return Colors.blue;
      case "E": return Colors.purple;
      case "Easy": return Colors.green;
      case "Medium": return Colors.amber;
      case "Hard": return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      padding: const EdgeInsets.all(16.0),
      onTap: onComplete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (statusLabel != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (statusColor ?? AppTheme.primary).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: (statusColor ?? AppTheme.primary).withOpacity(0.6)),
                        ),
                        child: Text(
                          statusLabel!,
                          style: TextStyle(
                            color: statusColor ?? AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showOverdue)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Tooltip(
                        message: overdueLabel ?? 'Past due',
                        child: const Icon(
                          LucideIcons.alertTriangle,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(LucideIcons.edit, size: 16, color: AppTheme.textSecondary),
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppTheme.textSecondary),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _difficultyColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        difficulty[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          
          // Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Progress", style: TextStyle(fontSize: 12)),
              Text("$progress%", style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          CyberProgress(
            value: progress.toDouble(), 
            height: 8,
          ),
          
          const SizedBox(height: 8),
          Row(
            children: [
               const Text("Reward: ", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
               Text(reward, style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
            ],
          ),
          if (onStart != null || onAbandon != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onStart != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onStart,
                      icon: Icon(startIcon, size: 14),
                      label: Text(startLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                if (onStart != null && onAbandon != null) const SizedBox(width: 12),
                if (onAbandon != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAbandon,
                      icon: const Icon(LucideIcons.xCircle, size: 14),
                      label: const Text('Abandon'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
