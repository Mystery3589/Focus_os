class Habit {
  final String id;
  final String title;
  final int createdAtMs;
  final bool archived;
  /// List of day keys (YYYYMMDD) when this habit was completed.
  final List<int> completedDays;

  const Habit({
    required this.id,
    required this.title,
    required this.createdAtMs,
    required this.archived,
    required this.completedDays,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      createdAtMs: (json['createdAtMs'] ?? 0) as int,
      archived: (json['archived'] ?? false) as bool,
      completedDays: (json['completedDays'] as List?)?.map((e) => e as int).toList() ?? <int>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAtMs': createdAtMs,
      'archived': archived,
      'completedDays': completedDays,
    };
  }

  Habit copyWith({
    String? id,
    String? title,
    int? createdAtMs,
    bool? archived,
    List<int>? completedDays,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      archived: archived ?? this.archived,
      completedDays: completedDays ?? this.completedDays,
    );
  }
}
