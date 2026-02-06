import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'shared/models/focus_session.dart';
import 'shared/providers/level_up_provider.dart';
import 'shared/providers/user_provider.dart';
import 'shared/services/quick_actions_service.dart';
import 'shared/services/white_noise_service.dart';
import 'shared/widgets/level_up_modal.dart';

void main() {
  // IMPORTANT: Keep binding initialization in the same Zone as runApp.
  // Otherwise Flutter prints a "Zone mismatch" warning and subtle bugs can occur.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Ensure we always get a stack trace in logs on device.
    var printedFullRenderFlexOverflow = false;
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      final short = details.exceptionAsString();

      // Extra prints help when logs are truncated.
      // For RenderFlex overflows, print the *full* details once so we capture
      // the "relevant error-causing widget" file:line.
      if (!printedFullRenderFlexOverflow && short.contains('RenderFlex overflowed')) {
        printedFullRenderFlexOverflow = true;
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

  ProviderSubscription<WhiteNoiseSettings>? _whiteNoiseSub;

  @override
  void initState() {
    super.initState();
    _initQuickActions();

    // Keep white-noise playback running regardless of which page is currently visible.
    // The Focus screen should only update settings; playback is owned by the app shell.
    _whiteNoiseSub = ref.listenManual<WhiteNoiseSettings>(
      userProvider.select((s) => s.focus.settings.whiteNoise),
      (previous, next) {
        WhiteNoiseService.instance.apply(next);
      },
    );

    // Apply immediately on startup so if the user enabled white noise previously,
    // it starts without requiring navigation to the Focus screen.
    final cur = ref.read(userProvider).focus.settings.whiteNoise;
    WhiteNoiseService.instance.apply(cur);
  }

  @override
  void dispose() {
    _whiteNoiseSub?.close();
    _whiteNoiseSub = null;
    super.dispose();
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
      title: 'Disciplo',
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
                aiAllocatedPoints: levelUpEvent.aiAllocatedPoints,
                userBonusPoints: levelUpEvent.userBonusPoints,
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
