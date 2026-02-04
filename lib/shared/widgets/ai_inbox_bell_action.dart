import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../providers/user_provider.dart';

/// AppBar action that opens the AI Inbox and shows an unread badge.
///
/// Use this inside `AppBar(actions: [...])` so it never overlaps other UI.
class AiInboxBellAction extends ConsumerWidget {
  final String tooltip;

  const AiInboxBellAction({super.key, this.tooltip = 'AI Inbox'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      userProvider.select((s) => s.aiInbox.where((m) => !m.read).length),
    );

    return IconButton(
      tooltip: tooltip,
      onPressed: () => context.push('/ai-inbox'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(LucideIcons.bell),
          if (unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withOpacity(0.35)),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
