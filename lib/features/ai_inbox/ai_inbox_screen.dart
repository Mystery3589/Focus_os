import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/page_entrance.dart';

class AiInboxScreen extends ConsumerWidget {
  const AiInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userProvider);
    final inbox = stats.aiInbox;
    final unreadCount = inbox.where((m) => !m.read).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('AI Inbox', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(userProvider.notifier).markAllAiInboxRead(),
              child: const Text('Mark all read'),
            ),
          TextButton(
            onPressed: () => ref.read(userProvider.notifier).clearAiInbox(),
            child: const Text('Clear'),
          ),
        ],
      ),
      body: PageEntrance(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CyberCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(
                children: [
                  const Icon(LucideIcons.bot, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'MESSAGES',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unreadCount unread',
                        style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (inbox.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No messages yet.\n\nYour AI mentor will send updates when you unlock new Jobs/Titles.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                  ),
                )
              else
                ...inbox.map((m) {
                  final dim = m.read;
                  return GestureDetector(
                    onTap: () => ref.read(userProvider.notifier).markAiInboxMessageRead(m.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withOpacity(dim ? 0.25 : 0.45),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor.withOpacity(0.75)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dim ? AppTheme.borderColor : AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.text,
                                  style: TextStyle(
                                    color: dim ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    fontSize: 13,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      _timeAgo(m.createdAtMs),
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                    const Spacer(),
                                    if (!m.read)
                                      const Text(
                                        'UNREAD',
                                        style: TextStyle(color: AppTheme.primary, fontSize: 11, letterSpacing: 1.1),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _timeAgo(int createdAtMs) {
    if (createdAtMs <= 0) return 'Just now';
    final now = DateTime.now().millisecondsSinceEpoch;
    final deltaMs = (now - createdAtMs).clamp(0, 1 << 62);
    final seconds = (deltaMs / 1000).floor();
    if (seconds < 30) return 'Just now';
    if (seconds < 60) return '${seconds}s ago';
    final minutes = (seconds / 60).floor();
    if (minutes < 60) return '${minutes}m ago';
    final hours = (minutes / 60).floor();
    if (hours < 48) return '${hours}h ago';
    final days = (hours / 24).floor();
    return '${days}d ago';
  }
}
