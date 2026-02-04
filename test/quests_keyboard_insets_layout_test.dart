import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focus_flutter/features/quests/quests_screen.dart';

void main() {
  testWidgets('Quests screen does not overflow when keyboard insets are present', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.viewInsets = FakeViewPadding(bottom: 300);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuestsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
