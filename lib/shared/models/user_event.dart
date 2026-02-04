class UserEvent {
  final String id;
  final String title;
  final String? notes;
  /// Local timestamp in milliseconds since epoch.
  ///
  /// If [allDay] is true, this should generally be the local day start.
  final int startAtMs;
  final bool allDay;
  /// If true, an event reminder may be scheduled (when global settings allow it).
  final bool remind;
  /// Minutes before [startAtMs] for reminder. Defaults to 0.
  final int remindMinutesBefore;

  const UserEvent({
    required this.id,
    required this.title,
    this.notes,
    required this.startAtMs,
    required this.allDay,
    required this.remind,
    required this.remindMinutesBefore,
  });

  factory UserEvent.fromJson(Map<String, dynamic> json) {
    return UserEvent(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      notes: json['notes'] as String?,
      startAtMs: (json['startAtMs'] ?? 0) as int,
      allDay: (json['allDay'] ?? true) as bool,
      remind: (json['remind'] ?? false) as bool,
      remindMinutesBefore: (json['remindMinutesBefore'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'startAtMs': startAtMs,
      'allDay': allDay,
      'remind': remind,
      'remindMinutesBefore': remindMinutesBefore,
    };
  }

  UserEvent copyWith({
    String? id,
    String? title,
    String? notes,
    int? startAtMs,
    bool? allDay,
    bool? remind,
    int? remindMinutesBefore,
  }) {
    return UserEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startAtMs: startAtMs ?? this.startAtMs,
      allDay: allDay ?? this.allDay,
      remind: remind ?? this.remind,
      remindMinutesBefore: remindMinutesBefore ?? this.remindMinutesBefore,
    );
  }
}
