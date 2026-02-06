
import 'inventory_item.dart';
import 'quest.dart';
import 'focus_session.dart';
import 'skill.dart';
import 'user_event.dart';
import 'habit.dart';
import 'focus_event.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class AiInboxMessage {
  final String id;
  final String text;
  final int createdAtMs;
  final bool read;

  const AiInboxMessage({
    required this.id,
    required this.text,
    required this.createdAtMs,
    required this.read,
  });

  factory AiInboxMessage.fromJson(Map<String, dynamic> json) {
    return AiInboxMessage(
      id: (json['id'] ?? '') as String,
      text: (json['text'] ?? '') as String,
      createdAtMs: (json['createdAtMs'] ?? 0) as int,
      read: (json['read'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAtMs': createdAtMs,
      'read': read,
    };
  }

  AiInboxMessage copyWith({
    String? id,
    String? text,
    int? createdAtMs,
    bool? read,
  }) {
    return AiInboxMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      read: read ?? this.read,
    );
  }
}

class UserStats {
  final String name;
  final int level;
  final int exp;
  final int expToNextLevel;
  final String? job;
  final String? title;
  final List<String> unlockedJobs;
  final List<String> unlockedTitles;
  final int? nextJobTitleGrantAtMs;
  final String? pendingAiMessage;
  final int? pendingAiMessageAtMs;
  final List<AiInboxMessage> aiInbox;
  final int hp;
  final int maxHp;
  final int mp;
  final int maxMp;
  final int fatigue;
  final int gold;
  final Stats stats;
  final int statPoints;
  final List<Equipment> equipment;
  final List<Quest> quests;
  final List<String> completedQuests;
  final List<InventoryItem> inventory;
  final FocusState focus;
  final Stats levelTaskWeights;
  final int? lastLevelUpAt;
  final List<SkillGoal> skills;
  final List<UserEvent> userEvents;
  final List<Habit> habits;
  final List<FocusEvent> focusEvents;

  UserStats({
    required this.name,
    required this.level,
    required this.exp,
    required this.expToNextLevel,
    this.job,
    this.title,
    required this.unlockedJobs,
    required this.unlockedTitles,
    this.nextJobTitleGrantAtMs,
    this.pendingAiMessage,
    this.pendingAiMessageAtMs,
    required this.aiInbox,
    required this.hp,
    required this.maxHp,
    required this.mp,
    required this.maxMp,
    required this.fatigue,
    required this.gold,
    required this.stats,
    required this.statPoints,
    required this.equipment,
    required this.quests,
    required this.completedQuests,
    required this.inventory,
    required this.focus,
    required this.levelTaskWeights,
    this.lastLevelUpAt,
    required this.skills,
    required this.userEvents,
    required this.habits,
    required this.focusEvents,
  });

  factory UserStats.initial() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return UserStats(
      name: "",
      level: 1,
      exp: 0,
      expToNextLevel: 100,
      job: 'Novice',
      title: 'Rookie',
      unlockedJobs: const ['Novice'],
      unlockedTitles: const ['Rookie'],
      // Legacy field (random/time-based unlocking) no longer used.
      nextJobTitleGrantAtMs: null,
      pendingAiMessage: null,
      pendingAiMessageAtMs: null,
      aiInbox: const [],
      hp: 100,
      maxHp: 100,
      mp: 10,
      maxMp: 10,
      fatigue: 0,
      gold: 0,
      stats: Stats(str: 10, agi: 10, per: 10, intStat: 10, vit: 10),
      statPoints: 0,
      equipment: [],
      quests: [],
      completedQuests: [],
      inventory: [
        InventoryItem(
          id: "item-health-potion",
          name: "Health Potion",
          type: "Consumable",
          rarity: "Common",
          description: "Restores 100 HP when consumed.",
          stats: ItemStats(hp: 100),
          quantity: 3,
        ),
        InventoryItem(
          id: "item-mana-potion",
          name: "Mana Potion",
          type: "Consumable",
          rarity: "Common",
          description: "Restores 50 MP when consumed.",
          stats: ItemStats(mp: 50),
          quantity: 2,
        ),
      ],
      focus: FocusState(
        openSessions: [],
        history: [],
        settings: FocusSettings.defaultSettings(),
      ),
      levelTaskWeights: Stats(str: 1, agi: 1, per: 1, intStat: 1, vit: 1),
      lastLevelUpAt: null,
      skills: [],
      userEvents: const [],
      habits: const [],
      focusEvents: const [],
    );
  }

  factory UserStats.fromJson(Map<String, dynamic> json) {
    final legacyJob = json['job'] as String?;
    final legacyTitle = json['title'] as String?;

    final unlockedJobs = (json['unlockedJobs'] as List?)
            ?.map((e) => e as String)
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        <String>[];
    if (legacyJob != null && legacyJob.trim().isNotEmpty && !unlockedJobs.contains(legacyJob)) {
      unlockedJobs.add(legacyJob);
    }
    if (unlockedJobs.isEmpty) {
      unlockedJobs.add('Novice');
    }

    final unlockedTitles = (json['unlockedTitles'] as List?)
            ?.map((e) => e as String)
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        <String>[];
    if (legacyTitle != null && legacyTitle.trim().isNotEmpty && !unlockedTitles.contains(legacyTitle)) {
      unlockedTitles.add(legacyTitle);
    }
    if (unlockedTitles.isEmpty) {
      unlockedTitles.add('Rookie');
    }

    final aiInbox = (json['aiInbox'] as List?)
        ?.whereType<Map>()
        .map((m) => AiInboxMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList() ??
      <AiInboxMessage>[];

    final userEvents = (json['userEvents'] as List?)
        ?.whereType<Map>()
        .map((e) => UserEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList() ??
      <UserEvent>[];

    final habits = (json['habits'] as List?)
        ?.whereType<Map>()
        .map((h) => Habit.fromJson(Map<String, dynamic>.from(h)))
        .toList() ??
      <Habit>[];

    final focusEvents = (json['focusEvents'] as List?)
        ?.whereType<Map>()
        .map((e) => FocusEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList() ??
      <FocusEvent>[];

    return UserStats(
      name: json['name'] ?? "",
      level: json['level'] ?? 1,
      exp: json['exp'] ?? 0,
      expToNextLevel: json['expToNextLevel'] ?? 100,
      job: legacyJob ?? unlockedJobs.first,
      title: legacyTitle ?? unlockedTitles.first,
      unlockedJobs: unlockedJobs,
      unlockedTitles: unlockedTitles,
      nextJobTitleGrantAtMs: json['nextJobTitleGrantAtMs'],
      pendingAiMessage: json['pendingAiMessage'],
      pendingAiMessageAtMs: json['pendingAiMessageAtMs'],
      aiInbox: aiInbox,
      hp: json['hp'] ?? 100,
      maxHp: json['maxHp'] ?? 100,
      mp: json['mp'] ?? 10,
      maxMp: json['maxMp'] ?? 10,
      fatigue: json['fatigue'] ?? 0,
      gold: json['gold'] ?? 0,
      stats: Stats.fromJson(json['stats'] ?? {}),
      statPoints: json['statPoints'] ?? 0,
      equipment: (json['equipment'] as List?)?.map((e) => Equipment.fromJson(e)).toList() ?? [],
      quests: (json['quests'] as List?)?.map((q) => Quest.fromJson(q)).toList() ?? [],
      completedQuests: (json['completedQuests'] as List?)?.map((q) => q as String).toList() ?? [],
      inventory: (json['inventory'] as List?)?.map((i) => InventoryItem.fromJson(i)).toList() ?? [],
      focus: json['focus'] != null ? FocusState.fromJson(json['focus']) : FocusState(openSessions: [], history: [], settings: FocusSettings.defaultSettings()),
      levelTaskWeights: json['levelTaskWeights'] != null ? Stats.fromJson(json['levelTaskWeights']) : Stats(str: 1, agi: 1, per: 1, intStat: 1, vit: 1),
      lastLevelUpAt: json['lastLevelUpAt'],
      skills: (json['skills'] as List?)?.map((s) => SkillGoal.fromJson(s)).toList() ?? [],
      userEvents: userEvents,
      habits: habits,
      focusEvents: focusEvents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level,
      'exp': exp,
      'expToNextLevel': expToNextLevel,
      'job': job,
      'title': title,
      'unlockedJobs': unlockedJobs,
      'unlockedTitles': unlockedTitles,
      'nextJobTitleGrantAtMs': nextJobTitleGrantAtMs,
      'pendingAiMessage': pendingAiMessage,
      'pendingAiMessageAtMs': pendingAiMessageAtMs,
      'aiInbox': aiInbox.map((m) => m.toJson()).toList(),
      'hp': hp,
      'maxHp': maxHp,
      'mp': mp,
      'maxMp': maxMp,
      'fatigue': fatigue,
      'gold': gold,
      'stats': stats.toJson(),
      'statPoints': statPoints,
      'equipment': equipment.map((e) => e.toJson()).toList(),
      'quests': quests.map((q) => q.toJson()).toList(),
      'completedQuests': completedQuests,
      'inventory': inventory.map((i) => i.toJson()).toList(),
      'focus': focus.toJson(),
      'levelTaskWeights': levelTaskWeights.toJson(),
      'lastLevelUpAt': lastLevelUpAt,
      'skills': skills.map((s) => s.toJson()).toList(),
      'userEvents': userEvents.map((e) => e.toJson()).toList(),
      'habits': habits.map((h) => h.toJson()).toList(),
      'focusEvents': focusEvents.map((e) => e.toJson()).toList(),
    };
  }

  UserStats copyWith({
    String? name,
    int? level,
    int? exp,
    int? expToNextLevel,
    String? job,
    String? title,
    List<String>? unlockedJobs,
    List<String>? unlockedTitles,
    int? nextJobTitleGrantAtMs,
    Object? pendingAiMessage = _unset,
    Object? pendingAiMessageAtMs = _unset,
    List<AiInboxMessage>? aiInbox,
    int? hp,
    int? maxHp,
    int? mp,
    int? maxMp,
    int? fatigue,
    int? gold,
    Stats? stats,
    int? statPoints,
    List<Equipment>? equipment,
    List<Quest>? quests,
    List<String>? completedQuests,
    List<InventoryItem>? inventory,
    FocusState? focus,
    Stats? levelTaskWeights,
    int? lastLevelUpAt,
    List<SkillGoal>? skills,
    List<UserEvent>? userEvents,
    List<Habit>? habits,
    List<FocusEvent>? focusEvents,
  }) {
    return UserStats(
      name: name ?? this.name,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      expToNextLevel: expToNextLevel ?? this.expToNextLevel,
      job: job ?? this.job,
      title: title ?? this.title,
      unlockedJobs: unlockedJobs ?? this.unlockedJobs,
      unlockedTitles: unlockedTitles ?? this.unlockedTitles,
      nextJobTitleGrantAtMs: nextJobTitleGrantAtMs ?? this.nextJobTitleGrantAtMs,
      pendingAiMessage: pendingAiMessage is _Unset ? this.pendingAiMessage : pendingAiMessage as String?,
      pendingAiMessageAtMs: pendingAiMessageAtMs is _Unset ? this.pendingAiMessageAtMs : pendingAiMessageAtMs as int?,
      aiInbox: aiInbox ?? this.aiInbox,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      mp: mp ?? this.mp,
      maxMp: maxMp ?? this.maxMp,
      fatigue: fatigue ?? this.fatigue,
      gold: gold ?? this.gold,
      stats: stats ?? this.stats,
      statPoints: statPoints ?? this.statPoints,
      equipment: equipment ?? this.equipment,
      quests: quests ?? this.quests,
      completedQuests: completedQuests ?? this.completedQuests,
      inventory: inventory ?? this.inventory,
      focus: focus ?? this.focus,
      levelTaskWeights: levelTaskWeights ?? this.levelTaskWeights,
      lastLevelUpAt: lastLevelUpAt ?? this.lastLevelUpAt,
      skills: skills ?? this.skills,
      userEvents: userEvents ?? this.userEvents,
      habits: habits ?? this.habits,
      focusEvents: focusEvents ?? this.focusEvents,
    );
  }
}

class Stats {
  final int str;
  final int agi;
  final int per;
  final int intStat;
  final int vit;

  Stats({
    required this.str,
    required this.agi,
    required this.per,
    required this.intStat,
    required this.vit,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      str: json['str'] ?? 0,
      agi: json['agi'] ?? 0,
      per: json['per'] ?? 0,
      intStat: json['int'] ?? 0,
      vit: json['vit'] ?? 0,
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

  Stats copyWith({
    int? str,
    int? agi,
    int? per,
    int? intStat,
    int? vit,
  }) {
    return Stats(
      str: str ?? this.str,
      agi: agi ?? this.agi,
      per: per ?? this.per,
      intStat: intStat ?? this.intStat,
      vit: vit ?? this.vit,
    );
  }
}

class Equipment {
  final String id;
  final String name;
  final String rarity; // "Common", "Uncommon", "Rare", "Epic", "Legendary"
  final List<String> stats;
  final String setBonus;
  final String slot;
  final bool equipped;

  Equipment({
    required this.id,
    required this.name,
    required this.rarity,
    required this.stats,
    required this.setBonus,
    required this.slot,
    required this.equipped,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      name: json['name'],
      rarity: json['rarity'],
      stats: List<String>.from(json['stats']),
      setBonus: json['setBonus'],
      slot: json['slot'],
      equipped: json['equipped'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rarity': rarity,
      'stats': stats,
      'setBonus': setBonus,
      'slot': slot,
      'equipped': equipped,
    };
  }
}
