import '../models/user_stats.dart';

/// Deterministic (achievement-based) unlock rules for Jobs and Titles.
///
/// This replaces the old time-based / random unlocking behavior.
class JobTitleUnlockService {
  const JobTitleUnlockService();

  static List<UnlockRecommendation> computeUnlocks({
    required UserStats stats,
    required List<String> jobCatalog,
    required List<String> titleCatalog,
    int? nowMs,
  }) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final p = ProgressSnapshot.from(stats, nowMs: now);

    final out = <UnlockRecommendation>[];

    for (final job in jobCatalog) {
      if (stats.unlockedJobs.contains(job)) continue;
      assert(_jobRules.containsKey(job), 'Missing unlock rule for job: $job');
      final rule = _jobRules[job];
      if (rule == null) continue;
      if (rule.isMet(p)) {
        out.add(
          UnlockRecommendation(
            type: UnlockType.job,
            name: job,
            reason: rule.reason,
          ),
        );
      }
    }

    for (final title in titleCatalog) {
      if (stats.unlockedTitles.contains(title)) continue;
      assert(_titleRules.containsKey(title), 'Missing unlock rule for title: $title');
      final rule = _titleRules[title];
      if (rule == null) continue;
      if (rule.isMet(p)) {
        out.add(
          UnlockRecommendation(
            type: UnlockType.title,
            name: title,
            reason: rule.reason,
          ),
        );
      }
    }

    // Stable order: unlock earlier catalog items first.
    out.sort((a, b) {
      final aIdx = a.type == UnlockType.job ? jobCatalog.indexOf(a.name) : titleCatalog.indexOf(a.name);
      final bIdx = b.type == UnlockType.job ? jobCatalog.indexOf(b.name) : titleCatalog.indexOf(b.name);
      if (a.type != b.type) return a.type.index.compareTo(b.type.index);
      return aIdx.compareTo(bIdx);
    });

    return out;
  }

  static final Map<String, _Rule> _jobRules = {
    'Novice': _Rule.always('Default starter job.'),
    'Apprentice': _Rule.levelAtLeast(3, 'Reach level 3.'),
    'Adventurer': _Rule.completedQuestsAtLeast(5, 'Complete 5 missions.'),
    'Scout': _Rule.focusSessionsAtLeast(5, 'Finish 5 focus sessions.'),
    'Tactician': _Rule.completedHighPriorityAtLeast(3, 'Complete 3 high-priority missions.'),
    'Artisan': _Rule.completedTimedMissionsAtLeast(10, 'Complete 10 missions with an expected duration.'),
    'Scholar': _Rule.skillsAtLeast(3, 'Create 3 skill goals.'),
    'Sentinel': _Rule.totalFocusMinutesAtLeast(600, 'Accumulate 10 hours of focus time.'),
    'Pathfinder': _Rule.userEventsAtLeast(10, 'Add 10 calendar events.'),
    'Strategist': _Rule.custom(
      reason: 'Complete 30 missions and 10 high-priority missions.',
      isMet: (p) => p.completedQuests >= 30 && p.completedHighPriority >= 10,
    ),
    'Warden': _Rule.breaksTakenAtLeast(10, 'Take 10 breaks when offered.'),
    'Chronomancer': _Rule.totalFocusMinutesAtLeast(3000, 'Accumulate 50 hours of focus time.'),
    'Seeker': _Rule.completedQuestsAtLeast(60, 'Complete 60 missions.'),
    'Craftmaster': _Rule.custom(
      reason: 'Create 6 skill goals and complete 40 missions.',
      isMet: (p) => p.skills >= 6 && p.completedQuests >= 40,
    ),
    'Field Medic': _Rule.breaksTakenAtLeast(25, 'Take 25 breaks when offered.'),
    'Navigator': _Rule.userEventsAtLeast(30, 'Add 30 calendar events.'),
    'Archivist': _Rule.focusSessionsAtLeast(100, 'Finish 100 focus sessions.'),
    'Vanguard': _Rule.custom(
      reason: 'Reach level 20 and complete 80 missions.',
      isMet: (p) => p.level >= 20 && p.completedQuests >= 80,
    ),
    'Ranger': _Rule.completedDailyAtLeast(30, 'Complete 30 daily missions.'),
    'Commander': _Rule.custom(
      reason: 'Reach level 25, complete 120 missions, and accumulate 100 hours of focus time.',
      isMet: (p) => p.level >= 25 && p.completedQuests >= 120 && p.totalFocusMinutes >= 6000,
    ),
  };

  static final Map<String, _Rule> _titleRules = {
    'Rookie': _Rule.always('Default starter title.'),
    'The Focused': _Rule.totalFocusMinutesAtLeast(120, 'Accumulate 2 hours of focus time.'),
    'The Patient': _Rule.breaksTakenAtLeast(5, 'Take 5 breaks when offered.'),
    'The Persistent': _Rule.focusSessionsAtLeast(15, 'Finish 15 focus sessions.'),
    'The Steady': _Rule.custom(
      reason: 'Accumulate 10 hours of focus time and complete 10 missions.',
      isMet: (p) => p.totalFocusMinutes >= 600 && p.completedQuests >= 10,
    ),
    'Task Breaker': _Rule.completedQuestsAtLeast(25, 'Complete 25 missions.'),
    'Timekeeper': _Rule.totalFocusMinutesAtLeast(1500, 'Accumulate 25 hours of focus time.'),
    'Momentum Builder': _Rule.custom(
      reason: 'Build momentum: complete 10 missions (or finish 10 focus sessions) in the last 7 days.',
      isMet: (p) => p.completedQuestsLast7Days >= 10 || p.focusSessionsLast7Days >= 10,
    ),
    'Mindful Worker': _Rule.breaksSkippedAtLeast(10, 'Skip 10 offered breaks.'),
    'Storm Calmer': _Rule.custom(
      reason: 'Recover quickly: abandon at least 1 mission, then complete 10 missions.',
      isMet: (p) => p.missionsAbandoned >= 1 && p.completedQuests >= 10,
    ),
    'The Unshaken': _Rule.completedDifficultySAtLeast(5, 'Complete 5 S-difficulty missions.'),
    'The Reliable': _Rule.completedQuestsAtLeast(50, 'Complete 50 missions.'),
    'The Determined': _Rule.levelAtLeast(10, 'Reach level 10.'),
    'The Prepared': _Rule.custom(
      reason: 'Plan ahead: create 10 missions with due dates and complete 10 missions.',
      isMet: (p) => p.questsWithDueDates >= 10 && p.completedQuests >= 10,
    ),
    'The Unstoppable': _Rule.completedLast30DaysAtLeast(30, 'Complete 30 missions in the last 30 days.'),
    'The Disciplined': _Rule.completedDailyAtLeast(20, 'Complete 20 daily missions.'),
    'The Strategist': _Rule.completedHighPriorityAtLeast(15, 'Complete 15 high-priority missions.'),
    'The Builder': _Rule.custom(
      reason: 'Build your system: create 30 missions and 4 skill goals.',
      isMet: (p) => p.totalMissionsCreated >= 30 && p.skills >= 4,
    ),
    'The Finisher': _Rule.completedQuestsAtLeast(80, 'Complete 80 missions.'),
    'The Quiet Force': _Rule.custom(
      reason: 'Accumulate 83 hours of focus time, take 30 breaks, and complete 100 missions.',
      isMet: (p) => p.totalFocusMinutes >= 5000 && p.breaksTaken >= 30 && p.completedQuests >= 100,
    ),
  };
}

enum UnlockType { job, title }

class UnlockRecommendation {
  final UnlockType type;
  final String name;
  final String reason;

  const UnlockRecommendation({
    required this.type,
    required this.name,
    required this.reason,
  });

  String get typeLabel => type == UnlockType.job ? 'Job' : 'Title';
}

class ProgressSnapshot {
  final int level;
  final int totalFocusMinutes;
  final int focusSessions;
  final int focusSessionsLast7Days;
  final int completedQuests;
  final int completedQuestsLast7Days;
  final int completedQuestsLast30Days;
  final int completedHighPriority;
  final int completedDifficultyS;
  final int completedDaily;
  final int completedTimedMissions;
  final int questsWithDueDates;
  final int totalMissionsCreated;
  final int skills;
  final int userEvents;
  final int breaksTaken;
  final int breaksSkipped;
  final int missionsAbandoned;

  const ProgressSnapshot({
    required this.level,
    required this.totalFocusMinutes,
    required this.focusSessions,
    required this.focusSessionsLast7Days,
    required this.completedQuests,
    required this.completedQuestsLast7Days,
    required this.completedQuestsLast30Days,
    required this.completedHighPriority,
    required this.completedDifficultyS,
    required this.completedDaily,
    required this.completedTimedMissions,
    required this.questsWithDueDates,
    required this.totalMissionsCreated,
    required this.skills,
    required this.userEvents,
    required this.breaksTaken,
    required this.breaksSkipped,
    required this.missionsAbandoned,
  });

  factory ProgressSnapshot.from(UserStats stats, {required int nowMs}) {
    final completed = stats.quests.where((q) => q.completed).toList(growable: false);

    final totalFocusMs = stats.focus.history.fold<int>(0, (sum, h) => sum + h.totalMs);
    final totalFocusMinutes = totalFocusMs <= 0 ? 0 : (totalFocusMs / 60000).floor();

    final sevenDaysAgo = nowMs - const Duration(days: 7).inMilliseconds;
    final thirtyDaysAgo = nowMs - const Duration(days: 30).inMilliseconds;

    final completedLast7 = completed.where((q) => (q.completedAt ?? 0) >= sevenDaysAgo).length;
    final completedLast30 = completed.where((q) => (q.completedAt ?? 0) >= thirtyDaysAgo).length;

    final focusSessions = stats.focus.history.length;
    final focusLast7 = stats.focus.history.where((h) => h.endedAt >= sevenDaysAgo).length;

    final completedHighPriority = completed.where((q) => q.priority.toLowerCase() == 'high').length;
    final completedS = completed.where((q) => q.difficulty.toUpperCase() == 'S').length;
    final completedDaily = completed.where((q) => (q.frequency ?? '').toLowerCase() == 'daily').length;
    final completedTimed = completed.where((q) => (q.expectedMinutes ?? 0) > 0).length;

    final dueDateCount = stats.quests.where((q) => q.dueDateMs != null).length;

    int countEvents(String type) => stats.focusEvents.where((e) => e.type == type).length;

    return ProgressSnapshot(
      level: stats.level,
      totalFocusMinutes: totalFocusMinutes,
      focusSessions: focusSessions,
      focusSessionsLast7Days: focusLast7,
      completedQuests: completed.length,
      completedQuestsLast7Days: completedLast7,
      completedQuestsLast30Days: completedLast30,
      completedHighPriority: completedHighPriority,
      completedDifficultyS: completedS,
      completedDaily: completedDaily,
      completedTimedMissions: completedTimed,
      questsWithDueDates: dueDateCount,
      totalMissionsCreated: stats.quests.length,
      skills: stats.skills.length,
      userEvents: stats.userEvents.length,
      breaksTaken: countEvents('break_taken'),
      breaksSkipped: countEvents('break_skipped'),
      missionsAbandoned: countEvents('mission_abandon'),
    );
  }
}

class _Rule {
  final String reason;
  final bool Function(ProgressSnapshot) isMet;

  const _Rule({required this.reason, required this.isMet});

  factory _Rule.always(String reason) => _Rule(reason: reason, isMet: (_) => true);

  factory _Rule.levelAtLeast(int n, String reason) => _Rule(reason: reason, isMet: (p) => p.level >= n);

  factory _Rule.totalFocusMinutesAtLeast(int n, String reason) =>
      _Rule(reason: reason, isMet: (p) => p.totalFocusMinutes >= n);

  factory _Rule.focusSessionsAtLeast(int n, String reason) => _Rule(reason: reason, isMet: (p) => p.focusSessions >= n);

  factory _Rule.completedQuestsAtLeast(int n, String reason) =>
      _Rule(reason: reason, isMet: (p) => p.completedQuests >= n);

  factory _Rule.completedHighPriorityAtLeast(int n, String reason) =>
      _Rule(reason: reason, isMet: (p) => p.completedHighPriority >= n);

  factory _Rule.completedDifficultySAtLeast(int n, String reason) =>
      _Rule(reason: reason, isMet: (p) => p.completedDifficultyS >= n);

  factory _Rule.completedDailyAtLeast(int n, String reason) => _Rule(reason: reason, isMet: (p) => p.completedDaily >= n);

  factory _Rule.completedTimedMissionsAtLeast(int n, String reason) =>
      _Rule(reason: reason, isMet: (p) => p.completedTimedMissions >= n);

  factory _Rule.skillsAtLeast(int n, String reason) => _Rule(reason: reason, isMet: (p) => p.skills >= n);

  factory _Rule.userEventsAtLeast(int n, String reason) => _Rule(reason: reason, isMet: (p) => p.userEvents >= n);

  factory _Rule.breaksTakenAtLeast(int n, String reason) => _Rule(reason: reason, isMet: (p) => p.breaksTaken >= n);

  factory _Rule.breaksSkippedAtLeast(int n, String reason) => _Rule(reason: reason, isMet: (p) => p.breaksSkipped >= n);

  factory _Rule.completedLast30DaysAtLeast(int n, String reason) =>
      _Rule(reason: reason, isMet: (p) => p.completedQuestsLast30Days >= n);

  factory _Rule.custom({required String reason, required bool Function(ProgressSnapshot) isMet}) => _Rule(reason: reason, isMet: isMet);
}
