import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flutter/shared/models/user_stats.dart';

void main() {
  test('UserStats JSON roundtrip (backup payload) does not throw', () {
    final original = UserStats.initial().copyWith(
      name: 'Tester',
      level: 3,
      gold: 123,
    );

    final json = original.toJson();
    final restored = UserStats.fromJson(json);

    expect(restored.name, 'Tester');
    expect(restored.level, 3);
    expect(restored.gold, 123);
    expect(restored.quests, isA<List>());
    expect(restored.focus.openSessions, isA<List>());
  });
}
