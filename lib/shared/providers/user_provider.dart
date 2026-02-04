
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user_stats.dart';
import '../models/quest.dart';
import '../models/inventory_item.dart';
import '../models/focus_session.dart';
import '../models/skill.dart';
import '../models/combat.dart';
import '../models/user_event.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../services/combat_service.dart';
import '../services/drive_sync_service.dart';
import 'level_up_provider.dart';

final userProvider = StateNotifierProvider<UserNotifier, UserStats>((ref) {
  return UserNotifier(ref);
});

class UserNotifier extends StateNotifier<UserStats> {
  final Ref ref;
  
  UserNotifier(this.ref) : super(UserStats.initial()) {
    _loadUserStats();
  }

  Timer? _recoveryTimer;
  static const _uuid = Uuid();
  static final Random _combatRng = Random();

  Future<SharedPreferences?> _prefsBestEffort() async {
    // On some Android builds, plugins can be briefly unavailable during very early startup.
    // Instead of crashing, retry a few times.
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        return await SharedPreferences.getInstance();
      } catch (_) {
        // Small backoff: 40ms, 80ms, 160ms, 320ms
        final delayMs = 40 * (1 << attempt);
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    return null;
  }

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static const List<String> _jobCatalog = <String>[
    'Novice',
    'Apprentice',
    'Adventurer',
    'Scout',
    'Tactician',
    'Artisan',
    'Scholar',
    'Sentinel',
    'Pathfinder',
    'Strategist',
    'Warden',
    'Chronomancer',
    'Seeker',
    'Craftmaster',
    'Field Medic',
    'Navigator',
    'Archivist',
    'Vanguard',
    'Ranger',
    'Commander',
  ];

  static const List<String> _titleCatalog = <String>[
    'Rookie',
    'The Focused',
    'The Patient',
    'The Persistent',
    'The Steady',
    'Task Breaker',
    'Timekeeper',
    'Momentum Builder',
    'Mindful Worker',
    'Storm Calmer',
    'The Unshaken',
    'The Reliable',
    'The Determined',
    'The Prepared',
    'The Unstoppable',
    'The Disciplined',
    'The Strategist',
    'The Builder',
    'The Finisher',
    'The Quiet Force',
  ];

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    super.dispose();
  }

  Future<void> _loadUserStats() async {
    final prefs = await _prefsBestEffort();
    if (prefs == null) {
      _startRecoveryTimer();
      return;
    }
    final jsonString = prefs.getString('soloLevelUpUserStats');
    if (jsonString != null) {
      try {
        final jsonMap = jsonDecode(jsonString);
        state = UserStats.fromJson(jsonMap);
        _migrateLegacySkillMissionsToQuests();
        _checkOfflineRecovery(prefs);
        _applyOverduePenalties();
        _ensureJobTitleScheduleInitialized();
      } catch (e) {
        // print('Error loading stats: $e');
      }
    }
    _startRecoveryTimer();
  }

  void _ensureJobTitleScheduleInitialized() {
    if (state.nextJobTitleGrantAtMs != null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rng = Random(now ^ state.level ^ state.exp ^ state.stats.vit);
    final minutes = 60 + rng.nextInt(180); // 1–4 hours
    state = state.copyWith(nextJobTitleGrantAtMs: now + Duration(minutes: minutes).inMilliseconds);
    _saveUserStats();
  }

  bool _unlockJobInternal(String job, {bool setActive = true}) {
    final trimmed = job.trim();
    if (trimmed.isEmpty) return false;

    final updated = List<String>.from(state.unlockedJobs);
    final alreadyUnlocked = updated.contains(trimmed);
    if (!alreadyUnlocked) {
      updated.add(trimmed);
    }

    state = state.copyWith(
      unlockedJobs: updated,
      job: setActive ? trimmed : state.job,
    );
    return !alreadyUnlocked;
  }

  bool _unlockTitleInternal(String title, {bool setActive = true}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;

    final updated = List<String>.from(state.unlockedTitles);
    final alreadyUnlocked = updated.contains(trimmed);
    if (!alreadyUnlocked) {
      updated.add(trimmed);
    }

    state = state.copyWith(
      unlockedTitles: updated,
      title: setActive ? trimmed : state.title,
    );
    return !alreadyUnlocked;
  }

  /// Unlock a new job and optionally make it active.
  ///
  /// Jobs are intended to be granted by the game's "AI".
  bool unlockJob(String job, {bool setActive = true}) {
    final changed = _unlockJobInternal(job, setActive: setActive);
    if (changed) _saveUserStats();
    return changed;
  }

  /// Unlock a new title and optionally make it active.
  ///
  /// Titles are intended to be granted by the game's "AI".
  bool unlockTitle(String title, {bool setActive = true}) {
    final changed = _unlockTitleInternal(title, setActive: setActive);
    if (changed) _saveUserStats();
    return changed;
  }

  /// Select your active job from already-unlocked jobs.
  void setActiveJob(String job) {
    final trimmed = job.trim();
    if (trimmed.isEmpty) return;
    if (!state.unlockedJobs.contains(trimmed)) return;
    if (state.job == trimmed) return;
    state = state.copyWith(job: trimmed);
    _saveUserStats();
  }

  /// Select your active title from already-unlocked titles.
  void setActiveTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    if (!state.unlockedTitles.contains(trimmed)) return;
    if (state.title == trimmed) return;
    state = state.copyWith(title: trimmed);
    _saveUserStats();
  }

  Future<void> _saveUserStats() async {
    final prefs = await _prefsBestEffort();
    if (prefs == null) return;
    final payload = jsonEncode(state.toJson());
    await prefs.setString('soloLevelUpUserStats', payload);

    // Used for best-effort sync conflict detection.
    await prefs.setInt(DriveSyncService.prefLastLocalSaveAtMs, DateTime.now().millisecondsSinceEpoch);

    final autoUpload = prefs.getBool(DriveSyncService.prefAutoUpload) ?? false;
    if (autoUpload) {
      DriveSyncService.instance.scheduleAutoUploadLatest(payload);
    }
  }

  /// Exports the current state to JSON for backups.
  ///
  /// Use [pretty] for human-readable formatting.
  String exportUserStatsJson({bool pretty = true}) {
    final map = state.toJson();
    if (!pretty) return jsonEncode(map);
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Imports a backup JSON payload and overwrites local state.
  ///
  /// Returns `true` on success, `false` if the payload is invalid.
  ///
  /// Side effects:
  /// - runs migrations
  /// - restarts recovery timer
  /// - re-syncs notifications
  Future<bool> importUserStatsJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return false;

      state = UserStats.fromJson(decoded);

      // Bring older payloads forward.
      _migrateLegacySkillMissionsToQuests();
      _applyOverduePenalties();
      _startRecoveryTimer();
      _resyncAllNotifications();

      await _saveUserStats();
      return true;
    } catch (_) {
      return false;
    }
  }

  NotificationSettings get _notificationSettings => state.focus.settings.notifications;

  String _pausedReminderTitleForSession(FocusOpenSession session) {
    if (session.questId.startsWith('custom-')) {
      final h = session.heading?.trim();
      return (h != null && h.isNotEmpty) ? h : 'Custom Session';
    }

    final q = state.quests.cast<Quest?>().firstWhere(
      (q) => q != null && q.id == session.questId,
      orElse: () => null,
    );
    return q?.title ?? 'Mission';
  }

  void _syncQuestDueReminder(Quest quest) {
    final notifications = _notificationSettings;

    // Cancel unless all requirements are met.
    if (!notifications.enabled || !notifications.dueDateReminder || quest.completed || quest.dueDateMs == null) {
      unawaited(NotificationService.instance.cancelDueDateReminder(quest.id));
      return;
    }

    final due = DateTime.fromMillisecondsSinceEpoch(quest.dueDateMs!);
    unawaited(NotificationService.instance.scheduleDueDateReminder(
      questId: quest.id,
      title: quest.title,
      dueDate: due,
      hour: notifications.dueDateReminderHour,
    ));
  }

  void _syncPausedReminderForSession(FocusOpenSession session) {
    final notifications = _notificationSettings;

    // Cancel unless all requirements are met.
    if (!notifications.enabled || !notifications.pausedMissionReminder || session.status != 'paused') {
      unawaited(NotificationService.instance.cancelPausedMissionReminder(session.id));
      return;
    }

    unawaited(NotificationService.instance.schedulePausedMissionReminder(
      sessionId: session.id,
      title: _pausedReminderTitleForSession(session),
      after: NotificationService.instance.pausedReminderDelayMinutes(notifications.pausedMissionReminderMinutes),
    ));
  }

  void _syncUserEventReminder(UserEvent event) {
    final notifications = _notificationSettings;

    // Cancel unless all requirements are met.
    if (!notifications.enabled || !notifications.eventReminder || !event.remind) {
      unawaited(NotificationService.instance.cancelEventReminder(event.id));
      return;
    }

    final startAt = DateTime.fromMillisecondsSinceEpoch(event.startAtMs);
    unawaited(NotificationService.instance.scheduleEventReminder(
      eventId: event.id,
      title: event.title,
      startAt: startAt,
      allDay: event.allDay,
      hourIfAllDay: notifications.eventReminderHour,
      minutesBefore: event.remindMinutesBefore,
    ));
  }

  void _resyncAllNotifications() {
    for (final q in state.quests) {
      _syncQuestDueReminder(q);
    }
    for (final s in state.focus.openSessions) {
      _syncPausedReminderForSession(s);
    }
    for (final e in state.userEvents) {
      _syncUserEventReminder(e);
    }
  }

  // --- Calendar events ---
  void addUserEvent(UserEvent event) {
    final title = event.title.trim();
    if (title.isEmpty) return;

    final updated = List<UserEvent>.from(state.userEvents);
    updated.add(event.copyWith(title: title));

    state = state.copyWith(userEvents: updated);
    _saveUserStats();
    _syncUserEventReminder(event);
  }

  void updateUserEvent(UserEvent event) {
    final idx = state.userEvents.indexWhere((e) => e.id == event.id);
    if (idx < 0) return;

    final title = event.title.trim();
    if (title.isEmpty) return;

    final updated = List<UserEvent>.from(state.userEvents);
    updated[idx] = event.copyWith(title: title);
    state = state.copyWith(userEvents: updated);
    _saveUserStats();
    _syncUserEventReminder(updated[idx]);
  }

  void deleteUserEvent(String eventId) {
    final idx = state.userEvents.indexWhere((e) => e.id == eventId);
    if (idx < 0) return;

    final updated = List<UserEvent>.from(state.userEvents)..removeAt(idx);
    state = state.copyWith(userEvents: updated);
    _saveUserStats();
    unawaited(NotificationService.instance.cancelEventReminder(eventId));
  }

  // --- Habits ---
  void addHabit(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final h = Habit(
      id: _uuid.v4(),
      title: trimmed,
      createdAtMs: now,
      archived: false,
      completedDays: const [],
    );

    state = state.copyWith(habits: [...state.habits, h]);
    _saveUserStats();
  }

  void toggleHabitCompletion(String habitId, {DateTime? day}) {
    final idx = state.habits.indexWhere((h) => h.id == habitId);
    if (idx < 0) return;

    final d = _dayStart(day ?? DateTime.now());
    final key = _dayKey(d);

    final habits = List<Habit>.from(state.habits);
    final h = habits[idx];
    if (h.archived) return;

    final completed = List<int>.from(h.completedDays);
    if (completed.contains(key)) {
      completed.removeWhere((k) => k == key);
    } else {
      completed.add(key);
    }
    completed.sort();
    habits[idx] = h.copyWith(completedDays: completed);

    state = state.copyWith(habits: habits);
    _saveUserStats();
  }

  void archiveHabit(String habitId, {required bool archived}) {
    final idx = state.habits.indexWhere((h) => h.id == habitId);
    if (idx < 0) return;

    final habits = List<Habit>.from(state.habits);
    habits[idx] = habits[idx].copyWith(archived: archived);
    state = state.copyWith(habits: habits);
    _saveUserStats();
  }

  void deleteHabit(String habitId) {
    final idx = state.habits.indexWhere((h) => h.id == habitId);
    if (idx < 0) return;

    final habits = List<Habit>.from(state.habits)..removeAt(idx);
    state = state.copyWith(habits: habits);
    _saveUserStats();
  }

  Future<void> resetAllData() async {
    final preservedName = state.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('soloLevelUpUserStats');
    await prefs.remove('lastRecoveryTime');

    // Reset progression but keep identity.
    state = UserStats.initial().copyWith(name: preservedName);
    _saveUserStats();
  }

  void _checkOfflineRecovery(SharedPreferences prefs) {
    // Basic offline recovery logic matching the web app
    final lastRecoveryTimeStr = prefs.getString('lastRecoveryTime');
    if (lastRecoveryTimeStr != null) {
      final lastTime = int.parse(lastRecoveryTimeStr);
      final now = DateTime.now().millisecondsSinceEpoch;
      final recoveryInterval = 5 * 60 * 1000; // 5 minutes
      final diff = now - lastTime;
      final periods = diff ~/ recoveryInterval;

      if (periods > 0) {
        final hpRecovery = (state.maxHp * 0.1 * periods).floor();
        final mpRecovery = (state.maxMp * 0.1 * periods).floor();

        state = state.copyWith(
          hp: min(state.maxHp, state.hp + hpRecovery),
          mp: min(state.maxMp, state.mp + mpRecovery),
        );
        prefs.setString('lastRecoveryTime', (lastTime + periods * recoveryInterval).toString());
      }
    }
    _saveUserStats();
  }

  void _startRecoveryTimer() {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
       // Only recover if not in combat (combat state logic to be added later if needed)
       // For now, mirroring simpler logic
       _applyOverduePenalties();

       _maybeGrantScheduledJobOrTitle();
       
       final hpRecovery = (state.maxHp * 0.1).floor();
       final mpRecovery = (state.maxMp * 0.1).floor();
       
       if (state.hp < state.maxHp || state.mp < state.maxMp) {
         state = state.copyWith(
           hp: min(state.maxHp, state.hp + hpRecovery),
           mp: min(state.maxMp, state.mp + mpRecovery),
         );
         final prefs = await SharedPreferences.getInstance();
         prefs.setString('lastRecoveryTime', DateTime.now().millisecondsSinceEpoch.toString());
         _saveUserStats();
       }
    });
  }

  void _maybeGrantScheduledJobOrTitle() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextAt = state.nextJobTitleGrantAtMs;
    if (nextAt == null) {
      _ensureJobTitleScheduleInitialized();
      return;
    }
    if (now < nextAt) return;

    final rng = Random(now ^ state.level ^ state.exp ^ state.stats.per ^ state.stats.vit);

    String? grantedJob;
    String? grantedTitle;
    final preferJob = rng.nextBool();
    if (preferJob) {
      grantedJob = _grantRandomJob(rng);
      grantedTitle = grantedJob == null ? _grantRandomTitle(rng) : null;
    } else {
      grantedTitle = _grantRandomTitle(rng);
      grantedJob = grantedTitle == null ? _grantRandomJob(rng) : null;
    }

    final message = grantedJob != null
        ? 'AI Mentor unlocked a new Job: $grantedJob'
        : grantedTitle != null
            ? 'AI Mentor unlocked a new Title: $grantedTitle'
            : null;

    if (message != null) {
      final entry = AiInboxMessage(
        id: _uuid.v4(),
        text: message,
        createdAtMs: now,
        read: false,
      );

      state = state.copyWith(
        pendingAiMessage: message,
        pendingAiMessageAtMs: now,
        aiInbox: [entry, ...state.aiInbox].take(200).toList(),
      );
    }

    // Reschedule either way (even if we've unlocked everything).
    final minutes = 60 + rng.nextInt(240); // 1–5 hours
    state = state.copyWith(nextJobTitleGrantAtMs: now + Duration(minutes: minutes).inMilliseconds);
    _saveUserStats();
  }

  String? _grantRandomJob(Random rng) {
    final remaining = _jobCatalog.where((j) => !state.unlockedJobs.contains(j)).toList();
    if (remaining.isEmpty) return null;
    final pick = remaining[rng.nextInt(remaining.length)];
    _unlockJobInternal(pick, setActive: true);
    return pick;
  }

  String? _grantRandomTitle(Random rng) {
    final remaining = _titleCatalog.where((t) => !state.unlockedTitles.contains(t)).toList();
    if (remaining.isEmpty) return null;
    final pick = remaining[rng.nextInt(remaining.length)];
    _unlockTitleInternal(pick, setActive: true);
    return pick;
  }

  void clearPendingAiMessage() {
    if (state.pendingAiMessage == null && state.pendingAiMessageAtMs == null) return;
    state = state.copyWith(
      pendingAiMessage: null,
      pendingAiMessageAtMs: null,
    );
    _saveUserStats();
  }

  void markAiInboxMessageRead(String id) {
    final idx = state.aiInbox.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final msg = state.aiInbox[idx];
    if (msg.read) return;
    final updated = List<AiInboxMessage>.from(state.aiInbox);
    updated[idx] = msg.copyWith(read: true);
    state = state.copyWith(aiInbox: updated);
    _saveUserStats();
  }

  void markAllAiInboxRead() {
    if (state.aiInbox.isEmpty) return;
    final hasUnread = state.aiInbox.any((m) => !m.read);
    if (!hasUnread) return;
    state = state.copyWith(aiInbox: state.aiInbox.map((m) => m.read ? m : m.copyWith(read: true)).toList());
    _saveUserStats();
  }

  void clearAiInbox() {
    if (state.aiInbox.isEmpty) return;
    state = state.copyWith(aiInbox: const []);
    _saveUserStats();
  }

  void addExp(int amount) {
    int currentExp = state.exp + amount;
    if (currentExp < 0) currentExp = 0;
    UserStats newState = state.copyWith(exp: currentExp);

    while (newState.exp >= newState.expToNextLevel) {
      newState = _levelUp(newState);
    }
    state = newState;
    _saveUserStats();
  }

  int _baseXpPerMinute(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'S':
        return 12;
      case 'A':
        return 10;
      case 'B':
        return 8;
      case 'C':
        return 6;
      case 'D':
        return 4;
      default:
        return 5;
    }
  }

  Map<String, int?> _calculateMissionXpBreakdown({
    required int actualMinutes,
    required Quest quest,
  }) {
    final safeMinutes = actualMinutes <= 0 ? 1 : actualMinutes;
    final base = _baseXpPerMinute(quest.difficulty) * safeMinutes;
    final int? expected = (quest.expectedMinutes != null && quest.expectedMinutes! > 0) ? quest.expectedMinutes : null;
    final int? delta = expected == null ? null : (expected - safeMinutes);

    int bonus = 0;
    int penalty = 0;

    if (delta != null) {
      if (delta > 0) {
        bonus = (base * 0.1).floor();
      } else if (delta < 0) {
        penalty = (base * 0.1).floor();
      }
    }

    final total = (base + bonus - penalty).clamp(0, 1 << 30).toInt();
    return {
      'base': base,
      'bonus': bonus,
      'penalty': penalty,
      'total': total,
      'expected': expected,
      'delta': delta,
    };
  }

  void _migrateLegacySkillMissionsToQuests() {
    // Older versions stored missions inside SkillGoal.missions.
    // New behavior: Skills reference the same Quest objects as the Missions page.
    // This migration converts legacy skill missions into quests linked via quest.skillId.
    bool changed = false;

    final existingQuestIds = state.quests.map((q) => q.id).toSet();
    final newQuests = List<Quest>.from(state.quests);
    final newSkills = <SkillGoal>[];

    for (final skill in state.skills) {
      if (skill.missions.isEmpty) {
        newSkills.add(skill);
        continue;
      }

      for (final m in skill.missions) {
        if (existingQuestIds.contains(m.id)) {
          // Quest already exists; ensure it's linked.
          final idx = newQuests.indexWhere((q) => q.id == m.id);
          if (idx != -1 && newQuests[idx].skillId != skill.id) {
            newQuests[idx] = newQuests[idx].copyWith(skillId: skill.id);
            changed = true;
          }
          continue;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        const expectedMinutes = 60;
        final expReward = _baseXpPerMinute('B') * expectedMinutes;

        newQuests.add(
          Quest(
            id: m.id,
            title: m.title,
            description: 'Created from skill: ${skill.title}',
            reward: '$expReward XP',
            progress: m.completed ? 100 : 0,
            difficulty: 'B',
            priority: 'B',
            expiry: '',
            expReward: expReward,
            statPointsReward: 0,
            active: false,
            completed: m.completed,
            skillId: skill.id,
            expectedMinutes: expectedMinutes,
            createdAt: now,
            completedAt: m.completed ? now : null,
          ),
        );
        existingQuestIds.add(m.id);
        changed = true;
      }

      // Clear legacy missions now that quests exist.
      newSkills.add(skill.copyWith(missions: const []));
      changed = true;
    }

    if (changed) {
      state = state.copyWith(quests: newQuests, skills: newSkills);
      _saveUserStats();
    }
  }

  int _dateKey(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  void _applyOverduePenalties() {
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    bool updated = false;
    int totalPenalty = 0;

    final updatedQuests = state.quests.map((quest) {
      if (quest.completed) return quest;
      if (quest.dueDateMs == null) return quest;

      final due = DateTime.fromMillisecondsSinceEpoch(quest.dueDateMs!);
      final isPastDue = now.isAfter(DateTime(due.year, due.month, due.day, 23, 59, 59));
      if (!isPastDue) return quest;

      final lastPenalty = quest.lastPenaltyDate ?? 0;
      if (lastPenalty == todayKey) return quest;

      final freq = (quest.frequency ?? '').toLowerCase();
      if (freq == 'daily' || freq == 'weekly') return quest;

      final penalty = _baseXpPerMinute(quest.difficulty) * 5;
      totalPenalty += penalty;
      updated = true;
      return quest.copyWith(lastPenaltyDate: todayKey);
    }).toList();

    if (updated) {
      state = state.copyWith(quests: updatedQuests);
      if (totalPenalty > 0) {
        addExp(-totalPenalty);
      }
      _saveUserStats();
    }
  }

  Stats _defaultTaskWeights() {
    return Stats(str: 1, agi: 1, per: 1, intStat: 1, vit: 1);
  }

  Stats _scoreFromText(String text) {
    final lower = text.toLowerCase();
    int str = 0;
    int agi = 0;
    int per = 0;
    int intStat = 0;
    int vit = 0;

    final strKeywords = [
      'strength', 'lift', 'lifting', 'push', 'pull', 'workout', 'gym', 'power', 'weights', 'bench', 'squat'
    ];
    final agiKeywords = [
      'run', 'running', 'sprint', 'cardio', 'speed', 'dance', 'mobility', 'stretch', 'yoga', 'agility'
    ];
    final perKeywords = [
      'review', 'audit', 'observe', 'inspect', 'detail', 'check', 'testing', 'qa', 'debug', 'proof'
    ];
    final intKeywords = [
      'study', 'learn', 'write', 'code', 'program', 'research', 'plan', 'design', 'math', 'analysis'
    ];
    final vitKeywords = [
      'sleep', 'rest', 'health', 'diet', 'meal', 'hydration', 'meditate', 'breath', 'endurance', 'recovery'
    ];

    for (final k in strKeywords) {
      if (lower.contains(k)) str += 2;
    }
    for (final k in agiKeywords) {
      if (lower.contains(k)) agi += 2;
    }
    for (final k in perKeywords) {
      if (lower.contains(k)) per += 2;
    }
    for (final k in intKeywords) {
      if (lower.contains(k)) intStat += 2;
    }
    for (final k in vitKeywords) {
      if (lower.contains(k)) vit += 2;
    }

    return Stats(str: str, agi: agi, per: per, intStat: intStat, vit: vit);
  }

  Stats _applyTaskWeighting(Stats current, Quest quest, int totalMinutes) {
    int str = current.str;
    int agi = current.agi;
    int per = current.per;
    int intStat = current.intStat;
    int vit = current.vit;

    final textScore = _scoreFromText('${quest.title} ${quest.description}');
    final timeFactor = max(1, (totalMinutes / 30).ceil());
    str += textScore.str * timeFactor;
    agi += textScore.agi * timeFactor;
    per += textScore.per * timeFactor;
    intStat += textScore.intStat * timeFactor;
    vit += textScore.vit * timeFactor;

    switch (quest.difficulty.toUpperCase()) {
      case 'S':
        str += 3;
        vit += 3;
        break;
      case 'A':
        str += 2;
        per += 2;
        break;
      case 'B':
        str += 1;
        agi += 2;
        break;
      case 'C':
        intStat += 2;
        per += 1;
        break;
      case 'D':
        agi += 1;
        intStat += 1;
        break;
    }

    if ((quest.frequency ?? '').toLowerCase() == 'daily') {
      agi += 3;
      vit += 1;
    }

    if (totalMinutes >= 60) {
      vit += 3;
    } else if (totalMinutes <= 20) {
      intStat += 2;
    }

    if (quest.priority.toUpperCase() == 'S') {
      per += 3;
    } else if (quest.priority.toUpperCase() == 'A') {
      per += 2;
    }

    return Stats(
      str: max(1, str),
      agi: max(1, agi),
      per: max(1, per),
      intStat: max(1, intStat),
      vit: max(1, vit),
    );
  }

  UserStats _autoAllocateStatPoints(UserStats current, int points) {
    if (points <= 0) return current;

    final weights = current.levelTaskWeights;
    final totalWeight = weights.str + weights.agi + weights.per + weights.intStat + weights.vit;
    if (totalWeight <= 0) return current;

    int remaining = points;
    int addStr = (points * weights.str / totalWeight).floor();
    int addAgi = (points * weights.agi / totalWeight).floor();
    int addPer = (points * weights.per / totalWeight).floor();
    int addInt = (points * weights.intStat / totalWeight).floor();
    int addVit = (points * weights.vit / totalWeight).floor();

    final allocated = addStr + addAgi + addPer + addInt + addVit;
    remaining -= allocated;

    final order = [
      {'stat': 'str', 'weight': weights.str},
      {'stat': 'agi', 'weight': weights.agi},
      {'stat': 'per', 'weight': weights.per},
      {'stat': 'int', 'weight': weights.intStat},
      {'stat': 'vit', 'weight': weights.vit},
    ]..sort((a, b) => (b['weight'] as int).compareTo(a['weight'] as int));

    int idx = 0;
    while (remaining > 0) {
      final stat = order[idx % order.length]['stat'];
      switch (stat) {
        case 'str':
          addStr += 1;
          break;
        case 'agi':
          addAgi += 1;
          break;
        case 'per':
          addPer += 1;
          break;
        case 'int':
          addInt += 1;
          break;
        case 'vit':
          addVit += 1;
          break;
      }
      remaining -= 1;
      idx += 1;
    }

    final newStats = current.stats.copyWith(
      str: current.stats.str + addStr,
      agi: current.stats.agi + addAgi,
      per: current.stats.per + addPer,
      intStat: current.stats.intStat + addInt,
      vit: current.stats.vit + addVit,
    );

    final newMaxHp = (100 + current.level * 10 + newStats.vit * 5).floor();
    final newMaxMp = (10 + current.level * 2 + newStats.intStat * 2).floor();

    return current.copyWith(
      stats: newStats,
      maxHp: newMaxHp,
      hp: newMaxHp,
      maxMp: newMaxMp,
      mp: newMaxMp,
      levelTaskWeights: _defaultTaskWeights(),
    );
  }

  UserStats _levelUp(UserStats currentStats) {
    final newLevel = currentStats.level + 1;
    const autoPoints = 5;
    // Auto increase stats
    final newStatsStr = currentStats.stats.str + 1;
    final newStatsAgi = currentStats.stats.agi + 1;
    final newStatsPer = currentStats.stats.per + 1;
    final newStatsInt = currentStats.stats.intStat + 1;
    final newStatsVit = currentStats.stats.vit + 1;

    final newMaxHp = (100 + newLevel * 10 + newStatsVit * 5).floor();
    final newMaxMp = (10 + newLevel * 2 + newStatsInt * 2).floor();
    final expNeeded = (100 * pow(1.1, newLevel - 1)).floor();

    // Trigger level-up modal
    ref.read(levelUpProvider.notifier).triggerLevelUp(newLevel, 1); // +1 to all stats

    final leveledStats = currentStats.copyWith(
      level: newLevel,
      exp: currentStats.exp - currentStats.expToNextLevel,
      expToNextLevel: expNeeded,
      maxHp: newMaxHp,
      hp: newMaxHp,
      maxMp: newMaxMp,
      mp: newMaxMp,
      stats: currentStats.stats.copyWith(
        str: newStatsStr,
        agi: newStatsAgi,
        per: newStatsPer,
        intStat: newStatsInt,
        vit: newStatsVit,
      ),
      lastLevelUpAt: DateTime.now().millisecondsSinceEpoch,
    );

    return _autoAllocateStatPoints(leveledStats, autoPoints);
  }

  void allocateStat(String stat) {
    if (state.statPoints <= 0) return;

    var newStats = state.stats;
    int newMaxHp = state.maxHp;
    int newMaxMp = state.maxMp;

    switch (stat) {
      case 'str': newStats = newStats.copyWith(str: newStats.str + 1); break;
      case 'agi': newStats = newStats.copyWith(agi: newStats.agi + 1); break;
      case 'per': newStats = newStats.copyWith(per: newStats.per + 1); break;
      case 'int': 
        newStats = newStats.copyWith(intStat: newStats.intStat + 1);
        newMaxMp = (10 + state.level * 2 + (newStats.intStat) * 2).floor();
        break;
      case 'vit': 
        newStats = newStats.copyWith(vit: newStats.vit + 1);
        newMaxHp = (100 + state.level * 10 + (newStats.vit) * 5).floor();
        break;
    }

    state = state.copyWith(
      stats: newStats,
      statPoints: state.statPoints - 1,
      maxHp: newMaxHp,
      maxMp: newMaxMp,
    );
    _saveUserStats();
  }

  void addQuest(Quest quest) {
    state = state.copyWith(
      quests: [...state.quests, quest],
    );
    _syncQuestDueReminder(quest);
    _saveUserStats();
  }

  void updateProfile({String? name, String? job, String? title}) {
    // Name is user-editable; job/title are intended to be AI-granted and selectable
    // only from already-unlocked items.
    final nextName = name ?? state.name;

    final updatedJobs = List<String>.from(state.unlockedJobs);
    String? nextJob = state.job;
    if (job != null && job.trim().isNotEmpty) {
      final trimmed = job.trim();
      if (!updatedJobs.contains(trimmed)) {
        updatedJobs.add(trimmed);
      }
      nextJob = trimmed;
    }

    final updatedTitles = List<String>.from(state.unlockedTitles);
    String? nextTitle = state.title;
    if (title != null && title.trim().isNotEmpty) {
      final trimmed = title.trim();
      if (!updatedTitles.contains(trimmed)) {
        updatedTitles.add(trimmed);
      }
      nextTitle = trimmed;
    }

    state = state.copyWith(
      name: nextName,
      unlockedJobs: updatedJobs,
      unlockedTitles: updatedTitles,
      job: nextJob,
      title: nextTitle,
    );
    _saveUserStats();
  }

  void addSkillGoal(String title, {String? description}) {
    final newSkill = SkillGoal(
      id: _uuid.v4(),
      title: title,
      description: description,
      missions: [],
      level: 1,
      exp: 0,
    );
    state = state.copyWith(skills: [...state.skills, newSkill]);
    _saveUserStats();
  }

  void updateSkillGoal(String skillId, {String? title, String? description}) {
    final idx = state.skills.indexWhere((s) => s.id == skillId);
    if (idx == -1) return;
    final skill = state.skills[idx];
    final updated = skill.copyWith(
      title: title ?? skill.title,
      description: description ?? skill.description,
    );
    final updatedSkills = List<SkillGoal>.from(state.skills);
    updatedSkills[idx] = updated;
    state = state.copyWith(skills: updatedSkills);
    _saveUserStats();
  }

  void deleteSkillGoal(String skillId) {
    final updatedQuests = state.quests
        .map((q) => q.skillId == skillId ? q.copyWith(skillId: null) : q)
        .toList();
    state = state.copyWith(
      quests: updatedQuests,
      skills: state.skills.where((s) => s.id != skillId).toList(),
    );
    _saveUserStats();
  }

  void addSkillMission(String skillId, String title) {
    final idx = state.skills.indexWhere((s) => s.id == skillId);
    if (idx == -1) return;

    final skill = state.skills[idx];
    final updated = skill.copyWith(
      missions: [
        ...skill.missions,
        SkillMission(id: _uuid.v4(), title: title, completed: false),
      ],
    );

    final updatedSkills = List<SkillGoal>.from(state.skills);
    updatedSkills[idx] = updated;
    state = state.copyWith(skills: updatedSkills);
    _saveUserStats();
  }

  void updateSkillMission(String skillId, String missionId, {String? title}) {
    final idx = state.skills.indexWhere((s) => s.id == skillId);
    if (idx == -1) return;
    final skill = state.skills[idx];
    final missionIdx = skill.missions.indexWhere((m) => m.id == missionId);
    if (missionIdx == -1) return;

    final updatedMissions = List<SkillMission>.from(skill.missions);
    final current = updatedMissions[missionIdx];
    updatedMissions[missionIdx] = current.copyWith(title: title ?? current.title);

    final updated = skill.copyWith(missions: updatedMissions);
    final updatedSkills = List<SkillGoal>.from(state.skills);
    updatedSkills[idx] = updated;
    state = state.copyWith(skills: updatedSkills);
    _saveUserStats();
  }

  void deleteSkillMission(String skillId, String missionId) {
    final idx = state.skills.indexWhere((s) => s.id == skillId);
    if (idx == -1) return;
    final skill = state.skills[idx];
    final updated = skill.copyWith(
      missions: skill.missions.where((m) => m.id != missionId).toList(),
    );
    final updatedSkills = List<SkillGoal>.from(state.skills);
    updatedSkills[idx] = updated;
    state = state.copyWith(skills: updatedSkills);
    _saveUserStats();
  }

  void toggleSkillMission(String skillId, String missionId) {
    final idx = state.skills.indexWhere((s) => s.id == skillId);
    if (idx == -1) return;
    final skill = state.skills[idx];
    final missionIdx = skill.missions.indexWhere((m) => m.id == missionId);
    if (missionIdx == -1) return;

    final updatedMissions = List<SkillMission>.from(skill.missions);
    final current = updatedMissions[missionIdx];
    updatedMissions[missionIdx] = current.copyWith(completed: !current.completed);

    final updated = skill.copyWith(missions: updatedMissions);
    final updatedSkills = List<SkillGoal>.from(state.skills);
    updatedSkills[idx] = updated;
    state = state.copyWith(skills: updatedSkills);
    _saveUserStats();
  }

  void updateQuest(Quest updatedQuest) {
    final questIndex = state.quests.indexWhere((q) => q.id == updatedQuest.id);
    if (questIndex == -1) return;

    final updatedQuests = List<Quest>.from(state.quests);
    updatedQuests[questIndex] = updatedQuest;

    state = state.copyWith(quests: updatedQuests);
    _syncQuestDueReminder(updatedQuest);
    _saveUserStats();
  }

  /// Restore a previously deleted quest.
  ///
  /// If a quest with the same id already exists, it is replaced.
  /// If [index] is provided and valid, inserts at that position.
  /// Also keeps `completedQuests` consistent with `quest.completed`.
  void restoreQuest(Quest quest, {int? index}) {
    final existingIndex = state.quests.indexWhere((q) => q.id == quest.id);
    final updatedQuests = List<Quest>.from(state.quests);

    if (existingIndex != -1) {
      updatedQuests[existingIndex] = quest;
    } else {
      final insertAt = (index != null && index >= 0 && index <= updatedQuests.length) ? index : updatedQuests.length;
      updatedQuests.insert(insertAt, quest);
    }

    final updatedCompleted = List<String>.from(state.completedQuests);
    if (quest.completed) {
      if (!updatedCompleted.contains(quest.id)) updatedCompleted.add(quest.id);
    } else {
      updatedCompleted.removeWhere((id) => id == quest.id);
    }

    state = state.copyWith(quests: updatedQuests, completedQuests: updatedCompleted);
    _syncQuestDueReminder(quest);
    _saveUserStats();
  }

  void deleteQuest(String questId) {
    final removedSessionIds = state.focus.openSessions
        .where((s) => s.questId == questId)
        .map((s) => s.id)
        .toList(growable: false);

    final updatedQuests = state.quests.where((q) => q.id != questId).toList();
    final updatedCompleted = state.completedQuests.where((id) => id != questId).toList();

    // Also remove any focus sessions referencing this quest to avoid dangling state.
    final focus = state.focus;
    final updatedOpen = focus.openSessions.where((s) => s.questId != questId).toList();
    final updatedHistory = focus.history.where((h) => h.questId != questId).toList();

    String? newActiveId = focus.activeSessionId;
    if (newActiveId != null) {
      final activeStillExists = updatedOpen.any((s) => s.id == newActiveId);
      if (!activeStillExists) newActiveId = null;
    }

    state = state.copyWith(
      quests: updatedQuests,
      completedQuests: updatedCompleted,
      focus: FocusState(
        activeSessionId: newActiveId,
        openSessions: updatedOpen,
        history: updatedHistory,
        settings: focus.settings,
      ),
    );

    unawaited(NotificationService.instance.cancelDueDateReminder(questId));
    for (final sessionId in removedSessionIds) {
      unawaited(NotificationService.instance.cancelPausedMissionReminder(sessionId));
    }

    _saveUserStats();
  }

  void completeQuest(String questId, {int? totalMinutes, int? earnedExpOverride}) {
    final questIndex = state.quests.indexWhere((q) => q.id == questId);
    if (questIndex == -1) return;
    
    final quest = state.quests[questIndex];
    if (quest.completed) return;

    // Quest is being completed: ensure any due-date reminder is cleared.
    unawaited(NotificationService.instance.cancelDueDateReminder(questId));

    // Mark quest as completed
    final updatedQuests = List<Quest>.from(state.quests);
    updatedQuests[questIndex] = quest.copyWith(
      progress: 100,
      completed: true,
      active: false,
      completedAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Give rewards
    var newState = state.copyWith(
      quests: updatedQuests,
      completedQuests: [...state.completedQuests, questId],
      statPoints: state.statPoints + quest.statPointsReward,
      gold: state.gold + (quest.goldReward ?? 0),
    );

    // Apply stat rewards directly
    if (quest.statRewards != null) {
      final r = quest.statRewards!;
      newState = newState.copyWith(
        stats: newState.stats.copyWith(
          str: newState.stats.str + (r.str ?? 0),
          agi: newState.stats.agi + (r.agi ?? 0),
          per: newState.stats.per + (r.per ?? 0),
          intStat: newState.stats.intStat + (r.intStat ?? 0),
          vit: newState.stats.vit + (r.vit ?? 0),
        )
      );
      // Recalc HP/MP
      if ((r.vit ?? 0) > 0) {
        newState = newState.copyWith(maxHp: (100 + newState.level * 10 + newState.stats.vit * 5).floor());
        newState = newState.copyWith(hp: newState.maxHp);
      }
      if ((r.intStat ?? 0) > 0) {
        newState = newState.copyWith(maxMp: (10 + newState.level * 2 + newState.stats.intStat * 2).floor());
        newState = newState.copyWith(mp: newState.maxMp);
      }
    }

    // Add items
    if (quest.itemRewards != null) {
      for (var item in quest.itemRewards!) {
         newState = _addItemInternal(newState, item);
      }
    }

    final minutes = totalMinutes ?? quest.expectedMinutes ?? 1;
    final weighted = _applyTaskWeighting(newState.levelTaskWeights, quest, minutes);
    newState = newState.copyWith(levelTaskWeights: weighted);

    // Skill XP progression (independent from player XP).
    int earnedXp = 0;
    if (earnedExpOverride != null) {
      earnedXp = earnedExpOverride;
    } else {
      final breakdown = _calculateMissionXpBreakdown(actualMinutes: minutes, quest: quest);
      earnedXp = breakdown['total'] ?? 0;
    }
    if (quest.skillId != null && earnedXp > 0) {
      newState = _addSkillExpInternal(newState, quest.skillId!, earnedXp);
    }

    state = newState;
    addExp(earnedXp);
  }

  UserStats _addSkillExpInternal(UserStats currentStats, String skillId, int amount) {
    if (amount <= 0) return currentStats;

    final idx = currentStats.skills.indexWhere((s) => s.id == skillId);
    if (idx == -1) return currentStats;

    final updatedSkills = List<SkillGoal>.from(currentStats.skills);
    final skill = updatedSkills[idx];

    int level = max(1, skill.level);
    int exp = max(0, skill.exp + amount);

    while (exp >= SkillGoal.expToNextLevelFor(level)) {
      exp -= SkillGoal.expToNextLevelFor(level);
      level += 1;
    }

    updatedSkills[idx] = skill.copyWith(level: level, exp: exp);
    return currentStats.copyWith(skills: updatedSkills);
  }

  UserStats _addItemInternal(UserStats currentStats, InventoryItem item) {
     final existingIndex = currentStats.inventory.indexWhere((i) => i.id == item.id);
     List<InventoryItem> newInventory = List.from(currentStats.inventory);
     
     if (existingIndex != -1) {
       final existing = newInventory[existingIndex];
       newInventory[existingIndex] = InventoryItem(
         id: existing.id,
         name: existing.name,
         type: existing.type,
         rarity: existing.rarity,
         description: existing.description,
         quantity: existing.quantity + item.quantity,
         stats: existing.stats,
         value: existing.value,
         imageUrl: existing.imageUrl,
       );
     } else {
       newInventory.add(item);
     }
     return currentStats.copyWith(inventory: newInventory);
  }

  /// Runs a one-tap fight and applies the result to state.
  ///
  /// This intentionally keeps combat instantaneous (no separate combat session state yet).
  /// For deterministic behavior in tests, pass a seeded [rng].
  CombatResult fightEnemy(CombatEnemy enemy, {Random? rng}) {
    final result = CombatService.simulateFight(
      player: state,
      enemy: enemy,
      rng: rng ?? _combatRng,
    );

    if (!result.executed) {
      return result;
    }

    var newState = state.copyWith(
      hp: result.hpAfter,
      mp: result.mpAfter,
      gold: state.gold + result.goldGained,
    );

    for (final item in result.itemDrops) {
      newState = _addItemInternal(newState, item);
    }

    if (result.equipmentDrops.isNotEmpty) {
      final updatedEquipment = List<Equipment>.from(newState.equipment)..addAll(result.equipmentDrops);
      newState = newState.copyWith(equipment: updatedEquipment);
    }

    state = newState;
    _saveUserStats();

    if (result.expGained > 0) {
      addExp(result.expGained);
    } else {
      _saveUserStats();
    }

    return result;
  }

  /// Boosts a mission's progress as a side-effect of winning combat.
  ///
  /// This does NOT complete the quest and does NOT grant quest rewards.
  /// The user can still complete the mission normally (usually via Focus).
  ///
  /// Returns the actual progress delta applied (0 if no change).
  int boostQuestProgressFromCombat({
    required String questId,
    required CombatEnemy enemy,
  }) {
    final idx = state.quests.indexWhere((q) => q.id == questId);
    if (idx == -1) return 0;

    final quest = state.quests[idx];
    if (quest.completed) return 0;

    final boost = CombatService.missionProgressBoostForTier(enemy.tier);
    if (boost <= 0) return 0;

    final before = quest.progress;
    final after = (before + boost).clamp(0, 100);
    final delta = after - before;
    if (delta == 0) return 0;

    final updatedQuests = List<Quest>.from(state.quests);
    updatedQuests[idx] = quest.copyWith(progress: after);
    state = state.copyWith(quests: updatedQuests);
    _saveUserStats();
    return delta;
  }

  bool startFocus(String questId, {String? heading}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var focus = state.focus;

    // Enforce: only one non-abandoned mission can be open at a time.
    // If another mission is paused/running, block starting a different one.
    final blocking = focus.openSessions.cast<FocusOpenSession?>().firstWhere(
      (s) => s != null && s.status != 'abandoned' && s.questId != questId,
      orElse: () => null,
    );
    if (blocking != null) {
      return false;
    }

    // If already running this mission, no-op.
    if (focus.activeSessionId != null) {
      final activeIdx = focus.openSessions.indexWhere((s) => s.id == focus.activeSessionId);
      if (activeIdx != -1) {
        final s = focus.openSessions[activeIdx];
        if (s.questId == questId && s.status == 'running') {
          return true;
        }
      }
    }
    
    // Pause active session if any
    if (focus.activeSessionId != null) {
        final activeIdx = focus.openSessions.indexWhere((s) => s.id == focus.activeSessionId);
        if (activeIdx != -1) {
             final s = focus.openSessions[activeIdx];
             if (s.questId != questId) {
                // Pause it
                final segments = List<FocusSegment>.from(s.segments);
                if (segments.isNotEmpty && segments.last.endMs == null) {
                    segments.last = FocusSegment(startMs: segments.last.startMs, endMs: now);
                }
                
                final updatedSessions = List<FocusOpenSession>.from(focus.openSessions);
                updatedSessions[activeIdx] = FocusOpenSession(
                    id: s.id,
                    questId: s.questId,
                    heading: s.heading, // Maintain heading
                    createdAt: s.createdAt,
                    status: 'paused',
                    segments: segments
                );
                focus = FocusState(
                    activeSessionId: null,
                    openSessions: updatedSessions,
                    history: focus.history,
                    settings: focus.settings
                );
             }
        }
    }

    // Check if new session exists
    final outputSessions = List<FocusOpenSession>.from(focus.openSessions);
    String newActiveId = questId; // Default ID logic from web app seemed to treat questId as sessionId sometimes

    // Simplify logic: check if there is an open session for this quest
    int existingIdx = outputSessions.indexWhere((s) => s.questId == questId);
    
    if (existingIdx != -1) {
        final existing = outputSessions[existingIdx];
        newActiveId = existing.id;
        final segments = List<FocusSegment>.from(existing.segments);
        segments.add(FocusSegment(startMs: now));
        
        outputSessions[existingIdx] = FocusOpenSession(
            id: existing.id,
            questId: existing.questId,
            heading: existing.heading, // Maintain heading
            createdAt: existing.createdAt,
            status: 'running',
            segments: segments
        );
    } else {
        // Create new
        newActiveId = _uuid.v4(); // Or use questId if unique enough? Web app used questId mostly
        if (questId.startsWith('custom-')) newActiveId = questId;

        outputSessions.add(FocusOpenSession(
            id: newActiveId,
            questId: questId,
            heading: heading, // Pass the heading
            createdAt: now,
            status: 'running',
            segments: [FocusSegment(startMs: now)]
        ));
    }

    state = state.copyWith(focus: FocusState(
        activeSessionId: newActiveId,
        openSessions: outputSessions,
        history: focus.history,
        settings: focus.settings
    ));

    // Resuming (or starting) should cancel any paused reminder for this session.
    unawaited(NotificationService.instance.cancelPausedMissionReminder(newActiveId));
    _saveUserStats();
    return true;
  }

  void updateFocusSettings(FocusSettings settings) {
    final prevEnabled = state.focus.settings.notifications.enabled;
    state = state.copyWith(
      focus: FocusState(
        activeSessionId: state.focus.activeSessionId,
        openSessions: state.focus.openSessions,
        history: state.focus.history,
        settings: settings,
      ),
    );
    _saveUserStats();

    if (!prevEnabled && settings.notifications.enabled) {
      unawaited(NotificationService.instance.requestPermissions());
    }
    _resyncAllNotifications();
  }

  void pauseFocus() {
    final activeId = state.focus.activeSessionId;
    if (activeId == null) return;

    final focus = state.focus;
    final idx = focus.openSessions.indexWhere((s) => s.id == activeId);
    if (idx == -1) return;

    final session = focus.openSessions[idx];
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Close last segment
    final segments = List<FocusSegment>.from(session.segments);
    if (segments.isNotEmpty && segments.last.endMs == null) {
      segments.last = FocusSegment(startMs: segments.last.startMs, endMs: now);
    }

    final updatedSessions = List<FocusOpenSession>.from(focus.openSessions);
    updatedSessions[idx] = FocusOpenSession(
      id: session.id,
      questId: session.questId,
      heading: session.heading,
      createdAt: session.createdAt,
      status: 'paused',
      segments: segments,
    );

    final pausedSession = updatedSessions[idx];

    state = state.copyWith(
      focus: FocusState(
        activeSessionId: null, // No active session matches web behavior usually, or keep it set but paused? Web clears active.
        openSessions: updatedSessions,
        history: focus.history,
        settings: focus.settings,
      ),
    );

    _syncPausedReminderForSession(pausedSession);
    _saveUserStats();
  }

  void abandonMission(String sessionId) {
    final focus = state.focus;
    final idx = focus.openSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    
    final updatedSessions = List<FocusOpenSession>.from(focus.openSessions);
    final session = updatedSessions[idx];
    
    // If it was active, clear active
    String? newActiveId = focus.activeSessionId;
    if (newActiveId == sessionId) {
      newActiveId = null;
    }

    // Close last segment if still running so UI freezes elapsed time.
    final now = DateTime.now().millisecondsSinceEpoch;
    final segments = List<FocusSegment>.from(session.segments);
    if (segments.isNotEmpty && segments.last.endMs == null) {
      segments.last = FocusSegment(startMs: segments.last.startMs, endMs: now);
    }

    // Update status
    updatedSessions[idx] = FocusOpenSession(
      id: session.id,
      questId: session.questId,
      heading: session.heading,
      createdAt: session.createdAt,
      status: 'abandoned',
      segments: segments,
    );

    state = state.copyWith(
      focus: FocusState(
        activeSessionId: newActiveId,
        openSessions: updatedSessions,
        history: focus.history,
        settings: focus.settings,
      ),
    );

    // Mission is no longer paused/runnable; clear any paused reminder.
    unawaited(NotificationService.instance.cancelPausedMissionReminder(sessionId));
    _saveUserStats();
  }

  /// Restores an existing open focus session (Undo helper).
  ///
  /// Replaces the session by id; if not found, this no-ops.
  ///
  /// If [activeSessionId] is provided, it becomes the current active session id.
  /// Paused mission notifications are re-synced based on the restored status.
  void restoreOpenSession(FocusOpenSession session, {String? activeSessionId}) {
    final focus = state.focus;
    final idx = focus.openSessions.indexWhere((s) => s.id == session.id);
    if (idx == -1) return;

    final updatedSessions = List<FocusOpenSession>.from(focus.openSessions);
    updatedSessions[idx] = session;

    // Only set active if the id exists in openSessions.
    String? newActiveId = activeSessionId;
    if (newActiveId != null && !updatedSessions.any((s) => s.id == newActiveId)) {
      newActiveId = null;
    }

    state = state.copyWith(
      focus: FocusState(
        activeSessionId: newActiveId,
        openSessions: updatedSessions,
        history: focus.history,
        settings: focus.settings,
      ),
    );

    _syncPausedReminderForSession(session);
    _saveUserStats();
  }

  void rejoinMission(String missionId) {
    // Resume session associated with this mission/id
    // Logic similar to startFocus but specifically targeting an existing abandoned/paused session
    startFocus(missionId);
  }

  void completeMission(String questId, int elapsedMs) {
    // 1. Find session and close it
    final focus = state.focus;
    // Note: questId passed here might be the session ID for custom sessions, or quest ID for quests.
    // Logic: find open session
    final sessionIdx = focus.openSessions.indexWhere((s) => s.id == questId || s.questId == questId);
    Quest? quest;
    try {
      quest = state.quests.firstWhere((q) => q.id == questId);
    } catch (_) {}
    
    if (sessionIdx != -1) {
       final session = focus.openSessions[sessionIdx];
       final now = DateTime.now().millisecondsSinceEpoch;

       // Session is being closed: clear any notifications linked to it.
       unawaited(NotificationService.instance.cancelPausedMissionReminder(session.id));
       if (!session.questId.startsWith('custom-')) {
        unawaited(NotificationService.instance.cancelDueDateReminder(session.questId));
       }
       
       // Close segment if running
       final segments = List<FocusSegment>.from(session.segments);
       if (segments.isNotEmpty && segments.last.endMs == null) {
          segments.last = FocusSegment(startMs: segments.last.startMs, endMs: now);
       }
       
       // Create log
       final minutes = (elapsedMs / 60000).ceil();
       final isCustomSession = session.questId.startsWith('custom-') || questId.startsWith('custom-');
       const customBaseXpPerMinute = 1;

       final Map<String, int?> breakdown = quest != null
           ? _calculateMissionXpBreakdown(actualMinutes: minutes, quest: quest)
           : <String, int?>{
               'base': max(1, minutes) * customBaseXpPerMinute,
               'bonus': 0,
               'penalty': 0,
               'total': max(1, minutes) * customBaseXpPerMinute,
               'expected': null,
               'delta': null,
             };

       final log = FocusSessionLogEntry(
         id: session.id,
         questId: session.questId,
         startedAt: session.createdAt,
         endedAt: now,
         segments: segments,
         totalMs: elapsedMs,
         earnedExp: breakdown['total'] ?? 0,
         expectedMinutes: quest != null ? breakdown['expected'] : null,
         deltaMinutes: quest != null ? breakdown['delta'] : null,
         baseXp: breakdown['base'],
         bonusXp: breakdown['bonus'],
         penaltyXp: breakdown['penalty'],
         difficulty: quest?.difficulty ?? (isCustomSession ? 'CUSTOM' : null),
         questTitle: quest?.title ?? (isCustomSession ? (session.heading?.trim().isNotEmpty == true ? session.heading!.trim() : 'Custom Session') : null),
       );
       
       // Remove from open sessions, add to history
       final newOpen = List<FocusOpenSession>.from(focus.openSessions)..removeAt(sessionIdx);
       final newHistory = List<FocusSessionLogEntry>.from(focus.history)..add(log);
       
       state = state.copyWith(
         focus: FocusState(
           activeSessionId: null,
           openSessions: newOpen,
           history: newHistory,
           settings: focus.settings,
         )
       );
       
       if (quest == null || questId.startsWith('custom-')) {
         addExp(log.earnedExp);
       }
    }
    
    // 2. Mark quest complete if it is a quest
    if (!questId.startsWith('custom-')) {
       final minutes = (elapsedMs / 60000).ceil();
       final breakdown = quest != null
           ? _calculateMissionXpBreakdown(actualMinutes: minutes, quest: quest)
           : null;
       completeQuest(
         questId,
         totalMinutes: minutes,
         earnedExpOverride: breakdown != null ? breakdown['total'] : null,
       );
    }
    _saveUserStats();
  }

  void useItem(String itemId) {
    final idx = state.inventory.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    
    final item = state.inventory[idx];
    
    // Apply effects (simplified for now)
    // In real app, item.stats would define what it does (Hp restore etc)
    // Assuming simple restore for now
    if (item.type == 'Consumable') {
        // Remove 1 quantity
        List<InventoryItem> newInventory = List.from(state.inventory);
        if (item.quantity > 1) {
           newInventory[idx] = InventoryItem(
             id: item.id,
             name: item.name,
             type: item.type,
             rarity: item.rarity,
             description: item.description,
             quantity: item.quantity - 1,
             stats: item.stats, // e.g. {"hp": 50}
             value: item.value,
             imageUrl: item.imageUrl
           );
        } else {
           newInventory.removeAt(idx);
        }
        
        // Apply stats
        int newHp = state.hp;
        int newMp = state.mp;
        
        if (item.stats?.hp != null) {
           newHp = min(state.maxHp, newHp + item.stats!.hp!);
        }
        if (item.stats?.mp != null) {
           newMp = min(state.maxMp, newMp + item.stats!.mp!);
        }
        
        state = state.copyWith(
           inventory: newInventory,
           hp: newHp,
           mp: newMp
        );
        _saveUserStats();
    }
  }
}
