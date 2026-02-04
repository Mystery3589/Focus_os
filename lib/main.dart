import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'shared/providers/level_up_provider.dart';
import 'shared/services/quick_actions_service.dart';
import 'shared/widgets/level_up_modal.dart';

void main() {
  // IMPORTANT: Keep binding initialization in the same Zone as runApp.
  // Otherwise Flutter prints a "Zone mismatch" warning and subtle bugs can occur.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Ensure we always get a stack trace in logs on device.
    var _printedFullRenderFlexOverflow = false;
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      final short = details.exceptionAsString();

      // Extra prints help when logs are truncated.
      // For RenderFlex overflows, print the *full* details once so we capture
      // the "relevant error-causing widget" file:line.
      if (!_printedFullRenderFlexOverflow && short.contains('RenderFlex overflowed')) {
        _printedFullRenderFlexOverflow = true;
        // ignore: avoid_print
        print(details.toString());
      } else {
        // ignore: avoid_print
        print('FlutterError: $short');
      }
      if (details.stack != null) {
        // ignore: avoid_print
        print(details.stack);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      // ignore: avoid_print
      print('Uncaught platform error: $error');
      // ignore: avoid_print
      print(stack);
      // Returning true prevents the error from being considered unhandled.
      return true;
    };

    runApp(const ProviderScope(child: MyApp()));
  }, (Object error, StackTrace stack) {
    // ignore: avoid_print
    print('Uncaught zoned error: $error');
    // ignore: avoid_print
    print(stack);
  });
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  static const _qaResumeFocus = 'resume_focus';
  static const _qaStartQuickFocus = 'start_quick_focus';
  static const _qaOpenMissions = 'open_missions';

  @override
  void initState() {
    super.initState();
    _initQuickActions();
  }

  Future<void> _initQuickActions() async {
    await QuickActionsService.instance.init(onAction: (type) {
      switch (type) {
        case _qaResumeFocus:
          router.go('/focus');
          break;
        case _qaStartQuickFocus:
          router.go(
            Uri(
              path: '/focus',
              queryParameters: {
                'heading': 'Quick Focus',
                'autostart': '1',
              },
            ).toString(),
          );
          break;
        case _qaOpenMissions:
          router.go('/quests');
          break;
      }
    });

    await QuickActionsService.instance.setItems(const [
      ShortcutItem(
        type: _qaResumeFocus,
        localizedTitle: 'Resume Focus',
      ),
      ShortcutItem(
        type: _qaStartQuickFocus,
        localizedTitle: 'Start Quick Focus',
      ),
      ShortcutItem(
        type: _qaOpenMissions,
        localizedTitle: 'Open Missions',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final levelUpEvent = ref.watch(levelUpProvider);

    return MaterialApp.router(
      title: 'Solo Level Up',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox(),
            // Level-up modal overlay
            if (levelUpEvent != null)
              LevelUpModal(
                newLevel: levelUpEvent.newLevel,
                statIncrease: levelUpEvent.statIncrease,
                onDismiss: () {
                  ref.read(levelUpProvider.notifier).clearLevelUp();
                },
              ),
          ],
        );
      },
    );
  }
}
