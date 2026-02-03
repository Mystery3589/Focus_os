class SkillMission {
  final String id;
  final String title;
  final bool completed;

  SkillMission({
    required this.id,
    required this.title,
    required this.completed,
  });

  factory SkillMission.fromJson(Map<String, dynamic> json) {
    return SkillMission(
      id: json['id'],
      title: json['title'],
      completed: json['completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
    };
  }

  SkillMission copyWith({
    String? id,
    String? title,
    bool? completed,
  }) {
    return SkillMission(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}

class SkillGoal {
  final String id;
  final String title;
  final String? description;
  final List<SkillMission> missions;
  final int level;
  final int exp;

  SkillGoal({
    required this.id,
    required this.title,
    this.description,
    required this.missions,
    required this.level,
    required this.exp,
  });

  /// XP required to reach the next skill level.
  ///
  /// Simple, predictable progression (linear):
  /// $$XP_{next}(L) = 100 + 50\cdot(L-1)$$
  int get expToNextLevel => SkillGoal.expToNextLevelFor(level);

  static int expToNextLevelFor(int level) {
    final safeLevel = level <= 0 ? 1 : level;
    return 100 + (safeLevel - 1) * 50;
  }

  factory SkillGoal.fromJson(Map<String, dynamic> json) {
    return SkillGoal(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      missions: (json['missions'] as List? ?? [])
          .map((m) => SkillMission.fromJson(m))
          .toList(),
      level: json['level'] ?? 1,
      exp: json['exp'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'missions': missions.map((m) => m.toJson()).toList(),
      'level': level,
      'exp': exp,
    };
  }

  SkillGoal copyWith({
    String? id,
    String? title,
    String? description,
    List<SkillMission>? missions,
    int? level,
    int? exp,
  }) {
    return SkillGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      missions: missions ?? this.missions,
      level: level ?? this.level,
      exp: exp ?? this.exp,
    );
  }
}
