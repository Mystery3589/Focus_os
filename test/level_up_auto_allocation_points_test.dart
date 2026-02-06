import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focus_flutter/shared/providers/user_provider.dart';

int _sumStats(dynamic stats) {
  // Stats is a concrete type, but keeping this helper local avoids importing the model.
  return (stats.str as int) + (stats.agi as int) + (stats.per as int) + (stats.intStat as int) + (stats.vit as int);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('level-up increases expToNextLevel and AI allocates 2 points on even levels', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    final before = container.read(userProvider);
    notifier.addExp(before.expToNextLevel); // exactly one level-up
    final after = container.read(userProvider);

    expect(after.level, before.level + 1);
    expect(after.exp, 0);
    expect(after.expToNextLevel, greaterThan(before.expToNextLevel));

    final delta = _sumStats(after.stats) - _sumStats(before.stats);
    expect(delta, 2);
  });

  test('AI allocates 3 points on odd levels', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(userProvider.notifier);

    // Level 1 -> 2
    final before1 = container.read(userProvider);
    notifier.addExp(before1.expToNextLevel);

    // Level 2 -> 3 (odd level)
    final before2 = container.read(userProvider);
    notifier.addExp(before2.expToNextLevel);

    final after = container.read(userProvider);
    expect(after.level, 3);

    final delta = _sumStats(after.stats) - _sumStats(before2.stats);
    expect(delta, 3);
  });
}
