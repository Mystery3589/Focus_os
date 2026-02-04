import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focus_flutter/features/combat/combat_screen.dart';

void main() {
  testWidgets('Combat screen does not overflow on phone-sized layout', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Simulate a narrow phone screen.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CombatScreen(),
        ),
      ),
    );

    // Let initial frames (and async best-effort loads) progress.
    await tester.pump(const Duration(milliseconds: 300));

    // A RenderFlex overflow is reported as a FlutterError in widget tests.
    expect(tester.takeException(), isNull);
  });
}
