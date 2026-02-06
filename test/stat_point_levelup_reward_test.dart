import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focus_flutter/shared/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('awards +1 allocatable stat point at level 5', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    // Level 1 -> 5 is 4 level-ups. Only the 5th level should award a point.
    for (int i = 0; i < 4; i++) {
      final statsBefore = container.read(userProvider);
      notifier.addExp(statsBefore.expToNextLevel);
    }

    final stats = container.read(userProvider);
    expect(stats.level, 5);
    expect(stats.statPoints, 1);
  });

  test('awards +1 allocatable stat point at levels 5 and 10', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    // Level 1 -> 10 is 9 level-ups; points should be awarded at 5 and 10.
    for (int i = 0; i < 9; i++) {
      final statsBefore = container.read(userProvider);
      notifier.addExp(statsBefore.expToNextLevel);
    }

    final stats = container.read(userProvider);
    expect(stats.level, 10);
    expect(stats.statPoints, 2);
  });
}
