
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/models/user_stats.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/page_container.dart';
import '../../shared/widgets/quest_card.dart';
import '../../shared/widgets/mission_dialog.dart';
import '../../shared/models/quest.dart';
import '../../shared/models/focus_session.dart';
import '../../shared/services/quest_sorting_service.dart';
import '../../shared/providers/device_identity_provider.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<QuestSortRule> _sortRules = const [
    QuestSortRule('latest', false),
  ];
  String? _skillFilterId; // null = all
  String _statusFilter = 'all'; // all | none | running | paused | abandoned
  String _difficultyFilter = 'all'; // all | S | A | B | C | D
  String _priorityFilter = 'all'; // all | S | A | B | C | D
  String _typeFilter = 'all'; // all | one-time | daily | weekly | monthly | yearly

  int get _activeFilterCount {
    int c = 0;
    if (_skillFilterId != null) c++;
    if (_statusFilter != 'all') c++;
    if (_difficultyFilter != 'all') c++;
    if (_priorityFilter != 'all') c++;
    if (_typeFilter != 'all') c++;
    return c;
  }

  String get _sortByLabel {
    if (_sortRules.isEmpty) return 'Sort: Latest';

    String labelFor(String field) {
      switch (field) {
        case 'latest':
          return 'Latest';
        case 'priority':
          return 'Priority';
        case 'difficulty':
          return 'Difficulty';
        case 'due':
          return 'Due';
        case 'length':
          return 'Length';
        case 'type':
          return 'Type';
        default:
          return field;
      }
    }

    final parts = _sortRules
        .map((r) => '${labelFor(r.field)} ${r.ascending ? '↑' : '↓'}')
        .toList(growable: false);
    return 'Sort: ${parts.join(', ')}';
  }

  void _clearFilters() {
    setState(() {
      _skillFilterId = null;
      _statusFilter = 'all';
      _difficultyFilter = 'all';
      _priorityFilter = 'all';
      _typeFilter = 'all';
    });
  }

  Future<void> _openSortAndFilterDialog(UserStats userStats) async {
    // Multi-sort: up to 4 criteria.
    final currentRules = _sortRules.isNotEmpty ? _sortRules : const [QuestSortRule('latest', false)];
    final tmpSortFields = <String>['none', 'none', 'none', 'none'];
    final tmpSortAsc = <bool>[false, false, false, false];
    for (var i = 0; i < currentRules.length && i < 4; i++) {
      tmpSortFields[i] = currentRules[i].field;
      tmpSortAsc[i] = currentRules[i].ascending;
    }

    String? tmpSkillFilterId = _skillFilterId;
    var tmpStatusFilter = _statusFilter;
    var tmpDifficultyFilter = _difficultyFilter;
    var tmpPriorityFilter = _priorityFilter;
    var tmpTypeFilter = _typeFilter;

    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.borderColor),
              ),
              title: const Text(
                'Sort & Filters',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Sort by', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose up to 4 criteria (top = most important).',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(4, (i) {
                        final idx = i;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: tmpSortFields[idx],
                                  dropdownColor: AppTheme.background,
                                  decoration: InputDecoration(
                                    labelText: idx == 0 ? 'Primary' : (idx == 1 ? 'Secondary' : (idx == 2 ? 'Tertiary' : 'Quaternary')),
                                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                    filled: true,
                                    fillColor: AppTheme.background,
                                    border: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                                  ),
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                  items: const [
                                    DropdownMenuItem(value: 'none', child: Text('None')),
                                    DropdownMenuItem(value: 'latest', child: Text('Latest')),
                                    DropdownMenuItem(value: 'priority', child: Text('Priority')),
                                    DropdownMenuItem(value: 'due', child: Text('Due date')),
                                    DropdownMenuItem(value: 'difficulty', child: Text('Difficulty')),
                                    DropdownMenuItem(value: 'length', child: Text('Expected length')),
                                    DropdownMenuItem(value: 'type', child: Text('Task type')),
                                  ],
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setLocalState(() => tmpSortFields[idx] = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              DropdownButton<bool>(
                                value: tmpSortAsc[idx],
                                dropdownColor: AppTheme.background,
                                underline: Container(height: 1, color: AppTheme.borderColor),
                                items: const [
                                  DropdownMenuItem(value: false, child: Text('Desc', style: TextStyle(color: AppTheme.textPrimary))),
                                  DropdownMenuItem(value: true, child: Text('Asc', style: TextStyle(color: AppTheme.textPrimary))),
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setLocalState(() => tmpSortAsc[idx] = val);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      const Divider(color: AppTheme.borderColor, height: 1),
                      const SizedBox(height: 12),
                      const Text('Filters', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: tmpSkillFilterId,
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
                        onChanged: (val) => setLocalState(() => tmpSkillFilterId = val),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: tmpStatusFilter,
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
                          setLocalState(() => tmpStatusFilter = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: tmpTypeFilter,
                        dropdownColor: AppTheme.background,
                        decoration: const InputDecoration(
                          labelText: 'Task type',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderColor)),
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'one-time', child: Text('One-time')),
                          DropdownMenuItem(value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setLocalState(() => tmpTypeFilter = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: tmpDifficultyFilter,
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
                                setLocalState(() => tmpDifficultyFilter = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: tmpPriorityFilter,
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
                                setLocalState(() => tmpPriorityFilter = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setLocalState(() {
                      tmpSortFields[0] = 'latest';
                      tmpSortFields[1] = 'none';
                      tmpSortFields[2] = 'none';
                      tmpSortFields[3] = 'none';
                      tmpSortAsc[0] = false;
                      tmpSortAsc[1] = false;
                      tmpSortAsc[2] = false;
                      tmpSortAsc[3] = false;
                      tmpSkillFilterId = null;
                      tmpStatusFilter = 'all';
                      tmpDifficultyFilter = 'all';
                      tmpPriorityFilter = 'all';
                      tmpTypeFilter = 'all';
                    });
                  },
                  child: const Text('Reset', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied != true) return;

    final nextRules = <QuestSortRule>[];
    final seen = <String>{};
    for (var i = 0; i < tmpSortFields.length; i++) {
      final f = tmpSortFields[i];
      if (f == 'none') continue;
      if (seen.contains(f)) continue;
      seen.add(f);
      nextRules.add(QuestSortRule(f, tmpSortAsc[i]));
    }
    if (nextRules.isEmpty) {
      nextRules.add(const QuestSortRule('latest', false));
    }

    setState(() {
      _sortRules = List.unmodifiable(nextRules);
      _skillFilterId = tmpSkillFilterId;
      _statusFilter = tmpStatusFilter;
      _difficultyFilter = tmpDifficultyFilter;
      _priorityFilter = tmpPriorityFilter;
      _typeFilter = tmpTypeFilter;
    });
  }

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

  Future<bool> _confirmCompleteWithoutStarting(BuildContext context, Quest quest) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text(
          'Complete Mission',
          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Mark “${quest.title}” as completed without starting a focus session?',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    return res ?? false;
  }

  Future<void> _handleCompleteWithoutStarting({
    required BuildContext context,
    required Quest quest,
    required FocusOpenSession? session,
  }) async {
    // Match Focus page behavior: block while running/paused.
    if (session != null && (session.status == 'running' || session.status == 'paused')) {
      AppToast.show(
        context,
        message: 'Can\'t complete while this mission is running/paused.',
      );
      context.go('/focus?missionId=${quest.id}');
      return;
    }

    final ok = await _confirmCompleteWithoutStarting(context, quest);
    if (!ok) return;

    final success = ref.read(userProvider.notifier).completeQuestWithoutStarting(quest.id);
    if (!success) {
      AppToast.show(
        context,
        message: 'Can\'t complete while this mission is running/paused.',
      );
      return;
    }

    AppToast.show(
      context,
      message: 'Completed “${quest.title}”.',
      duration: const Duration(seconds: 4),
    );
  }

  List<Quest> _filterAndSortQuests(List<Quest> quests, bool isCompleted, List<FocusOpenSession> openSessions) {
    return filterAndSortQuests(
      quests: quests,
      isCompleted: isCompleted,
      openSessions: openSessions,
      sortRules: _sortRules,
      skillFilterId: _skillFilterId,
      statusFilter: _statusFilter,
      difficultyFilter: _difficultyFilter,
      priorityFilter: _priorityFilter,
      typeFilter: _typeFilter,
      searchTerm: _searchController.text,
    );
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

    // Keep the header compact and bounded so it doesn't steal space from the
    // missions list or leave large unused space at the bottom on desktop.
    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeaderHeight = (screenH * 0.34).clamp(180.0, 320.0);

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
          child: PageContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Search / Sort / Filters can be tall. When the keyboard is
                // open, allow this section to scroll (bounded), without using
                // flex sizing (which can leave a big empty area at the bottom
                // and shrink the missions list viewport).
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeaderHeight),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 520;

                              final sortButton = TextButton.icon(
                                onPressed: () => _openSortAndFilterDialog(userStats),
                                icon: const Icon(LucideIcons.slidersHorizontal, size: 16, color: AppTheme.textSecondary),
                                label: Text(
                                  _activeFilterCount > 0 ? 'Sort & Filter ($_activeFilterCount)' : 'Sort & Filter',
                                  style: const TextStyle(color: AppTheme.textSecondary),
                                ),
                              );

                              final clearButton = TextButton.icon(
                                onPressed: _activeFilterCount == 0 ? null : _clearFilters,
                                icon: const Icon(LucideIcons.rotateCcw, size: 16, color: AppTheme.textSecondary),
                                label: const Text('Clear', style: TextStyle(color: AppTheme.textSecondary)),
                              );

                              final addButton = ElevatedButton.icon(
                                onPressed: () => showMissionDialog(context, ref),
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text('New'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              );

                              final sortLabel = Text(
                                _activeFilterCount > 0
                                    ? '$_sortByLabel • $_activeFilterCount filter${_activeFilterCount == 1 ? '' : 's'}'
                                    : _sortByLabel,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              );

                              if (isNarrow) {
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    sortButton,
                                    clearButton,
                                    addButton,
                                    sortLabel,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  sortButton,
                                  clearButton,
                                  const SizedBox(width: 10),
                                  Expanded(child: sortLabel),
                                  const SizedBox(width: 10),
                                  addButton,
                                ],
                              );
                            },
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
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildQuestList(List<Quest> quests, {required bool isActive}) {
    final myDeviceId = ref.watch(deviceIdentityProvider).valueOrNull?.id;
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

      // Group sub-missions under their parent for display.
      final sectionById = <String, Quest>{
        for (final q in list) q.id: q,
      };
      final childrenByParent = <String, List<Quest>>{};
      for (final q in list) {
        final pid = q.parentQuestId;
        if (pid == null) continue;
        if (!sectionById.containsKey(pid)) continue;
        (childrenByParent[pid] ??= <Quest>[]).add(q);
      }

      // Preserve the existing ordering of [list] for top-level items.
      final topLevel = <Quest>[];
      for (final q in list) {
        final pid = q.parentQuestId;
        if (pid == null || !sectionById.containsKey(pid)) {
          topLevel.add(q);
        }
      }

      Widget buildQuestCardFor(
        Quest quest, {
        required EdgeInsets padding,
        required bool allowAddSubMission,
        required bool allowStart,
        required bool allowCompleteTap,
        String? titleOverride,
        bool allowOverdue = true,
      }) {
        FocusOpenSession? session;
        try {
          session = focusState.openSessions.firstWhere((s) => s.questId == quest.id);
        } catch (_) {}

        final status = session?.status;
        final isPaused = status == 'paused';
        final isRunning = status == 'running';
        final isAbandoned = status == 'abandoned';

        final ownedByOtherDevice =
          isRunning &&
          myDeviceId != null &&
          session?.deviceId != null &&
          session!.deviceId != myDeviceId;

        final anyOpen = blockingSession != null;
        final isOtherMissionOpen = anyOpen && blockingSession.questId != quest.id;

        String? statusLabel;
        Color? statusColor;
        if (isRunning) {
          if (ownedByOtherDevice) {
            statusLabel = 'RUNNING (OTHER DEVICE)';
            statusColor = Colors.lightBlueAccent;
          } else {
            statusLabel = 'RUNNING';
            statusColor = Colors.greenAccent;
          }
        } else if (isPaused) {
          statusLabel = 'PAUSED';
          statusColor = Colors.amberAccent;
        } else if (isAbandoned) {
          statusLabel = 'ABANDONED';
          statusColor = Colors.redAccent;
        }

        String startLabel = 'Start';
        IconData startIcon = LucideIcons.play;
        if (ownedByOtherDevice) {
          startLabel = 'Continue here';
          startIcon = LucideIcons.arrowRight;
        } else if (isRunning) {
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
        if (allowOverdue && dueMs != null) {
          final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
          final isPastDue = DateTime.now().isAfter(DateTime(due.year, due.month, due.day, 23, 59, 59));
          showOverdue = isPastDue && (quest.frequency ?? '').toLowerCase() != 'daily';
        }

        return Padding(
          padding: padding,
          child: QuestCard(
            title: titleOverride ?? quest.title,
            description: quest.description,
            reward: quest.reward,
            progress: quest.progress,
            difficulty: quest.difficulty,
            statusLabel: statusLabel,
            statusColor: statusColor,
            showOverdue: showOverdue,
            overdueLabel: 'Past due',
            onAddSubMission: isActive && allowAddSubMission && !quest.completed
                ? () => showMissionDialog(context, ref, parentQuestId: quest.id)
                : null,
            onComplete: isActive && allowCompleteTap
                ? () {
                    if (quest.progress < 100) {
                      context.push('/focus', extra: quest.id);
                    } else {
                      ref.read(userProvider.notifier).completeQuest(quest.id);
                    }
                  }
                : null,
            onCompleteWithoutStarting: isActive && allowCompleteTap && !quest.completed
                ? () {
                    _handleCompleteWithoutStarting(
                      context: context,
                      quest: quest,
                      session: session,
                    );
                  }
                : null,
            completeWithoutStartingLabel: 'Complete (no focus)',
            onEdit: isActive ? () => showMissionDialog(context, ref, quest: quest) : null,
            onDelete: () => _showDeleteConfirmation(context, quest.id),
            startLabel: startLabel,
            startIcon: startIcon,
            onStart: isActive && allowStart
                ? () {
                    if (isOtherMissionOpen) {
                      final title = blockingQuest?.title ?? 'a mission';
                      AppToast.show(
                        context,
                        message: 'Finish/resume $title before starting another mission.',
                      );
                      context.go('/focus?missionId=${blockingSession.questId}');
                      return;
                    }

                    if (ownedByOtherDevice) {
                      // Take over the running session and open Focus.
                      if (session != null) {
                        unawaited(ref.read(userProvider.notifier).continueOpenSessionOnThisDevice(session.id));
                      }
                      context.go('/focus?missionId=${quest.id}');
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
                      AppToast.show(
                        context,
                        message: 'You already have a paused/running mission.',
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
                    // ignore: unused_local_variable
                    messenger.hideCurrentSnackBar();
                    AppToast.show(
                      context,
                      message: 'Mission abandoned.',
                      actionLabel: 'Undo',
                      onAction: () {
                        ref.read(userProvider.notifier).restoreOpenSession(
                              before,
                              activeSessionId: beforeActiveId,
                            );
                      },
                      duration: const Duration(seconds: 8),
                    );
                  }
                : null,
          ),
        );
      }

      final cards = <Widget>[];
      for (final quest in topLevel) {
        final hasChildrenAnywhere = userStats.quests.any((q) => q.parentQuestId == quest.id);
        cards.add(
          buildQuestCardFor(
            quest,
            padding: const EdgeInsets.only(bottom: 16.0),
            allowAddSubMission: quest.parentQuestId == null,
            allowStart: !hasChildrenAnywhere,
            allowCompleteTap: !hasChildrenAnywhere,
            allowOverdue: true,
          ),
        );

        final children = childrenByParent[quest.id];
        if (children == null || children.isEmpty) continue;
        for (final child in children) {
          final childHasKids = userStats.quests.any((q) => q.parentQuestId == child.id);
          cards.add(
            buildQuestCardFor(
              child,
              padding: const EdgeInsets.only(bottom: 16.0, left: 18.0),
              allowAddSubMission: false,
              allowStart: !childHasKids,
              allowCompleteTap: !childHasKids,
              titleOverride: '↳ ${child.title}',
              allowOverdue: false,
            ),
          );
        }
      }

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
          ...cards,
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
                    AppToast.show(
                      context,
                      message: 'Mission abandoned. You can start a new one now.',
                      actionLabel: 'Undo',
                      onAction: () {
                        ref.read(userProvider.notifier).restoreOpenSession(
                              before,
                              activeSessionId: beforeActiveId,
                            );
                      },
                      duration: const Duration(seconds: 8),
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
          if (extraMissions.isEmpty) ...[
            const SizedBox(height: 10),
            CyberCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.sparkles, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You’re caught up',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'No extra missions scheduled beyond today. Add a new mission when you’re ready.',
                          style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: () => showMissionDialog(context, ref),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Create mission'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          buildSection('COMPLETED', quests),
        ],

        // Ensure the last card/buttons can scroll fully above the bottom navbar.
        SizedBox(height: 90 + MediaQuery.of(context).padding.bottom),
      ],
    );
  }

  // Mission create/edit uses shared dialog in lib/shared/widgets/mission_dialog.dart

  void _showDeleteConfirmation(BuildContext context, String questId) {
    final stats = ref.read(userProvider);
    Quest? quest;
    int? questIndex;

    final questsById = <String, Quest>{
      for (final q in stats.quests) q.id: q,
    };
    final indicesById = <String, int>{
      for (final entry in stats.quests.asMap().entries) entry.value.id: entry.key,
    };

    Set<String> descendantIds() {
      final ids = <String>{questId};
      bool added = true;
      while (added) {
        added = false;
        for (final q in stats.quests) {
          final p = q.parentQuestId;
          if (p != null && ids.contains(p) && !ids.contains(q.id)) {
            ids.add(q.id);
            added = true;
          }
        }
      }
      return ids;
    }
    try {
      questIndex = stats.quests.indexWhere((q) => q.id == questId);
      if (questIndex != -1) quest = stats.quests[questIndex];
    } catch (_) {}

    final idsToDelete = descendantIds();
    final questsToRestore = idsToDelete.map((id) => questsById[id]).whereType<Quest>().toList(growable: false);

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
                final toastContext = this.context;
                AppToast.show(
                  toastContext,
                  message: questsToRestore.length > 1
                      ? 'Deleted “${quest.title}” (+${questsToRestore.length - 1} sub-mission${questsToRestore.length - 1 == 1 ? '' : 's'}).'
                      : 'Deleted “${quest.title}”.',
                  actionLabel: 'Undo',
                  onAction: () {
                    // Restore in descending index order so insertions don't shift
                    // positions of later items.
                    final sorted = List<Quest>.from(questsToRestore)
                      ..sort((a, b) => (indicesById[b.id] ?? 0).compareTo(indicesById[a.id] ?? 0));
                    for (final q in sorted) {
                      ref.read(userProvider.notifier).restoreQuest(q, index: indicesById[q.id]);
                    }
                  },
                  duration: const Duration(seconds: 8),
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
