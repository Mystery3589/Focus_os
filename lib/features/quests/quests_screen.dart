
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/quest_card.dart';
import '../../shared/widgets/mission_dialog.dart';
import '../../shared/models/quest.dart';
import '../../shared/models/focus_session.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'latest'; // latest | priority | difficulty | due
  String? _skillFilterId; // null = all
  String _statusFilter = 'all'; // all | none | running | paused | abandoned
  String _difficultyFilter = 'all'; // all | S | A | B | C | D
  String _priorityFilter = 'all'; // all | S | A | B | C | D

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? _statusForQuest(String questId, List<FocusOpenSession> openSessions) {
    try {
      return openSessions.firstWhere((s) => s.questId == questId).status;
    } catch (_) {
      return null;
    }
  }

  int _difficultyRank(String difficulty) {
    const order = {'S': 5, 'A': 4, 'B': 3, 'C': 2, 'D': 1};
    return order[difficulty.toUpperCase()] ?? 0;
  }

  int _priorityRank(String priority) {
    const order = {'S': 5, 'A': 4, 'B': 3, 'C': 2, 'D': 1};
    return order[priority.toUpperCase()] ?? 0;
  }

  List<Quest> _filterAndSortQuests(List<Quest> quests, bool isCompleted, List<FocusOpenSession> openSessions) {
    final filtered = quests.where((q) {
      if (q.completed != isCompleted) return false;

      if (_skillFilterId != null && q.skillId != _skillFilterId) return false;

      if (_difficultyFilter != 'all' && q.difficulty.toUpperCase() != _difficultyFilter) return false;

      if (_priorityFilter != 'all' && q.priority.toUpperCase() != _priorityFilter) return false;

      if (!isCompleted && _statusFilter != 'all') {
        final status = _statusForQuest(q.id, openSessions);
        if (_statusFilter == 'none') {
          if (status != null) return false;
        } else {
          if (status != _statusFilter) return false;
        }
      }

      if (_searchController.text.isNotEmpty) {
        final term = _searchController.text.toLowerCase();
        return q.title.toLowerCase().contains(term) || q.description.toLowerCase().contains(term);
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_sortBy == 'priority') {
        final pA = _priorityRank(a.priority);
        final pB = _priorityRank(b.priority);
        if (pA != pB) return pB.compareTo(pA);
      } else if (_sortBy == 'difficulty') {
        final dA = _difficultyRank(a.difficulty);
        final dB = _difficultyRank(b.difficulty);
        if (dA != dB) return dB.compareTo(dA);
      } else if (_sortBy == 'due') {
        // Null due dates go last.
        final dA = a.dueDateMs ?? 1 << 60;
        final dB = b.dueDateMs ?? 1 << 60;
        if (dA != dB) return dA.compareTo(dB);
      }

      // Latest by default or as a tie-breaker (createdAt for active, completedAt for completed)
      final tA = isCompleted ? (a.completedAt ?? 0) : (a.createdAt ?? 0);
      final tB = isCompleted ? (b.completedAt ?? 0) : (b.createdAt ?? 0);
      return tB.compareTo(tA);
    });

    return filtered;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);
    final openSessions = userStats.focus.openSessions;
    final activeQuests = _filterAndSortQuests(userStats.quests, false, openSessions);
    final completedQuests = _filterAndSortQuests(userStats.quests, true, openSessions);

    return Scaffold(
      // When the keyboard opens (including from modal dialogs), the viewInsets
      // reduce available height. Keep this page layout resilient to those
      // changes so we don't trigger RenderFlex overflows behind dialogs.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: const Text("Missions", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: const [
          AiInboxBellAction(),
        ],
      ),
      body: PageEntrance(
        child: SafeArea(
          child: Column(
            children: [
              // Search / Sort / Filters can be tall. When the keyboard is open,
              // allow this section to scroll instead of overflowing.
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CyberCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.search, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: "Search missions...",
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: const TextStyle(color: AppTheme.textPrimary),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(LucideIcons.x, size: 16, color: AppTheme.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      CyberCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.arrowUpDown, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            const Text("Sort by:", style: TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _sortBy,
                                isExpanded: true,
                                dropdownColor: AppTheme.background, // Should match card bg roughly
                                underline: const SizedBox(),
                                style: const TextStyle(color: AppTheme.textPrimary),
                                items: const [
                                  DropdownMenuItem(value: 'latest', child: Text("Latest Created")),
                                  DropdownMenuItem(value: 'priority', child: Text("Priority (High to Low)")),
                                  DropdownMenuItem(value: 'difficulty', child: Text("Difficulty (Hard to Easy)")),
                                  DropdownMenuItem(value: 'due', child: Text("Due date (Soonest)")),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _sortBy = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      CyberCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.filter, size: 16, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                const Text('Filters', style: TextStyle(color: AppTheme.textSecondary)),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _skillFilterId = null;
                                      _statusFilter = 'all';
                                      _difficultyFilter = 'all';
                                      _priorityFilter = 'all';
                                    });
                                  },
                                  child: const Text('Clear', style: TextStyle(color: AppTheme.textSecondary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: 220,
                                  child: DropdownButtonFormField<String?>(
                                    value: _skillFilterId,
                                    dropdownColor: AppTheme.background,
                                    decoration: const InputDecoration(
                                      labelText: 'Skill',
                                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                                      filled: true,
                                      fillColor: AppTheme.background,
                                      border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                    ),
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    items: [
                                      const DropdownMenuItem<String?>(value: null, child: Text('All skills')),
                                      ...userStats.skills.map(
                                        (s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.title)),
                                      )
                                    ],
                                    onChanged: (val) => setState(() => _skillFilterId = val),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: DropdownButtonFormField<String>(
                                    value: _statusFilter,
                                    dropdownColor: AppTheme.background,
                                    decoration: const InputDecoration(
                                      labelText: 'Status (active tab)',
                                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                                      filled: true,
                                      fillColor: AppTheme.background,
                                      border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                    ),
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    items: const [
                                      DropdownMenuItem(value: 'all', child: Text('All')),
                                      DropdownMenuItem(value: 'none', child: Text('No session')),
                                      DropdownMenuItem(value: 'running', child: Text('Running')),
                                      DropdownMenuItem(value: 'paused', child: Text('Paused')),
                                      DropdownMenuItem(value: 'abandoned', child: Text('Abandoned')),
                                    ],
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() => _statusFilter = val);
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  child: DropdownButtonFormField<String>(
                                    value: _difficultyFilter,
                                    dropdownColor: AppTheme.background,
                                    decoration: const InputDecoration(
                                      labelText: 'Difficulty',
                                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                                      filled: true,
                                      fillColor: AppTheme.background,
                                      border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                    ),
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    items: const [
                                      DropdownMenuItem(value: 'all', child: Text('All')),
                                      DropdownMenuItem(value: 'S', child: Text('S')),
                                      DropdownMenuItem(value: 'A', child: Text('A')),
                                      DropdownMenuItem(value: 'B', child: Text('B')),
                                      DropdownMenuItem(value: 'C', child: Text('C')),
                                      DropdownMenuItem(value: 'D', child: Text('D')),
                                    ],
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() => _difficultyFilter = val);
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  child: DropdownButtonFormField<String>(
                                    value: _priorityFilter,
                                    dropdownColor: AppTheme.background,
                                    decoration: const InputDecoration(
                                      labelText: 'Priority',
                                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                                      filled: true,
                                      fillColor: AppTheme.background,
                                      border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                    ),
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    items: const [
                                      DropdownMenuItem(value: 'all', child: Text('All')),
                                      DropdownMenuItem(value: 'S', child: Text('S')),
                                      DropdownMenuItem(value: 'A', child: Text('A')),
                                      DropdownMenuItem(value: 'B', child: Text('B')),
                                      DropdownMenuItem(value: 'C', child: Text('C')),
                                      DropdownMenuItem(value: 'D', child: Text('D')),
                                    ],
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() => _priorityFilter = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: const [
                  Tab(text: "Active"),
                  Tab(text: "Completed"),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuestList(activeQuests, isActive: true),
                    _buildQuestList(completedQuests, isActive: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () {
          showMissionDialog(context, ref);
        },
        child: const Icon(LucideIcons.plus, color: Colors.black),
      ),
    );
  }

  Widget _buildQuestList(List<Quest> quests, {required bool isActive}) {
    if (quests.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: (constraints.maxHeight - 32).clamp(0.0, double.infinity)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: CyberCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.searchX, size: 36, color: AppTheme.primary),
                        const SizedBox(height: 10),
                        const Text(
                          'No missions found',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try clearing filters or adjusting your search.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _skillFilterId = null;
                                  _statusFilter = 'all';
                                  _difficultyFilter = 'all';
                                  _priorityFilter = 'all';
                                });
                              },
                              icon: const Icon(LucideIcons.filterX, size: 16),
                              label: const Text('Clear filters'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                                side: const BorderSide(color: AppTheme.borderColor),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => showMissionDialog(context, ref),
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('Create mission'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    final userStats = ref.read(userProvider);
    final focusState = userStats.focus;
    final blockingSession = focusState.openSessions.cast<FocusOpenSession?>().firstWhere(
      (s) => s != null && s.status != 'abandoned',
      orElse: () => null,
    );
    Quest? blockingQuest;
    if (blockingSession != null) {
      try {
        blockingQuest = userStats.quests.firstWhere((q) => q.id == blockingSession.questId);
      } catch (_) {}
    }
    final today = DateTime.now();
    final todayMissions = quests.where((q) {
      final startMs = q.startDateMs;
      if (startMs == null) return true;
      return _isSameDay(DateTime.fromMillisecondsSinceEpoch(startMs), today);
    }).toList();

    final extraMissions = quests.where((q) {
      final startMs = q.startDateMs;
      if (startMs == null) return false;
      return !_isSameDay(DateTime.fromMillisecondsSinceEpoch(startMs), today);
    }).toList();

    Widget buildSection(String title, List<Quest> list) {
      if (list.isEmpty) return const SizedBox();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
            child: Text(
              title,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 1.1),
            ),
          ),
          ...list.map((quest) {
            FocusOpenSession? session;
            try {
              session = focusState.openSessions.firstWhere((s) => s.questId == quest.id);
            } catch (_) {}

            final status = session?.status;
            final isPaused = status == 'paused';
            final isRunning = status == 'running';
            final isAbandoned = status == 'abandoned';

            final anyOpen = blockingSession != null;
            final isOtherMissionOpen = anyOpen && blockingSession.questId != quest.id;

            String? statusLabel;
            Color? statusColor;
            if (isRunning) {
              statusLabel = 'RUNNING';
              statusColor = Colors.greenAccent;
            } else if (isPaused) {
              statusLabel = 'PAUSED';
              statusColor = Colors.amberAccent;
            } else if (isAbandoned) {
              statusLabel = 'ABANDONED';
              statusColor = Colors.redAccent;
            }

            // CTA precedence:
            // - Running/Paused: act on this mission
            // - Otherwise, if another mission is running/paused, lock this one (even if it has an abandoned session)
            // - Otherwise, allow rejoin/start
            String startLabel = 'Start';
            IconData startIcon = LucideIcons.play;
            if (isRunning) {
              startLabel = 'Open';
              startIcon = LucideIcons.externalLink;
            } else if (isPaused) {
              startLabel = 'Resume';
              startIcon = LucideIcons.play;
            } else if (isOtherMissionOpen) {
              startLabel = 'Locked';
              startIcon = LucideIcons.lock;
            } else if (isAbandoned) {
              startLabel = 'Rejoin';
              startIcon = LucideIcons.play;
            }

            final dueMs = quest.dueDateMs;
            bool showOverdue = false;
            if (dueMs != null) {
              final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
              final isPastDue = DateTime.now().isAfter(DateTime(due.year, due.month, due.day, 23, 59, 59));
              showOverdue = isPastDue && (quest.frequency ?? '').toLowerCase() != 'daily';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: QuestCard(
                title: quest.title,
                description: quest.description,
                reward: quest.reward,
                progress: quest.progress,
                difficulty: quest.difficulty,
                statusLabel: statusLabel,
                statusColor: statusColor,
                showOverdue: showOverdue,
                overdueLabel: 'Past due',
                onComplete: isActive
                    ? () {
                        if (quest.progress < 100) {
                          context.push('/focus', extra: quest.id);
                        } else {
                          ref.read(userProvider.notifier).completeQuest(quest.id);
                        }
                      }
                    : null,
                onEdit: isActive ? () => showMissionDialog(context, ref, quest: quest) : null,
                onDelete: () => _showDeleteConfirmation(context, quest.id),
                startLabel: startLabel,
                startIcon: startIcon,
                onStart: isActive
                    ? () {
                        if (isOtherMissionOpen) {
                          final title = blockingQuest?.title ?? 'a mission';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Finish/resume $title before starting another mission.')),
                          );
                          context.go('/focus?missionId=${blockingSession.questId}');
                          return;
                        }

                        if (isRunning) {
                          context.go('/focus?missionId=${quest.id}');
                          return;
                        }

                        final focusSettings = ref.read(userProvider).focus.settings;
                        ref.read(userProvider.notifier).updateFocusSettings(
                              focusSettings.copyWith(mode: 'stopwatch'),
                            );
                        final ok = ref.read(userProvider.notifier).startFocus(quest.id);
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You already have a paused/running mission.')),
                          );
                          if (blockingSession != null) {
                            context.go('/focus?missionId=${blockingSession.questId}');
                          }
                          return;
                        }
                        context.go('/focus?missionId=${quest.id}');
                      }
                    : null,
                onAbandon: isActive && session != null && (isPaused || isRunning)
                    ? () {
                        final before = session!;
                        final beforeActiveId = focusState.activeSessionId;
                        ref.read(userProvider.notifier).abandonMission(before.id);

                        final messenger = ScaffoldMessenger.of(context);
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('Mission abandoned.'),
                            duration: const Duration(seconds: 8),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () {
                                ref.read(userProvider.notifier).restoreOpenSession(
                                      before,
                                      activeSessionId: beforeActiveId,
                                    );
                              },
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            );
          }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isActive && blockingSession != null) ...[
          CyberCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  blockingSession.status == 'running' ? LucideIcons.play : LucideIcons.pause,
                  size: 16,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active mission session',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        blockingQuest?.title ?? 'Mission',
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        blockingSession.status == 'running'
                            ? 'Running — you can’t start another mission.'
                            : 'Paused — resume or abandon to start another mission.',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    context.go('/focus?missionId=${blockingSession.questId}');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: const Text('Open Focus'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {
                    final before = blockingSession;
                    final beforeActiveId = focusState.activeSessionId;
                    ref.read(userProvider.notifier).abandonMission(before.id);

                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Mission abandoned. You can start a new one now.'),
                        duration: const Duration(seconds: 8),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            ref.read(userProvider.notifier).restoreOpenSession(
                                  before,
                                  activeSessionId: beforeActiveId,
                                );
                          },
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  child: const Text('Abandon'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (isActive) ...[
          buildSection('TODAY', todayMissions),
          buildSection('EXTRA MISSIONS', extraMissions),
        ] else ...[
          buildSection('COMPLETED', quests),
        ]
      ],
    );
  }

  // Mission create/edit uses shared dialog in lib/shared/widgets/mission_dialog.dart

  void _showDeleteConfirmation(BuildContext context, String questId) {
    final stats = ref.read(userProvider);
    Quest? quest;
    int? questIndex;
    try {
      questIndex = stats.quests.indexWhere((q) => q.id == questId);
      if (questIndex != -1) quest = stats.quests[questIndex];
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text(
          'Delete Mission',
          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this mission? This action cannot be undone.',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(userProvider.notifier).deleteQuest(questId);
              Navigator.pop(context);

              if (quest != null) {
                final messenger = ScaffoldMessenger.of(this.context);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Deleted “${quest.title}”.'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        ref.read(userProvider.notifier).restoreQuest(quest!, index: questIndex);
                      },
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
          ],
        ),
      );
    
  }
}
