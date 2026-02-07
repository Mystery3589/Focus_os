
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/cyber_button.dart';
import '../../shared/models/focus_session.dart';
import '../../shared/models/quest.dart';
import '../../shared/models/user_stats.dart';
import '../../shared/widgets/page_container.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';
import '../../shared/services/white_noise_library_service.dart';
import '../../shared/services/flip_clock_sound_service.dart';
import '../../shared/providers/device_identity_provider.dart';

class FocusScreen extends ConsumerStatefulWidget {
  final String? initialMissionId;
  final String? initialCustomHeading;
  final bool autoStartCustom;

  const FocusScreen({
    super.key,
    this.initialMissionId,
    this.initialCustomHeading,
    this.autoStartCustom = false,
  });

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _timer;
  int _now = DateTime.now().millisecondsSinceEpoch;
  String _selectedMissionId = "";
  final TextEditingController _customSessionController = TextEditingController();
  final TextEditingController _pomoFocusController = TextEditingController();
  final TextEditingController _pomoBreakController = TextEditingController();
  final TextEditingController _breakMinIntervalController = TextEditingController();
  final TextEditingController _breakMaxIntervalController = TextEditingController();
  final TextEditingController _breakMinutesController = TextEditingController();
  final TextEditingController _breakSkipBonusXpController = TextEditingController();
  ProviderSubscription<WhiteNoiseSettings>? _whiteNoiseSub;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Keep the local UI state in sync with settings changes.
    // (Playback is controlled globally by the app shell in main.dart.)
    _whiteNoiseSub = ref.listenManual<WhiteNoiseSettings>(
      userProvider.select((s) => s.focus.settings.whiteNoise),
      (previous, next) {
        // no-op: we just want rebuilds when settings change
      },
    );
    
    // Auto-select mission if provided or active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userStats = ref.read(userProvider);

      final initialHeading = widget.initialCustomHeading?.trim();
      final hasInitialHeading = initialHeading != null && initialHeading.isNotEmpty;

      // Optional: quick-start a custom session (used by app icon quick actions).
      if (widget.initialMissionId == null && hasInitialHeading) {
        if (_customSessionController.text != initialHeading) {
          _customSessionController.text = initialHeading;
        }

        if (widget.autoStartCustom) {
          final customId = 'custom-${const Uuid().v4()}';
          final ok = ref.read(userProvider.notifier).startFocus(customId, heading: initialHeading);
          if (ok) {
            _selectedMissionId = customId;
            setState(() {});
            return;
          }
        }
      }
      
      if (widget.initialMissionId != null && widget.initialMissionId!.isNotEmpty) {
        _selectedMissionId = widget.initialMissionId!;
        // Auto-start logic could go here if desired, replicating web app behavior
        _checkAutoStart(userStats);
      } else if (userStats.focus.activeSessionId != null) {
        final activeSession = userStats.focus.openSessions
            .cast<FocusOpenSession?>()
            .firstWhere((s) => s?.id == userStats.focus.activeSessionId, orElse: () => null);
        _selectedMissionId = activeSession?.questId ?? userStats.focus.activeSessionId!;
      } else if (userStats.quests.isNotEmpty) {
        // Optional: default to first quest or empty
        // _selectedMissionId = userStats.quests.first.id;
      }
      setState(() {});
    });
  }

  void _checkAutoStart(UserStats userStats) {
     // If no session exists for this mission, auto start
     // Logic can be complex, simplifying for now: user clicks start manually or we auto-trigger provider
     final existingSession = userStats.focus.openSessions.cast<FocusOpenSession?>().firstWhere(
       (s) => s?.questId == widget.initialMissionId,
       orElse: () => null,
     );
     
     if (existingSession == null) {
        ref.read(userProvider.notifier).startFocus(widget.initialMissionId!);
        setState(() {
           // We'll update selected ID when the provider updates, but we can set it here too
           _selectedMissionId = widget.initialMissionId!; 
        });
     } else {
       _selectedMissionId = existingSession.questId;
     }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _whiteNoiseSub?.close();
    _whiteNoiseSub = null;
    _customSessionController.dispose();
    _pomoFocusController.dispose();
    _pomoBreakController.dispose();
    _breakMinIntervalController.dispose();
    _breakMaxIntervalController.dispose();
    _breakMinutesController.dispose();
    _breakSkipBonusXpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now().millisecondsSinceEpoch;
        });
      }
    });
  }

  String _formatDuration(int ms) {
    if (ms < 0) ms = 0;
    final totalSeconds = (ms / 1000).floor();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;
    
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return "$hh:$mm:$ss";
  }

  ({String hh, String mm, String ss}) _durationParts(int ms) {
    if (ms < 0) ms = 0;
    final totalSeconds = (ms / 1000).floor();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return (hh: hh, mm: mm, ss: ss);
  }

  int _calculateElapsed(FocusOpenSession? session) {
    if (session == null) return 0;
    
    // If paused or abandoned, use the last segment's end time as the "current" time reference 
    // effectively freezing the timer.
    // However, the model stores segments. 
    // If status is 'paused'/'abandoned', the last segment should have an endMs.
    // If 'running', last segment endMs is null.
    
    int total = 0;
    for (var segment in session.segments) {
      final end = segment.endMs ?? _now;
      total += (end - segment.startMs);
    }
    return total > 0 ? total : 0;
  }

  Future<void> _maybeOfferBreak(
    WidgetRef ref,
    FocusOpenSession session, {
    bool force = false,
    bool issued = false,
  }) async {
    final offer = ref.read(userProvider.notifier).offerBreakForSession(
          session.id,
          force: force,
          issued: issued,
        );
    if (offer == null) return;
    if (!mounted) return;

    final breakMinutes = offer.breakMinutes;
    final bonusXp = offer.skipBonusXp;

    final take = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.background,
          title: const Text(
            'Break time?',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Text(
            bonusXp > 0
                ? 'Take a $breakMinutes minute break, or skip for +$bonusXp XP.'
                : 'Take a $breakMinutes minute break?',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(bonusXp > 0 ? 'Skip (+$bonusXp XP)' : 'Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Take break'),
            ),
          ],
        );
      },
    );

    if (take == null) return;
    final notifier = ref.read(userProvider.notifier);
    if (take) {
      notifier.recordBreakTaken(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Break started ($breakMinutes min).')),
        );
      }
    } else {
      notifier.recordBreakSkipped(session.id);
      if (mounted && bonusXp > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Break skipped: +$bonusXp XP')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);
    final identity = ref.watch(deviceIdentityProvider).valueOrNull;
    final myDeviceId = identity?.id;
    final focusState = userStats.focus;
    final missions = userStats.quests.where((q) => !q.completed).toList();
    
    // Determine active/selected session
    // Logic: Look for open session matching selectedMissionId (which could be a questId OR a sessionId for custom)
    // The web app sometimes uses questId as sessionId for quests, but here we generate UUIDs?
    // Let's check provider logic. Provider: startFocus(missionId) -> assigns id=missionId if not custom?
    // Checking `startFocus` in UserProvider:
    // It creates `id: isCustom ? "custom-..." : missionId`.
    // So `_selectedMissionId` usually equals the session ID for quests.
    
    FocusOpenSession? selectedSession;
    try {
        selectedSession = focusState.openSessions.firstWhere((s) => s.id == _selectedMissionId);
    } catch (_) {}
    
    // If selectedMissionId is actually a Quest ID, and we have a session for it, find it
    if (selectedSession == null) {
       try {
         selectedSession = focusState.openSessions.firstWhere((s) => s.questId == _selectedMissionId);
       } catch (_) {}
    }

    final sessionDeviceId = selectedSession?.deviceId;
    final isOwnedHere = (myDeviceId == null || sessionDeviceId == null) ? true : sessionDeviceId == myDeviceId;

    final isRunning = selectedSession?.status == 'running' && isOwnedHere;
    final isRunningRemote = selectedSession?.status == 'running' && !isOwnedHere;
    final isPaused = selectedSession?.status == 'paused';
    final isAbandoned = selectedSession?.status == 'abandoned';
    
    // Timer values
    final elapsedMs = _calculateElapsed(selectedSession);
    final settings = focusState.settings;
    final focusGoalMs = settings.pomodoro.focusMinutes * 60 * 1000;
    // Pomo logic: countdown. Stopwatch: count up.
    final displayMs = settings.mode == 'pomodoro' 
        ? (focusGoalMs - elapsedMs).clamp(0, double.infinity).toInt()
        : elapsedMs;

    // Keep text fields in sync (without recreating controllers every build)
    if (!isRunning && !isPaused && !isRunningRemote) {
      final focusText = settings.pomodoro.focusMinutes.toString();
      if (_pomoFocusController.text != focusText) {
        _pomoFocusController.text = focusText;
      }
      final breakText = settings.pomodoro.breakMinutes.toString();
      if (_pomoBreakController.text != breakText) {
        _pomoBreakController.text = breakText;
      }

      final b = settings.breaks;
      final minI = b.minIntervalMinutes.toString();
      if (_breakMinIntervalController.text != minI) {
        _breakMinIntervalController.text = minI;
      }
      final maxI = b.maxIntervalMinutes.toString();
      if (_breakMaxIntervalController.text != maxI) {
        _breakMaxIntervalController.text = maxI;
      }
      final breakM = b.breakMinutes.toString();
      if (_breakMinutesController.text != breakM) {
        _breakMinutesController.text = breakM;
      }
      final bonus = b.skipBonusXp.toString();
      if (_breakSkipBonusXpController.text != bonus) {
        _breakSkipBonusXpController.text = bonus;
      }
    }

    final titleText = _resolveSessionTitle(
      missions: missions,
      selectedSession: selectedSession,
      selectedMissionId: _selectedMissionId,
      customHeading: _customSessionController.text,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.timer, color: AppTheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Focus',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          const AiInboxBellAction(),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e2a3a),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: const Text(
                    'One mission at a time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageEntrance(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              CyberCard(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Mission Focus Timer",
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mode + Pomodoro inputs row
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final showInputs = !isRunning && !isPaused && settings.mode == 'pomodoro';
                        final modeRow = Row(
                          children: [
                            _buildModeButton(settings.mode == 'pomodoro', "Pomodoro", () {
                              ref.read(userProvider.notifier).updateFocusSettings(
                                    focusState.settings.copyWith(mode: 'pomodoro'),
                                  );
                            }),
                            const SizedBox(width: 10),
                            _buildModeButton(settings.mode == 'stopwatch', "Stopwatch", () {
                              ref.read(userProvider.notifier).updateFocusSettings(
                                    focusState.settings.copyWith(mode: 'stopwatch'),
                                  );
                            }),
                          ],
                        );

                        final inputs = showInputs ? _buildPomodoroInputs(ref, settings) : const SizedBox.shrink();

                        if (!wide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              modeRow,
                              if (showInputs) ...[
                                const SizedBox(height: 12),
                                inputs,
                              ],
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: modeRow),
                            const SizedBox(width: 16),
                            if (showInputs) SizedBox(width: 520, child: inputs),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Mission selector
                    _buildMissionSelector(missions, isRunning || isPaused || isRunningRemote),

                    const SizedBox(height: 18),

                    // Timer display
                    if (titleText.isNotEmpty)
                      Center(
                        child: Column(
                          children: [
                            Text(
                              titleText,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                ChoiceChip(
                                  label: const Text('Normal'),
                                  selected: settings.clockStyle == 'normal',
                                  onSelected: (_) {
                                    if (settings.clockStyle == 'normal') return;
                                    ref.read(userProvider.notifier).updateFocusSettings(
                                          focusState.settings.copyWith(clockStyle: 'normal'),
                                        );
                                  },
                                  selectedColor: AppTheme.primary,
                                  labelStyle: TextStyle(
                                    color: settings.clockStyle == 'normal' ? Colors.black : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                ChoiceChip(
                                  label: const Text('Flip'),
                                  selected: settings.clockStyle == 'flip',
                                  onSelected: (_) {
                                    if (settings.clockStyle == 'flip') return;
                                    ref.read(userProvider.notifier).updateFocusSettings(
                                          focusState.settings.copyWith(clockStyle: 'flip'),
                                        );
                                  },
                                  selectedColor: AppTheme.primary,
                                  labelStyle: TextStyle(
                                    color: settings.clockStyle == 'flip' ? Colors.black : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            if (settings.clockStyle == 'flip') ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.volume2, size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Flip tick sound',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 10),
                                  Switch.adaptive(
                                    value: settings.flipClockSoundEnabled,
                                    onChanged: (v) {
                                      ref.read(userProvider.notifier).updateFocusSettings(
                                            focusState.settings.copyWith(flipClockSoundEnabled: v),
                                          );
                                    },
                                    activeColor: AppTheme.primary,
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            Builder(
                              builder: (context) {
                                if (settings.clockStyle == 'flip') {
                                  final p = _durationParts(displayMs);
                                  return _FlipClock(
                                    hh: p.hh,
                                    mm: p.mm,
                                    ss: p.ss,
                                    soundEnabled: settings.flipClockSoundEnabled,
                                  );
                                }

                                return Text(
                                  _formatDuration(displayMs),
                                  style: const TextStyle(
                                    fontSize: 60,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                );
                              },
                            ),
                            if (settings.mode == 'pomodoro' && selectedSession != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  "Elapsed: ${_formatDuration(elapsedMs)}  •  Goal: ${settings.pomodoro.focusMinutes}m",
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    _buildControls(ref, selectedSession, isRunning, isRunningRemote, isPaused, isAbandoned),

                    const SizedBox(height: 14),
                    _buildWhiteNoiseControls(ref, settings),

                    const SizedBox(height: 14),
                    _buildBreakControls(ref, settings),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _buildRecentSessions(userStats, missions),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(bool isActive, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _basename(String path) {
    final p = path.replaceAll('\\', '/');
    final idx = p.lastIndexOf('/');
    if (idx == -1) return p;
    return p.substring(idx + 1);
  }

  Widget _buildWhiteNoiseControls(WidgetRef ref, FocusSettings settings) {
    final wn = settings.whiteNoise;
    final enabled = wn.enabled && wn.preset != 'off';
    String whiteNoiseNowPlayingLabel(WhiteNoiseSettings w) {
      final p = w.preset;
      if (p == 'rain') return 'Now playing: Rain';
      if (p == 'thunder' || p == 'thunderstorm') return 'Now playing: Thunderstorm';
      if (p == 'custom') {
        final name = (w.customPath == null || w.customPath!.trim().isEmpty) ? 'Custom (no file)' : _basename(w.customPath!);
        return 'Now playing: Custom — $name';
      }
      return 'Now playing: $p';
    }
    final thunderSelected = wn.preset == 'thunder' || wn.preset == 'thunderstorm';

    void setWhiteNoise(WhiteNoiseSettings next) {
      final updated = settings.copyWith(whiteNoise: next);
      ref.read(userProvider.notifier).updateFocusSettings(updated);
    }

    Future<void> pickCustom() async {
      try {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
          withData: false,
        );
        final path = res?.files.single.path;
        if (path == null || path.trim().isEmpty) return;
        setWhiteNoise(
          wn.copyWith(
            enabled: true,
            preset: 'custom',
            customPath: path,
          ),
        );
      } catch (_) {
        // Non-fatal; picking audio is optional.
      }
    }

    Future<void> saveCustomCopy() async {
      final path = wn.customPath;
      if (path == null || path.trim().isEmpty) return;
      try {
        final saved = await WhiteNoiseLibraryService.instance.saveCustomCopy(path);
        if (saved == null || saved.trim().isEmpty) return;
        setWhiteNoise(wn.copyWith(customPath: saved));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom white noise saved to app storage.')),
        );
      } catch (_) {
        // Non-fatal.
      }
    }


    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.cloudRain, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'White noise',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: Icon(enabled ? LucideIcons.pauseCircle : LucideIcons.playCircle, color: AppTheme.primary),
                tooltip: enabled ? 'Pause white noise' : 'Play white noise',
                onPressed: () {
                  // Make play/pause persistent so it keeps working across pages.
                  setWhiteNoise(
                    wn.copyWith(
                      enabled: !enabled,
                      preset: !enabled ? (wn.preset == 'off' ? 'rain' : wn.preset) : wn.preset,
                    ),
                  );
                },
              ),
              Switch(
                value: enabled,
                onChanged: (v) {
                  setWhiteNoise(
                    wn.copyWith(
                      enabled: v,
                      preset: v ? (wn.preset == 'off' ? 'rain' : wn.preset) : wn.preset,
                    ),
                  );
                },
                activeThumbColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Rain / Thunderstorm are generated offline. Custom lets you pick your own file.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Rain'),
                selected: wn.preset == 'rain',
                onSelected: enabled ? (_) => setWhiteNoise(wn.copyWith(preset: 'rain')) : null,
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(color: wn.preset == 'rain' ? Colors.black : AppTheme.textSecondary, fontWeight: FontWeight.w600),
                visualDensity: VisualDensity.compact,
              ),
              ChoiceChip(
                label: const Text('Thunderstorm'),
                selected: thunderSelected,
                onSelected: enabled ? (_) => setWhiteNoise(wn.copyWith(preset: 'thunderstorm')) : null,
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(color: thunderSelected ? Colors.black : AppTheme.textSecondary, fontWeight: FontWeight.w600),
                visualDensity: VisualDensity.compact,
              ),
              ChoiceChip(
                label: const Text('Custom'),
                selected: wn.preset == 'custom',
                onSelected: enabled
                    ? (_) {
                        setWhiteNoise(wn.copyWith(preset: 'custom'));
                        if (wn.customPath == null || wn.customPath!.trim().isEmpty) {
                          pickCustom();
                        }
                      }
                    : null,
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(color: wn.preset == 'custom' ? Colors.black : AppTheme.textSecondary, fontWeight: FontWeight.w600),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(LucideIcons.volume2, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                const Text('Volume', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(width: 10),
                Expanded(
                  child: Slider(
                    value: wn.volume.clamp(0.0, 1.0),
                    onChanged: (v) => setWhiteNoise(wn.copyWith(volume: v)),
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.borderColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Now playing indicator
            Row(
              children: [
                const Icon(LucideIcons.playCircle, size: 14, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    whiteNoiseNowPlayingLabel(wn),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (enabled && wn.preset == 'custom') ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    wn.customPath == null || wn.customPath!.trim().isEmpty
                        ? 'No file selected'
                        : _basename(wn.customPath!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: enabled ? pickCustom : null,
                  icon: const Icon(LucideIcons.folderOpen, size: 16),
                  label: const Text('Pick'),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: enabled ? saveCustomCopy : null,
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakControls(WidgetRef ref, FocusSettings settings) {
    final b = settings.breaks;

    void setBreaks(BreakSettings next) {
      ref.read(userProvider.notifier).updateFocusSettings(settings.copyWith(breaks: next));
    }

    int? parse(String v) => int.tryParse(v.trim());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.coffee, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Breaks',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: b.enabled,
                onChanged: (v) => setBreaks(b.copyWith(enabled: v)),
                activeThumbColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Breaks may be offered randomly when you pause (after long intervals).',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Min interval', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: _buildNumInput(
                  controller: _breakMinIntervalController,
                  onSubmitted: (v) {
                    final n = parse(v);
                    if (n == null) return;
                    setBreaks(b.copyWith(minIntervalMinutes: n));
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Max interval', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: _buildNumInput(
                  controller: _breakMaxIntervalController,
                  onSubmitted: (v) {
                    final n = parse(v);
                    if (n == null) return;
                    setBreaks(b.copyWith(maxIntervalMinutes: n));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Break minutes', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: _buildNumInput(
                  controller: _breakMinutesController,
                  onSubmitted: (v) {
                    final n = parse(v);
                    if (n == null) return;
                    setBreaks(b.copyWith(breakMinutes: n));
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Skip bonus XP', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: _buildNumInput(
                  controller: _breakSkipBonusXpController,
                  onSubmitted: (v) {
                    final n = parse(v);
                    if (n == null) return;
                    setBreaks(b.copyWith(skipBonusXp: n));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPomodoroInputs(WidgetRef ref, FocusSettings settings) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Pomodoro focus (minutes)", style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              const SizedBox(height: 6),
              _buildNumInput(
                controller: _pomoFocusController,
                onSubmitted: (val) {
                  final mins = (int.tryParse(val) ?? 25).clamp(1, 999);
                  ref.read(userProvider.notifier).updateFocusSettings(
                        settings.copyWith(pomodoro: settings.pomodoro.copyWith(focusMinutes: mins)),
                      );
                },
              ),
              const SizedBox(height: 8),
              Text(
                "Max is high (999). We clamp for safety.",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Break (minutes)", style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              const SizedBox(height: 6),
              _buildNumInput(
                controller: _pomoBreakController,
                onSubmitted: (val) {
                  final mins = (int.tryParse(val) ?? 5).clamp(1, 999);
                  ref.read(userProvider.notifier).updateFocusSettings(
                        settings.copyWith(pomodoro: settings.pomodoro.copyWith(breakMinutes: mins)),
                      );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumInput({
    required TextEditingController controller,
    required void Function(String) onSubmitted,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }

  Widget _buildMissionSelector(List<Quest> missions, bool disabled) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.stretch,
       children: [
         const Text("Select Mission", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
         const SizedBox(height: 8),
         Container(
           padding: const EdgeInsets.symmetric(horizontal: 12),
           decoration: BoxDecoration(
             color: AppTheme.background,
             border: Border.all(color: AppTheme.borderColor),
             borderRadius: BorderRadius.circular(4),
           ),
           child: DropdownButtonHideUnderline(
             child: DropdownButton<String>(
               value: missions.any((m) => m.id == _selectedMissionId) ? _selectedMissionId : (_selectedMissionId.isEmpty ? "" : null),
               dropdownColor: AppTheme.background,
               style: const TextStyle(color: AppTheme.textPrimary),
               hint: const Text("Custom Session", style: TextStyle(color: AppTheme.textSecondary)),
               items: [
                 const DropdownMenuItem(value: "", child: Text("-- Custom Session --")),
                 ...missions.map((m) => DropdownMenuItem(
                   value: m.id,
                   child: Text(m.title, overflow: TextOverflow.ellipsis),
                 )),
               ],
               onChanged: disabled ? null : (val) {
                 setState(() {
                   _selectedMissionId = val ?? "";
                 });
               },
             ),
           ),
         ),
         if (_selectedMissionId.isEmpty) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customSessionController,
              enabled: !disabled,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: "Enter custom session heading...",
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.borderColor), borderRadius: BorderRadius.circular(4)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
         ],
       ],
     );
  }

  Widget _buildControls(
    WidgetRef ref,
    FocusOpenSession? session,
    bool isRunning,
    bool isRunningRemote,
    bool isPaused,
    bool isAbandoned,
  ) {
    if (isAbandoned) {
      return CyberButton(
        text: "Rejoin Mission",
        fullWidth: true,
        icon: LucideIcons.play,
        onPressed: () {
          ref.read(userProvider.notifier).rejoinMission(_selectedMissionId);
        },
      );
    }

    if (isRunningRemote) {
      final deviceLabel = session?.deviceLabel?.trim();
      final who = (deviceLabel != null && deviceLabel.isNotEmpty) ? deviceLabel : 'another device';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CyberCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Running on $who',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You can take over this session here. Time will continue (not restart).',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CyberButton(
            text: 'Continue on this device',
            fullWidth: true,
            icon: LucideIcons.arrowRight,
            onPressed: session == null
                ? null
                : () {
                    unawaited(ref.read(userProvider.notifier).continueOpenSessionOnThisDevice(session.id));
                  },
          ),
        ],
      );
    }
    
    if (isRunning) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CyberButton(
                  text: "Pause",
                  variant: CyberButtonVariant.outline,
                  icon: LucideIcons.pause,
                  onPressed: () async {
                    if (session == null) return;
                    ref.read(userProvider.notifier).pauseFocus();
                    await _maybeOfferBreak(ref, session);
                  },
                ),
              ),
              if (!(_selectedMissionId.startsWith("custom-"))) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: CyberButton(
                    text: "Complete",
                    variant: CyberButtonVariant.primary, // Green usually
                    icon: LucideIcons.check,
                    onPressed: () {
                       final elapsed = _calculateElapsed(session);
                       // Need to pass questId. If active session is custom, questId might be null or session Id. 
                       // Check model.
                       final questId = session!.questId;
                       ref.read(userProvider.notifier).completeMission(questId, elapsed);
                       
                       // After complete, go back when possible; otherwise fall back to home.
                       if (!mounted) return;
                       if (context.canPop()) {
                         context.pop();
                       } else {
                         context.go('/');
                       }
                    },
                  ),
                ),
              ],
              if (_selectedMissionId.startsWith("custom-")) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: CyberButton(
                    text: "End",
                    variant: CyberButtonVariant.outline,
                    icon: LucideIcons.square,
                    onPressed: () {
                       final elapsed = _calculateElapsed(session);
                       ref.read(userProvider.notifier).completeMission(session!.id, elapsed);
                       setState(() {
                         _selectedMissionId = "";
                         _customSessionController.clear();
                       });
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (!(_selectedMissionId.startsWith("custom-")))
            Row(
              children: [
                Expanded(
                  child: CyberButton(
                    text: "Abandon",
                    variant: CyberButtonVariant.outline,
                    icon: LucideIcons.xCircle,
                    onPressed: () {
                      if (session != null) {
                        ref.read(userProvider.notifier).abandonMission(session.id);
                      }
                      setState(() {
                        _selectedMissionId = "";
                        _customSessionController.clear();
                      });
                    },
                  ),
                ),
              ],
            ),
        ],
      );
    }

    if (isPaused) {
       return Column(
         children: [
           Row(
             children: [
               Expanded(
                 child: CyberButton(
                   text: "Continue",
                   variant: CyberButtonVariant.primary,
                   icon: LucideIcons.play,
                   onPressed: () {
                     ref.read(userProvider.notifier).startFocus(_selectedMissionId);
                   },
                 ),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: CyberButton(
                   text: _selectedMissionId.startsWith("custom-") ? "End" : "Abandon",
                   variant: CyberButtonVariant.outline,
                   icon: _selectedMissionId.startsWith("custom-") ? LucideIcons.square : LucideIcons.xCircle,
                   onPressed: () {
                     if (session != null) {
                       if (_selectedMissionId.startsWith("custom-")) {
                         final elapsed = _calculateElapsed(session);
                         ref.read(userProvider.notifier).completeMission(session.id, elapsed);
                       } else {
                         ref.read(userProvider.notifier).abandonMission(session.id);
                       }
                     }
                     setState(() {
                       _selectedMissionId = "";
                       _customSessionController.clear();
                     });
                   },
                 ),
               ),
             ],
           ),
           const SizedBox(height: 12),
           CyberButton(
             text: "Issue break",
             fullWidth: true,
             variant: CyberButtonVariant.outline,
             icon: LucideIcons.coffee,
             onPressed: session == null
                 ? null
                 : () async {
                     await _maybeOfferBreak(ref, session, force: true, issued: true);
                   },
           ),
         ],
       );
    }
    
    // Not running, not paused -> Start
    final isQuestSelected = _selectedMissionId.isNotEmpty && !_selectedMissionId.startsWith('custom-');

    Future<bool> confirmCompleteWithoutStarting() async {
      if (!isQuestSelected) return false;

      Quest? quest;
      try {
        quest = ref.read(userProvider).quests.firstWhere((q) => q.id == _selectedMissionId);
      } catch (_) {}
      if (quest == null) return false;

      final res = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Complete mission? ',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(LucideIcons.x, color: AppTheme.textSecondary),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            content: Text(
              'This will mark "${quest!.title}" as completed without starting a focus session.\n\nRewards will still be granted and it will be tracked in your history.',
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(LucideIcons.check, size: 16),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          );
        },
      );
      return res ?? false;
    }

    void startSelectedOrCustom() {
      if (_selectedMissionId.isNotEmpty) {
        ref.read(userProvider.notifier).startFocus(_selectedMissionId);
        return;
      }
      if (_customSessionController.text.isNotEmpty) {
        final customId = "custom-${const Uuid().v4()}";
        ref.read(userProvider.notifier).startFocus(customId, heading: _customSessionController.text);
        setState(() {
          _selectedMissionId = customId;
        });
      }
    }

    if (!isQuestSelected) {
      return CyberButton(
        text: "Start Focus",
        fullWidth: true,
        icon: LucideIcons.play,
        onPressed: startSelectedOrCustom,
      );
    }

    return Row(
      children: [
        Expanded(
          child: CyberButton(
            text: "Start Focus",
            variant: CyberButtonVariant.primary,
            icon: LucideIcons.play,
            onPressed: startSelectedOrCustom,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CyberButton(
            text: "Complete",
            variant: CyberButtonVariant.outline,
            icon: LucideIcons.check,
            onPressed: () async {
              final ok = await confirmCompleteWithoutStarting();
              if (!ok) return;

              final success = ref.read(userProvider.notifier).completeQuestWithoutStarting(_selectedMissionId);
              if (!success) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Can\'t complete while this mission is running/paused.')),
                );
                return;
              }

              setState(() {
                _selectedMissionId = "";
                _customSessionController.clear();
              });
            },
          ),
        ),
      ],
    );
  }

  String _resolveSessionTitle({
    required List<Quest> missions,
    required FocusOpenSession? selectedSession,
    required String selectedMissionId,
    required String customHeading,
  }) {
    if (selectedSession?.heading != null && (selectedSession!.heading!.trim().isNotEmpty)) {
      return selectedSession.heading!.trim();
    }
    if (selectedMissionId.isEmpty) {
      return customHeading.trim().isEmpty ? "" : customHeading.trim();
    }
    try {
      return missions.firstWhere((m) => m.id == selectedMissionId).title;
    } catch (_) {
      return "Custom Session";
    }
  }

  Widget _buildRecentSessions(UserStats userStats, List<Quest> missions) {
    final history = List<FocusSessionLogEntry>.from(userStats.focus.history)
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "RECENT FOCUS SESSIONS",
          style: TextStyle(
            color: AppTheme.primary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          CyberCard(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: Text(
                "No sessions yet",
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          Column(
            children: history.take(5).map((h) {
              final title = (h.questTitle != null && h.questTitle!.trim().isNotEmpty)
                  ? h.questTitle!.trim()
                  : () {
                      try {
                        return missions.firstWhere((m) => m.id == h.questId).title;
                      } catch (_) {
                        return "Unknown mission";
                      }
                    }();

              final duration = _formatDuration(h.totalMs);
              final started = DateTime.fromMillisecondsSinceEpoch(h.startedAt);
              final ended = DateTime.fromMillisecondsSinceEpoch(h.endedAt);
              final when = "${started.day}/${started.month}/${started.year}, ${_timeOfDay(started)} – ${_timeOfDay(ended)}";

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: CyberCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              when,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(duration, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            "+${h.earnedExp} XP",
                            style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _timeOfDay(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'pm' : 'am';
    return "$h:$m $suffix";
  }
}

class _FlipClock extends StatefulWidget {
  final String hh;
  final String mm;
  final String ss;
  final bool soundEnabled;

  const _FlipClock({
    required this.hh,
    required this.mm,
    required this.ss,
    required this.soundEnabled,
  });

  @override
  State<_FlipClock> createState() => _FlipClockState();
}

class _FlipClockState extends State<_FlipClock> {
  @override
  void didUpdateWidget(covariant _FlipClock oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only tick when the displayed seconds actually change.
    if (!widget.soundEnabled) return;
    if (widget.ss == oldWidget.ss) return;

    FlipClockSoundService.instance.tick();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Keep it big, but responsive for smaller layouts.
        final maxW = c.maxWidth.isFinite ? c.maxWidth : 640.0;
        final digitW = (maxW / 12).clamp(34.0, 64.0);
        final digitH = (digitW * 1.35).clamp(48.0, 88.0);
        final gap = (digitW * 0.12).clamp(4.0, 10.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _FlipNumber(value: widget.hh, digitWidth: digitW, digitHeight: digitH, gap: gap),
            SizedBox(width: gap),
            _FlipColon(height: digitH),
            SizedBox(width: gap),
            _FlipNumber(value: widget.mm, digitWidth: digitW, digitHeight: digitH, gap: gap),
            SizedBox(width: gap),
            _FlipColon(height: digitH),
            SizedBox(width: gap),
            _FlipNumber(value: widget.ss, digitWidth: digitW, digitHeight: digitH, gap: gap),
          ],
        );
      },
    );
  }
}

class _FlipColon extends StatelessWidget {
  final double height;
  const _FlipColon({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          ':',
          style: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.95),
            fontSize: height * 0.55,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _FlipNumber extends StatelessWidget {
  final String value;
  final double digitWidth;
  final double digitHeight;
  final double gap;

  const _FlipNumber({
    required this.value,
    required this.digitWidth,
    required this.digitHeight,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    final s = value.padLeft(2, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FlipDigit(digit: s[0], width: digitWidth, height: digitHeight),
        SizedBox(width: gap),
        _FlipDigit(digit: s[1], width: digitWidth, height: digitHeight),
      ],
    );
  }
}

class _FlipDigit extends StatelessWidget {
  final String digit;
  final double width;
  final double height;

  const _FlipDigit({
    required this.digit,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          return AnimatedBuilder(
            animation: anim,
            child: child,
            builder: (context, child) {
              // Make the switch feel like a flip (rotateX with subtle perspective).
              final t = anim.value;
              final angle = (1.0 - t) * (math.pi / 2);
              final m = Matrix4.identity()..setEntry(3, 2, 0.002);
              m.rotateX(angle);
              return Transform(
                alignment: Alignment.center,
                transform: m,
                child: Opacity(
                  opacity: (0.25 + 0.75 * t).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
          );
        },
        child: _FlipDigitFace(
          key: ValueKey<String>(digit),
          digit: digit,
          width: width,
          height: height,
        ),
      ),
    );
  }
}

class _FlipDigitFace extends StatelessWidget {
  final String digit;
  final double width;
  final double height;

  const _FlipDigitFace({
    super.key,
    required this.digit,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.cardBg;
    final border = AppTheme.primary.withOpacity(0.35);
    final divider = AppTheme.borderColor.withOpacity(0.35);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Split line.
          Positioned(
            left: 8,
            right: 8,
            top: height / 2,
            child: Container(
              height: 1,
              color: divider,
            ),
          ),
          // Digit.
          Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: height * 0.75,
                height: 1.0,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
