import 'package:flutter_riverpod/flutter_riverpod.dart';

// Level-up notification state
class LevelUpEvent {
  final int newLevel;
  final int statIncrease;
  final DateTime timestamp;

  LevelUpEvent({
    required this.newLevel,
    required this.statIncrease,
    required this.timestamp,
  });
}

class LevelUpNotifier extends StateNotifier<LevelUpEvent?> {
  LevelUpNotifier() : super(null);

  void triggerLevelUp(int newLevel, int statIncrease) {
    state = LevelUpEvent(
      newLevel: newLevel,
      statIncrease: statIncrease,
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
