import 'package:flutter_riverpod/flutter_riverpod.dart';

// Level-up notification state
class LevelUpEvent {
  final int newLevel;
  final int aiAllocatedPoints;
  final int userBonusPoints;
  final DateTime timestamp;

  LevelUpEvent({
    required this.newLevel,
    required this.aiAllocatedPoints,
    required this.userBonusPoints,
    required this.timestamp,
  });
}

class LevelUpNotifier extends StateNotifier<LevelUpEvent?> {
  LevelUpNotifier() : super(null);

  void triggerLevelUp(
    int newLevel, {
    required int aiAllocatedPoints,
    required int userBonusPoints,
  }) {
    state = LevelUpEvent(
      newLevel: newLevel,
      aiAllocatedPoints: aiAllocatedPoints,
      userBonusPoints: userBonusPoints,
      timestamp: DateTime.now(),
    );
  }

  void clearLevelUp() {
    state = null;
  }
}

final levelUpProvider = StateNotifierProvider<LevelUpNotifier, LevelUpEvent?>((ref) {
  return LevelUpNotifier();
});
