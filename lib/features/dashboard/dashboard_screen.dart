import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/cyber_progress.dart';
import '../../shared/widgets/stat_display.dart';
import '../../shared/widgets/cyber_button.dart';
import '../../shared/widgets/page_container.dart';
import '../../shared/models/user_stats.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _didPromptForName = false;
  bool _didShowAiMessage = false;
  ProviderSubscription<UserStats>? _aiMessageSubscription;
  late final AnimationController _aiInboxPulseController;

  bool get _isTestEnv {
    // Avoid importing flutter_test into lib/ code.
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding') || name.contains('AutomatedTestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();

    _aiInboxPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Avoid infinite animations in widget tests (pumpAndSettle would never settle).
    if (!_isTestEnv) {
      _aiInboxPulseController.repeat(reverse: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForName();
    });

    // Show AI mentor unlock messages (jobs/titles) as a one-time toast.
    _aiMessageSubscription = ref.listenManual<UserStats>(userProvider, (previous, next) {
      if (!mounted) return;
      if (_isTestEnv) return;

      final msg = next.pendingAiMessage;
      if (msg == null || msg.trim().isEmpty) return;

      if (_didShowAiMessage && previous?.pendingAiMessage == msg) return;

      _didShowAiMessage = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            action: SnackBarAction(
              label: 'Profile',
              onPressed: () => context.go('/settings/profile'),
            ),
            duration: const Duration(seconds: 6),
          ),
        );

        // Clear so it won't show again on rebuilds/restarts.
        ref.read(userProvider.notifier).clearPendingAiMessage();
      });
    });
  }

  @override
  void dispose() {
    _aiMessageSubscription?.close();
    _aiInboxPulseController.dispose();
    super.dispose();
  }

  Future<void> _maybePromptForName() async {
    if (!mounted) return;
    if (_didPromptForName) return;

    // Avoid blocking widget tests with a modal dialog.
    if (_isTestEnv) return;

    final name = ref.read(userProvider).name.trim();
    if (name.isNotEmpty) return;

    _didPromptForName = true;

    final controller = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              final trimmed = controller.text.trim();
              final canContinue = trimmed.isNotEmpty;

              return AlertDialog(
                title: const Text('Welcome, Hunter'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What should we call you?'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (!canContinue) return;
                        ref.read(userProvider.notifier).updateProfile(name: trimmed);
                        Navigator.of(context).pop();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Enter your name',
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: canContinue
                        ? () {
                            ref.read(userProvider.notifier).updateProfile(name: trimmed);
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);
    final expPercentage = (userStats.exp / userStats.expToNextLevel) * 100;

    // Get active quests (not completed)
    final activeMissions = userStats.quests.where((q) => !q.completed).toList();
    
    // Get equipped items (assuming equipment is stored in inventory with equipped flag)
    // For now using first few items as placeholder since equipment model isn't explicit
    final equippedItems = userStats.inventory.take(3).toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 96.0),
        child: PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusPanel(userStats, expPercentage)
                  .animate()
                  .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.06, end: 0, duration: 600.ms),

              const SizedBox(height: 12),

              _buildQuickActions(context).animate().fadeIn(delay: 350.ms),

              const SizedBox(height: 14),

                _buildAiInboxPanel(userStats)
                  .animate()
                  .fadeIn(delay: 380.ms)
                  .slideY(begin: 0.04, end: 0, duration: 500.ms),

                const SizedBox(height: 14),

              _buildSectionHeader(context, "ACTIVE MISSIONS", () => context.go('/quests'))
                  .animate()
                  .fadeIn(delay: 400.ms),
              const SizedBox(height: 8),
              _buildActiveMissions(activeMissions).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 14),

              _buildSectionHeader(context, "EQUIPMENT", () => context.go('/equipment'))
                  .animate()
                  .fadeIn(delay: 600.ms),
              const SizedBox(height: 8),
              _buildEquipmentPreview(equippedItems).animate().fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPanel(UserStats userStats, double expPercentage) {
    return Stack(
      children: [
        // Glow effect
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
        ),
        CyberCard(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;

              final levelBlock = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${userStats.level}",
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          "LEVEL",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoLine("NAME", userStats.name.isEmpty ? "Unnamed" : userStats.name),
                  _buildInfoLine("JOB", userStats.job ?? "None"),
                  _buildInfoLine("TITLE", userStats.title ?? "None"),
                ],
              );

              final barsBlock = Column(
                children: [
                  _buildBar("HP", userStats.hp, userStats.maxHp, AppTheme.primary),
                  const SizedBox(height: 10),
                  _buildBar("MP", userStats.mp, userStats.maxMp, AppTheme.primary),
                  const SizedBox(height: 10),
                  _buildBar("EXP", userStats.exp, userStats.expToNextLevel, AppTheme.primary),
                  const SizedBox(height: 10),
                  _buildBar("FATIGUE", userStats.fatigue, 100, const Color(0xFFff4c4c)),
                ],
              );

              final statsWrap = Wrap(
                spacing: 14,
                runSpacing: 12,
                children: [
                  StatDisplay(icon: LucideIcons.shield, name: "STR", value: userStats.stats.str),
                  StatDisplay(icon: LucideIcons.heart, name: "VIT", value: userStats.stats.vit),
                  StatDisplay(icon: LucideIcons.zap, name: "AGI", value: userStats.stats.agi),
                  StatDisplay(icon: LucideIcons.brain, name: "INT", value: userStats.stats.intStat),
                  StatDisplay(icon: LucideIcons.eye, name: "PER", value: userStats.stats.per),
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.primary.withOpacity(0.3))),
                      ),
                      child: const Text(
                        "STATUS",
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.primary,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 240, child: levelBlock),
                        const SizedBox(width: 18),
                        Expanded(child: barsBlock),
                      ],
                    )
                  else
                    Column(
                      children: [
                        levelBlock,
                        const SizedBox(height: 14),
                        barsBlock,
                      ],
                    ),

                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: statsWrap),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "Available Points",
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          Text(
                            "${userStats.statPoints}",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CyberButton(
                            text: "Allocate",
                            variant: CyberButtonVariant.outline,
                            onPressed: () {
                              // TODO: wire to allocation page when available
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAiInboxPanel(UserStats userStats) {
    final inbox = userStats.aiInbox;
    final unreadCount = inbox.where((m) => !m.read).length;
    final recent = inbox.take(3).toList();

    final card = CyberCard(
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
                  'AI INBOX',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
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
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _openAiInboxSheet(userStats),
                child: const Text('View'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const Text(
              'No messages yet. Your AI mentor will send updates when you unlock new Jobs/Titles.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            )
          else
            ...recent.map((m) => _buildAiInboxRow(m)).toList(),
        ],
      ),
    );

    if (unreadCount <= 0 || _isTestEnv) {
      return card;
    }

    // Subtle pulsing glow wrapper to draw attention to unread messages.
    return AnimatedBuilder(
      animation: _aiInboxPulseController,
      builder: (context, child) {
        final t = _aiInboxPulseController.value;
        final glowOpacity = 0.10 + (0.16 * t);
        final blur = 12.0 + (10.0 * t);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(glowOpacity),
                blurRadius: blur,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: card,
    );
  }

  Widget _buildAiInboxRow(AiInboxMessage message) {
    final dim = message.read;
    return GestureDetector(
      onTap: () {
        ref.read(userProvider.notifier).markAiInboxMessageRead(message.id);
        _openAiInboxSheet(ref.read(userProvider));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.background.withOpacity(dim ? 0.25 : 0.40),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.7)),
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
                    message.text,
                    style: TextStyle(
                      color: dim ? AppTheme.textSecondary : AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(message.createdAtMs),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(LucideIcons.chevronRight, color: AppTheme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openAiInboxSheet(UserStats stats) async {
    if (_isTestEnv) return;

    // Always read latest when opening.
    final current = ref.read(userProvider);
    final inbox = current.aiInbox;
    final unreadCount = inbox.where((m) => !m.read).length;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            child: CyberCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.bot, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'AI INBOX',
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
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
                  const SizedBox(height: 10),
                  if (inbox.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'No messages yet.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final live = ref.watch(userProvider).aiInbox;
                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: live.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final msg = live[i];
                              return GestureDetector(
                                onTap: () => ref.read(userProvider.notifier).markAiInboxMessageRead(msg.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background.withOpacity(msg.read ? 0.25 : 0.45),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.borderColor.withOpacity(0.75)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.text,
                                        style: TextStyle(
                                          color: msg.read ? AppTheme.textSecondary : AppTheme.textPrimary,
                                          fontSize: 13,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            _timeAgo(msg.createdAtMs),
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                          ),
                                          const Spacer(),
                                          if (!msg.read)
                                            const Text(
                                              'UNREAD',
                                              style: TextStyle(color: AppTheme.primary, fontSize: 11, letterSpacing: 1.1),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _timeAgo(int createdAtMs) {
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

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              "$label:",
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, int current, int max, Color color) {
    double percentage = 0.0;
    if (max > 0) {
      percentage = (current / max) * 100;
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              Text("$current/$max", style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        CyberProgress(
          value: percentage,
          height: 8,
          progressColor: color,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            color: AppTheme.primary,
            letterSpacing: 1.5,
          ),
        ),
        CyberButton(
          text: "View All",
          variant: CyberButtonVariant.outline,
          onPressed: onViewAll,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return CyberCard(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: CyberButton(
              text: "Start Focus",
              variant: CyberButtonVariant.primary,
              onPressed: () => context.go('/focus'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CyberButton(
              text: "Missions",
              variant: CyberButtonVariant.outline,
              onPressed: () => context.go('/quests'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CyberButton(
              text: "Analytics",
              variant: CyberButtonVariant.outline,
              onPressed: () => context.go('/stats'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMissions(List missions) {
    if (missions.isEmpty) {
      return CyberCard(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "No active missions",
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    
    return Column(
      children: missions.take(3).map((mission) {
        bool showOverdue = false;
        if (mission.dueDateMs != null) {
          final due = DateTime.fromMillisecondsSinceEpoch(mission.dueDateMs);
          final isPastDue = DateTime.now().isAfter(DateTime(due.year, due.month, due.day, 23, 59, 59));
          showOverdue = isPastDue && (mission.frequency ?? '').toLowerCase() != 'daily';
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: CyberCard(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mission.description,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showOverdue)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(LucideIcons.alertTriangle, size: 16, color: Colors.redAccent),
                  ),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.textSecondary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEquipmentPreview(List items) {
    if (items.isEmpty) {
      return CyberCard(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "No equipment equipped",
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) {
        return CyberCard(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.shield, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(item.name, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
