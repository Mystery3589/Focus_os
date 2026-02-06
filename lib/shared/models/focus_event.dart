class FocusEvent {
  /// Unique id for the event (UUID).
  final String id;

  /// Event type (string for forward compatibility).
  ///
  /// Examples:
  /// - focus_start / focus_resume / focus_pause
  /// - mission_abandon / mission_complete / mission_complete_manual
  /// - break_offer / break_issued / break_taken / break_skipped
  /// - bonus_xp
  final String type;

  /// Local timestamp in milliseconds since epoch.
  final int atMs;

  /// Related quest id (if any).
  final String? questId;

  /// Related focus open-session id (if any).
  final String? sessionId;

  /// Optional numeric value (e.g. bonus XP).
  final int? value;

  const FocusEvent({
    required this.id,
    required this.type,
    required this.atMs,
    this.questId,
    this.sessionId,
    this.value,
  });

  factory FocusEvent.fromJson(Map<String, dynamic> json) {
    return FocusEvent(
      id: (json['id'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      atMs: (json['atMs'] ?? 0) as int,
      questId: json['questId'] as String?,
      sessionId: json['sessionId'] as String?,
      value: json['value'] is int ? (json['value'] as int) : (json['value'] is num ? (json['value'] as num).toInt() : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'atMs': atMs,
      'questId': questId,
      'sessionId': sessionId,
      'value': value,
    };
  }
}
