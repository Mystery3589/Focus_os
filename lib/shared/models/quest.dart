
import 'inventory_item.dart';

class Quest {
  final String id;
  final String title;
  final String description;
  final String reward;
  final int progress;
  final String difficulty; // "S", "A", "B", "C", "D", "E"
  final String priority; // "High", "Medium", "Low"
  final String expiry;
  final int expReward;
  final int statPointsReward;
  final bool active;
  final bool completed;
  /// Optional SkillGoal id this mission belongs to.
  final String? skillId;
  final int? startDateMs;
  final int? dueDateMs;
  final int? expectedMinutes;
  final String? frequency; // daily/monthly/yearly/none
  final int? lastPenaltyDate;
  final bool isCustom;
  final QuestStatRewards? statRewards;
  final List<InventoryItem>? itemRewards;
  final int? goldReward;
  final int? createdAt;
  final int? completedAt;

  /// Optional parent mission id. When set, this quest is a sub-mission of
  /// [parentQuestId].
  final String? parentQuestId;

  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.progress,
    required this.difficulty,
    required this.priority,
    required this.expiry,
    required this.expReward,
    required this.statPointsReward,
    required this.active,
    required this.completed,
    this.skillId,
    this.startDateMs,
    this.dueDateMs,
    this.expectedMinutes,
    this.frequency,
    this.lastPenaltyDate,
    this.isCustom = false,
    this.statRewards,
    this.itemRewards,
    this.goldReward,
    this.createdAt,
    this.completedAt,
    this.parentQuestId,
  });

  factory Quest.fromJson(Map<String, dynamic> json) {
    return Quest(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      reward: json['reward'],
      progress: json['progress'],
      difficulty: json['difficulty'],
      priority: json['priority'],
      expiry: json['expiry'],
      expReward: json['expReward'],
      statPointsReward: json['statPointsReward'],
      active: json['active'],
      completed: json['completed'],
      skillId: json['skillId'],
        startDateMs: json['startDateMs'],
        dueDateMs: json['dueDateMs'],
        expectedMinutes: json['expectedMinutes'],
        frequency: json['frequency'],
        lastPenaltyDate: json['lastPenaltyDate'],
      isCustom: json['isCustom'] ?? false,
      statRewards: json['statRewards'] != null ? QuestStatRewards.fromJson(json['statRewards']) : null,
      itemRewards: json['itemRewards'] != null
          ? (json['itemRewards'] as List).map((i) => InventoryItem.fromJson(i)).toList()
          : null,
      goldReward: json['goldReward'],
      createdAt: json['createdAt'],
      completedAt: json['completedAt'],
      parentQuestId: json['parentQuestId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'reward': reward,
      'progress': progress,
      'difficulty': difficulty,
      'priority': priority,
      'expiry': expiry,
      'expReward': expReward,
      'statPointsReward': statPointsReward,
      'active': active,
      'completed': completed,
      'skillId': skillId,
      'startDateMs': startDateMs,
      'dueDateMs': dueDateMs,
      'expectedMinutes': expectedMinutes,
      'frequency': frequency,
      'lastPenaltyDate': lastPenaltyDate,
      'isCustom': isCustom,
      'statRewards': statRewards?.toJson(),
      'itemRewards': itemRewards?.map((i) => i.toJson()).toList(),
      'goldReward': goldReward,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'parentQuestId': parentQuestId,
    };
  }

  Quest copyWith({
    String? id,
    String? title,
    String? description,
    String? reward,
    int? progress,
    String? difficulty,
    String? priority,
    String? expiry,
    int? expReward,
    int? statPointsReward,
    bool? active,
    bool? completed,
    String? skillId,
    int? startDateMs,
    int? dueDateMs,
    int? expectedMinutes,
    String? frequency,
    int? lastPenaltyDate,
    bool? isCustom,
    QuestStatRewards? statRewards,
    List<InventoryItem>? itemRewards,
    int? goldReward,
    int? createdAt,
    int? completedAt,
    String? parentQuestId,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      reward: reward ?? this.reward,
      progress: progress ?? this.progress,
      difficulty: difficulty ?? this.difficulty,
      priority: priority ?? this.priority,
      expiry: expiry ?? this.expiry,
      expReward: expReward ?? this.expReward,
      statPointsReward: statPointsReward ?? this.statPointsReward,
      active: active ?? this.active,
      completed: completed ?? this.completed,
      skillId: skillId ?? this.skillId,
      startDateMs: startDateMs ?? this.startDateMs,
      dueDateMs: dueDateMs ?? this.dueDateMs,
      expectedMinutes: expectedMinutes ?? this.expectedMinutes,
      frequency: frequency ?? this.frequency,
      lastPenaltyDate: lastPenaltyDate ?? this.lastPenaltyDate,
      isCustom: isCustom ?? this.isCustom,
      statRewards: statRewards ?? this.statRewards,
      itemRewards: itemRewards ?? this.itemRewards,
      goldReward: goldReward ?? this.goldReward,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      parentQuestId: parentQuestId ?? this.parentQuestId,
    );
  }
}

class QuestStatRewards {
  final int? str;
  final int? agi;
  final int? per;
  final int? intStat;
  final int? vit;

  QuestStatRewards({this.str, this.agi, this.per, this.intStat, this.vit});

  factory QuestStatRewards.fromJson(Map<String, dynamic> json) {
    return QuestStatRewards(
      str: json['str'],
      agi: json['agi'],
      per: json['per'],
      intStat: json['int'],
      vit: json['vit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'str': str,
      'agi': agi,
      'per': per,
      'int': intStat,
      'vit': vit,
    };
  }
}
