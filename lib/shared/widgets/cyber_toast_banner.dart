import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';

/// A cyber-styled top banner content widget intended to be hosted inside a
/// `MaterialBanner`.
///
/// This keeps the rendering logic reusable while the display mechanism
/// (ScaffoldMessenger) stays at the call site.
class CyberToastBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onPrimary;
  final String? primaryLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final VoidCallback? onDismiss;

  const CyberToastBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = LucideIcons.sparkles,
    this.onPrimary,
    this.primaryLabel,
    this.onSecondary,
    this.secondaryLabel,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final primaryLabelSafe = (primaryLabel == null || primaryLabel!.trim().isEmpty) ? null : primaryLabel!.trim();
    final secondaryLabelSafe = (secondaryLabel == null || secondaryLabel!.trim().isEmpty) ? null : secondaryLabel!.trim();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppTheme.cardBg.withOpacity(0.98),
            AppTheme.cardBg.withOpacity(0.90),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.18),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconGlow(icon: icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        onPressed: onDismiss,
                        icon: const Icon(LucideIcons.x, size: 16),
                        color: AppTheme.textSecondary,
                        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                        padding: EdgeInsets.zero,
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  if (primaryLabelSafe != null || secondaryLabelSafe != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (primaryLabelSafe != null)
                          _ActionChip(
                            label: primaryLabelSafe,
                            filled: true,
                            onPressed: onPrimary,
                          ),
                        if (secondaryLabelSafe != null)
                          _ActionChip(
                            label: secondaryLabelSafe,
                            filled: false,
                            onPressed: onSecondary,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconGlow extends StatelessWidget {
  final IconData icon;

  const _IconGlow({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primary.withOpacity(0.12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: AppTheme.primary, size: 18),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  const _ActionChip({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.black : AppTheme.primary;
    final bg = filled ? AppTheme.primary : Colors.transparent;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: filled ? null : Border.all(color: AppTheme.primary.withOpacity(0.55)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
