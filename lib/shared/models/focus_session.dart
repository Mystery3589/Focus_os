
class FocusSettings {
  final String mode; // "pomodoro", "stopwatch"
  final PomodoroSettings pomodoro;
  final XpSettings xp;
  final NotificationSettings notifications;

  FocusSettings({
    required this.mode,
    required this.pomodoro,
    required this.xp,
    required this.notifications,
  });

  FocusSettings copyWith({
    String? mode,
    PomodoroSettings? pomodoro,
    XpSettings? xp,
    NotificationSettings? notifications,
  }) {
    return FocusSettings(
      mode: mode ?? this.mode,
      pomodoro: pomodoro ?? this.pomodoro,
      xp: xp ?? this.xp,
      notifications: notifications ?? this.notifications,
    );
  }

  factory FocusSettings.fromJson(Map<String, dynamic> json) {
    return FocusSettings(
      mode: json['mode'] ?? 'pomodoro',
      pomodoro: PomodoroSettings.fromJson(json['pomodoro'] ?? {}),
      xp: XpSettings.fromJson(json['xp'] ?? {}),
      notifications: NotificationSettings.fromJson(json['notifications'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'pomodoro': pomodoro.toJson(),
      'xp': xp.toJson(),
      'notifications': notifications.toJson(),
    };
  }
  
  // Default settings
  static FocusSettings defaultSettings() {
    return FocusSettings(
      mode: 'pomodoro',
      pomodoro: PomodoroSettings(focusMinutes: 25, breakMinutes: 5),
      xp: XpSettings(baseXpPerMinute: 1),
      notifications: NotificationSettings.defaultSettings(),
    );
  }
}

class NotificationSettings {
  final bool enabled;
  final bool pausedMissionReminder;
  final int pausedMissionReminderMinutes;
  final bool dueDateReminder;
  final int dueDateReminderHour; // 0-23

  const NotificationSettings({
    required this.enabled,
    required this.pausedMissionReminder,
    required this.pausedMissionReminderMinutes,
    required this.dueDateReminder,
    required this.dueDateReminderHour,
  });

  static NotificationSettings defaultSettings() {
    return const NotificationSettings(
      enabled: false,
      pausedMissionReminder: true,
      pausedMissionReminderMinutes: 30,
      dueDateReminder: true,
      dueDateReminderHour: 9,
    );
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? pausedMissionReminder,
    int? pausedMissionReminderMinutes,
    bool? dueDateReminder,
    int? dueDateReminderHour,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      pausedMissionReminder: pausedMissionReminder ?? this.pausedMissionReminder,
      pausedMissionReminderMinutes: pausedMissionReminderMinutes ?? this.pausedMissionReminderMinutes,
      dueDateReminder: dueDateReminder ?? this.dueDateReminder,
      dueDateReminderHour: dueDateReminderHour ?? this.dueDateReminderHour,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] ?? false,
      pausedMissionReminder: json['pausedMissionReminder'] ?? true,
      pausedMissionReminderMinutes: json['pausedMissionReminderMinutes'] ?? 30,
      dueDateReminder: json['dueDateReminder'] ?? true,
      dueDateReminderHour: json['dueDateReminderHour'] ?? 9,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'pausedMissionReminder': pausedMissionReminder,
      'pausedMissionReminderMinutes': pausedMissionReminderMinutes,
      'dueDateReminder': dueDateReminder,
      'dueDateReminderHour': dueDateReminderHour,
    };
  }
}

class PomodoroSettings {
  final int focusMinutes;
  final int breakMinutes;

  PomodoroSettings({required this.focusMinutes, required this.breakMinutes});

  PomodoroSettings copyWith({
    int? focusMinutes,
    int? breakMinutes,
  }) {
    return PomodoroSettings(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
    );
  }

  factory PomodoroSettings.fromJson(Map<String, dynamic> json) {
    return PomodoroSettings(
      focusMinutes: json['focusMinutes'] ?? 25,
      breakMinutes: json['breakMinutes'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'focusMinutes': focusMinutes,
      'breakMinutes': breakMinutes,
    };
  }
}

class XpSettings {
  final int baseXpPerMinute;

  XpSettings({required this.baseXpPerMinute});

  factory XpSettings.fromJson(Map<String, dynamic> json) {
    return XpSettings(
      baseXpPerMinute: json['baseXpPerMinute'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseXpPerMinute': baseXpPerMinute,
    };
  }
}

class FocusSegment {
  final int startMs;
  final int? endMs;

  FocusSegment({required this.startMs, this.endMs});

  factory FocusSegment.fromJson(Map<String, dynamic> json) {
    return FocusSegment(
      startMs: json['startMs'],
      endMs: json['endMs'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startMs': startMs,
      'endMs': endMs,
    };
  }
}

class FocusOpenSession {
  final String id;
  final String questId;
  final String? heading; // For custom sessions
  final int createdAt;
  final String status; // "running", "paused", "abandoned"
  final List<FocusSegment> segments;

  FocusOpenSession({
    required this.id,
    required this.questId,
    this.heading,
    required this.createdAt,
    required this.status,
    required this.segments,
  });

  factory FocusOpenSession.fromJson(Map<String, dynamic> json) {
    return FocusOpenSession(
      id: json['id'],
      questId: json['questId'],
      heading: json['heading'],
      createdAt: json['createdAt'],
      status: json['status'],
      segments: (json['segments'] as List).map((s) => FocusSegment.fromJson(s)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questId': questId,
      'heading': heading,
      'createdAt': createdAt,
      'status': status,
      'segments': segments.map((s) => s.toJson()).toList(),
    };
  }
}

class FocusSessionLogEntry {
  final String id;
  final String questId;
  final int startedAt;
  final int endedAt;
  final List<FocusSegment> segments;
  final int totalMs;
  final int earnedExp;
  final int? expectedMinutes;
  final int? deltaMinutes;
  final int? baseXp;
  final int? bonusXp;
  final int? penaltyXp;
  final String? difficulty;
  final String? questTitle;

  FocusSessionLogEntry({
    required this.id,
    required this.questId,
    required this.startedAt,
    required this.endedAt,
    required this.segments,
    required this.totalMs,
    required this.earnedExp,
    this.expectedMinutes,
    this.deltaMinutes,
    this.baseXp,
    this.bonusXp,
    this.penaltyXp,
    this.difficulty,
    this.questTitle,
  });

  factory FocusSessionLogEntry.fromJson(Map<String, dynamic> json) {
    return FocusSessionLogEntry(
      id: json['id'],
      questId: json['questId'],
      startedAt: json['startedAt'],
      endedAt: json['endedAt'],
      segments: (json['segments'] as List).map((s) => FocusSegment.fromJson(s)).toList(),
      totalMs: json['totalMs'],
      earnedExp: json['earnedExp'],
      expectedMinutes: json['expectedMinutes'],
      deltaMinutes: json['deltaMinutes'],
      baseXp: json['baseXp'],
      bonusXp: json['bonusXp'],
      penaltyXp: json['penaltyXp'],
      difficulty: json['difficulty'],
      questTitle: json['questTitle'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questId': questId,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'segments': segments.map((s) => s.toJson()).toList(),
      'totalMs': totalMs,
      'earnedExp': earnedExp,
      'expectedMinutes': expectedMinutes,
      'deltaMinutes': deltaMinutes,
      'baseXp': baseXp,
      'bonusXp': bonusXp,
      'penaltyXp': penaltyXp,
      'difficulty': difficulty,
      'questTitle': questTitle,
    };
  }
}

class FocusState {
  final String? activeSessionId;
  final List<FocusOpenSession> openSessions;
  final List<FocusSessionLogEntry> history;
  final FocusSettings settings;

  FocusState({
    this.activeSessionId,
    required this.openSessions,
    required this.history,
    required this.settings,
  });
  
  FocusState copyWith({
    String? activeSessionId,
    List<FocusOpenSession>? openSessions,
    List<FocusSessionLogEntry>? history,
    FocusSettings? settings,
  }) {
    return FocusState(
      activeSessionId: activeSessionId ?? this.activeSessionId,
      openSessions: openSessions ?? this.openSessions,
      history: history ?? this.history,
      settings: settings ?? this.settings,
    );
  }

  factory FocusState.fromJson(Map<String, dynamic> json) {
    return FocusState(
      activeSessionId: json['activeSessionId'],
      openSessions: (json['openSessions'] as List?)?.map((s) => FocusOpenSession.fromJson(s)).toList() ?? [],
      history: (json['history'] as List?)?.map((s) => FocusSessionLogEntry.fromJson(s)).toList() ?? [],
      settings: json['settings'] != null ? FocusSettings.fromJson(json['settings']) : FocusSettings.defaultSettings(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeSessionId': activeSessionId,
      'openSessions': openSessions.map((s) => s.toJson()).toList(),
      'history': history.map((s) => s.toJson()).toList(),
      'settings': settings.toJson(),
    };
  }
}
