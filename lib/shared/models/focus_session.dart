
class WhiteNoiseSettings {
  /// Master toggle.
  final bool enabled;

  /// "off" | "rain" | "thunderstorm" (or legacy "thunder") | "custom"
  final String preset;

  /// 0.0 - 1.0
  final double volume;

  /// Absolute file path when using preset == "custom".
  final String? customPath;

  const WhiteNoiseSettings({
    required this.enabled,
    required this.preset,
    required this.volume,
    this.customPath,
  });

  static WhiteNoiseSettings defaultSettings() {
    return const WhiteNoiseSettings(
      enabled: false,
      preset: 'thunderstorm',
      volume: 0.45,
      customPath: null,
    );
  }

  WhiteNoiseSettings copyWith({
    bool? enabled,
    String? preset,
    double? volume,
    String? customPath,
  }) {
    return WhiteNoiseSettings(
      enabled: enabled ?? this.enabled,
      preset: preset ?? this.preset,
      volume: volume ?? this.volume,
      customPath: customPath ?? this.customPath,
    );
  }

  factory WhiteNoiseSettings.fromJson(Map<String, dynamic> json) {
    final rawVol = json['volume'];
    final vol = (rawVol is num ? rawVol.toDouble() : 0.45).clamp(0.0, 1.0);
    return WhiteNoiseSettings(
      enabled: json['enabled'] ?? false,
      // Default to thunderstorm if missing (new installs will feel consistent).
      preset: json['preset'] ?? 'thunderstorm',
      volume: vol,
      customPath: json['customPath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'preset': preset,
      'volume': volume,
      'customPath': customPath,
    };
  }
}

class BreakSettings {
  /// When enabled, the app may suggest breaks when you pause after a long focus stretch.
  final bool enabled;

  /// Random interval lower bound (minutes).
  final int minIntervalMinutes;

  /// Random interval upper bound (minutes).
  final int maxIntervalMinutes;

  /// Suggested break duration (minutes).
  final int breakMinutes;

  /// Bonus XP awarded when skipping a suggested/issued break.
  final int skipBonusXp;

  const BreakSettings({
    required this.enabled,
    required this.minIntervalMinutes,
    required this.maxIntervalMinutes,
    required this.breakMinutes,
    required this.skipBonusXp,
  });

  static BreakSettings defaultSettings() {
    return const BreakSettings(
      enabled: true,
      minIntervalMinutes: 45,
      maxIntervalMinutes: 90,
      breakMinutes: 5,
      skipBonusXp: 15,
    );
  }

  BreakSettings copyWith({
    bool? enabled,
    int? minIntervalMinutes,
    int? maxIntervalMinutes,
    int? breakMinutes,
    int? skipBonusXp,
  }) {
    return BreakSettings(
      enabled: enabled ?? this.enabled,
      minIntervalMinutes: minIntervalMinutes ?? this.minIntervalMinutes,
      maxIntervalMinutes: maxIntervalMinutes ?? this.maxIntervalMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      skipBonusXp: skipBonusXp ?? this.skipBonusXp,
    );
  }

  factory BreakSettings.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return fallback;
    }

    final minI = asInt(json['minIntervalMinutes'], 45).clamp(5, 24 * 60);
    final maxI = asInt(json['maxIntervalMinutes'], 90).clamp(minI, 24 * 60);
    final breakM = asInt(json['breakMinutes'], 5).clamp(1, 180);
    final bonus = asInt(json['skipBonusXp'], 15).clamp(0, 1 << 30);

    return BreakSettings(
      enabled: json['enabled'] ?? true,
      minIntervalMinutes: minI,
      maxIntervalMinutes: maxI,
      breakMinutes: breakM,
      skipBonusXp: bonus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'minIntervalMinutes': minIntervalMinutes,
      'maxIntervalMinutes': maxIntervalMinutes,
      'breakMinutes': breakMinutes,
      'skipBonusXp': skipBonusXp,
    };
  }
}

class FocusSettings {
  final String mode; // "pomodoro", "stopwatch"
  /// "normal" | "flip"
  final String clockStyle;
  /// When using the Flip clock style, play a short tick/click each second.
  final bool flipClockSoundEnabled;
  final PomodoroSettings pomodoro;
  final XpSettings xp;
  final NotificationSettings notifications;
  final WhiteNoiseSettings whiteNoise;
  final BreakSettings breaks;

  FocusSettings({
    required this.mode,
    required this.clockStyle,
    required this.flipClockSoundEnabled,
    required this.pomodoro,
    required this.xp,
    required this.notifications,
    required this.whiteNoise,
    required this.breaks,
  });

  FocusSettings copyWith({
    String? mode,
    String? clockStyle,
    bool? flipClockSoundEnabled,
    PomodoroSettings? pomodoro,
    XpSettings? xp,
    NotificationSettings? notifications,
    WhiteNoiseSettings? whiteNoise,
    BreakSettings? breaks,
  }) {
    return FocusSettings(
      mode: mode ?? this.mode,
      clockStyle: clockStyle ?? this.clockStyle,
      flipClockSoundEnabled: flipClockSoundEnabled ?? this.flipClockSoundEnabled,
      pomodoro: pomodoro ?? this.pomodoro,
      xp: xp ?? this.xp,
      notifications: notifications ?? this.notifications,
      whiteNoise: whiteNoise ?? this.whiteNoise,
      breaks: breaks ?? this.breaks,
    );
  }

  factory FocusSettings.fromJson(Map<String, dynamic> json) {
    return FocusSettings(
      mode: json['mode'] ?? 'pomodoro',
      clockStyle: json['clockStyle'] ?? 'normal',
      flipClockSoundEnabled: json['flipClockSoundEnabled'] ?? false,
      pomodoro: PomodoroSettings.fromJson(json['pomodoro'] ?? {}),
      xp: XpSettings.fromJson(json['xp'] ?? {}),
      notifications: NotificationSettings.fromJson(json['notifications'] ?? {}),
      whiteNoise: json['whiteNoise'] != null
          ? WhiteNoiseSettings.fromJson(json['whiteNoise'] ?? {})
          : WhiteNoiseSettings.defaultSettings(),
      breaks: json['breaks'] != null ? BreakSettings.fromJson(json['breaks'] ?? {}) : BreakSettings.defaultSettings(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'clockStyle': clockStyle,
      'flipClockSoundEnabled': flipClockSoundEnabled,
      'pomodoro': pomodoro.toJson(),
      'xp': xp.toJson(),
      'notifications': notifications.toJson(),
      'whiteNoise': whiteNoise.toJson(),
      'breaks': breaks.toJson(),
    };
  }
  
  // Default settings
  static FocusSettings defaultSettings() {
    return FocusSettings(
      mode: 'pomodoro',
      clockStyle: 'normal',
      flipClockSoundEnabled: false,
      pomodoro: PomodoroSettings(focusMinutes: 25, breakMinutes: 5),
      xp: XpSettings(baseXpPerMinute: 1),
      notifications: NotificationSettings.defaultSettings(),
      whiteNoise: WhiteNoiseSettings.defaultSettings(),
      breaks: BreakSettings.defaultSettings(),
    );
  }
}

class NotificationSettings {
  final bool enabled;
  final bool pausedMissionReminder;
  final int pausedMissionReminderMinutes;
  final bool dueDateReminder;
  final int dueDateReminderHour; // 0-23
  final bool eventReminder;
  final int eventReminderHour; // 0-23

  const NotificationSettings({
    required this.enabled,
    required this.pausedMissionReminder,
    required this.pausedMissionReminderMinutes,
    required this.dueDateReminder,
    required this.dueDateReminderHour,
    required this.eventReminder,
    required this.eventReminderHour,
  });

  static NotificationSettings defaultSettings() {
    return const NotificationSettings(
      enabled: false,
      pausedMissionReminder: true,
      pausedMissionReminderMinutes: 30,
      dueDateReminder: true,
      dueDateReminderHour: 9,
      eventReminder: false,
      eventReminderHour: 9,
    );
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? pausedMissionReminder,
    int? pausedMissionReminderMinutes,
    bool? dueDateReminder,
    int? dueDateReminderHour,
    bool? eventReminder,
    int? eventReminderHour,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      pausedMissionReminder: pausedMissionReminder ?? this.pausedMissionReminder,
      pausedMissionReminderMinutes: pausedMissionReminderMinutes ?? this.pausedMissionReminderMinutes,
      dueDateReminder: dueDateReminder ?? this.dueDateReminder,
      dueDateReminderHour: dueDateReminderHour ?? this.dueDateReminderHour,
      eventReminder: eventReminder ?? this.eventReminder,
      eventReminderHour: eventReminderHour ?? this.eventReminderHour,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] ?? false,
      pausedMissionReminder: json['pausedMissionReminder'] ?? true,
      pausedMissionReminderMinutes: json['pausedMissionReminderMinutes'] ?? 30,
      dueDateReminder: json['dueDateReminder'] ?? true,
      dueDateReminderHour: json['dueDateReminderHour'] ?? 9,
      eventReminder: json['eventReminder'] ?? false,
      eventReminderHour: json['eventReminderHour'] ?? 9,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'pausedMissionReminder': pausedMissionReminder,
      'pausedMissionReminderMinutes': pausedMissionReminderMinutes,
      'dueDateReminder': dueDateReminder,
      'dueDateReminderHour': dueDateReminderHour,
      'eventReminder': eventReminder,
      'eventReminderHour': eventReminderHour,
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

  /// Which device currently “owns” the running session.
  ///
  /// When a session is continued on another device, this value switches to the
  /// new device id. Used only for UI/UX and cross-device safety.
  final String? deviceId;

  /// Friendly label for [deviceId] (e.g. "android ab12").
  final String? deviceLabel;

  /// Last time (ms since epoch) the owning device updated this session.
  ///
  /// Best-effort, used to detect stale sessions.
  final int? lastHeartbeatAtMs;

  /// Breaks are suggested when pausing after this many total focus minutes.
  final int nextBreakAtTotalMinutes;
  final int breakOffers;
  final int breaksTaken;
  final int breaksSkipped;

  FocusOpenSession({
    required this.id,
    required this.questId,
    this.heading,
    required this.createdAt,
    required this.status,
    required this.segments,
    this.deviceId,
    this.deviceLabel,
    this.lastHeartbeatAtMs,
    this.nextBreakAtTotalMinutes = 60,
    this.breakOffers = 0,
    this.breaksTaken = 0,
    this.breaksSkipped = 0,
  });

  factory FocusOpenSession.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return fallback;
    }

    return FocusOpenSession(
      id: json['id'],
      questId: json['questId'],
      heading: json['heading'],
      createdAt: json['createdAt'],
      status: json['status'],
      segments: (json['segments'] as List).map((s) => FocusSegment.fromJson(s)).toList(),
      deviceId: json['deviceId'],
      deviceLabel: json['deviceLabel'],
      lastHeartbeatAtMs: (json['lastHeartbeatAtMs'] is int)
          ? json['lastHeartbeatAtMs']
          : (json['lastHeartbeatAtMs'] is num ? (json['lastHeartbeatAtMs'] as num).toInt() : null),
      nextBreakAtTotalMinutes: asInt(json['nextBreakAtTotalMinutes'], 60),
      breakOffers: asInt(json['breakOffers'], 0),
      breaksTaken: asInt(json['breaksTaken'], 0),
      breaksSkipped: asInt(json['breaksSkipped'], 0),
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
      'deviceId': deviceId,
      'deviceLabel': deviceLabel,
      'lastHeartbeatAtMs': lastHeartbeatAtMs,
      'nextBreakAtTotalMinutes': nextBreakAtTotalMinutes,
      'breakOffers': breakOffers,
      'breaksTaken': breaksTaken,
      'breaksSkipped': breaksSkipped,
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
