
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    _startTimer();
    
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
    _customSessionController.dispose();
    _pomoFocusController.dispose();
    _pomoBreakController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);
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

    final isRunning = selectedSession?.status == 'running';
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
    if (!isRunning && !isPaused) {
      final focusText = settings.pomodoro.focusMinutes.toString();
      if (_pomoFocusController.text != focusText) {
        _pomoFocusController.text = focusText;
      }
      final breakText = settings.pomodoro.breakMinutes.toString();
      if (_pomoBreakController.text != breakText) {
        _pomoBreakController.text = breakText;
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
                    _buildMissionSelector(missions, isRunning || isPaused),

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
                            const SizedBox(height: 10),
                            Builder(
                              builder: (context) {
                                if (settings.clockStyle == 'flip') {
                                  final p = _durationParts(displayMs);
                                  return _FlipClock(
                                    hh: p.hh,
                                    mm: p.mm,
                                    ss: p.ss,
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

                    _buildControls(ref, selectedSession, isRunning, isPaused, isAbandoned),
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

  Widget _buildControls(WidgetRef ref, FocusOpenSession? session, bool isRunning, bool isPaused, bool isAbandoned) {
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
                  onPressed: () {
                     ref.read(userProvider.notifier).pauseFocus();
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
                       
                       // After complete, maybe go back or show dialog?
                       // For now, reset selection or go back
                       if (mounted) context.pop(); 
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
       return Row(
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
       );
    }
    
    // Not running, not paused -> Start
    return CyberButton(
      text: "Start Focus",
      fullWidth: true,
      icon: LucideIcons.play,
      onPressed: () {
         if (_selectedMissionId.isNotEmpty) {
           ref.read(userProvider.notifier).startFocus(_selectedMissionId);
         } else if (_customSessionController.text.isNotEmpty) {
           // Start custom session
           // We need to generate an ID or let provider handle it?
           // Provider `startFocus` checks if id exists in missions. if not, treats as custom? 
           // Looking at `user_provider.dart` would confirm.
           // Assuming `startFocus` takes (id, heading).
           // If I pass a new UUID, provider might look for quest. 
           // Let's assume provider handles "if not quest, create custom".
           final customId = "custom-${const Uuid().v4()}";
           ref.read(userProvider.notifier).startFocus(customId, heading: _customSessionController.text);
           setState(() {
             _selectedMissionId = customId;
           });
         }
      },
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

class _FlipClock extends StatelessWidget {
  final String hh;
  final String mm;
  final String ss;

  const _FlipClock({
    required this.hh,
    required this.mm,
    required this.ss,
  });

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
            _FlipNumber(value: hh, digitWidth: digitW, digitHeight: digitH, gap: gap),
            SizedBox(width: gap),
            _FlipColon(height: digitH),
            SizedBox(width: gap),
            _FlipNumber(value: mm, digitWidth: digitW, digitHeight: digitH, gap: gap),
            SizedBox(width: gap),
            _FlipColon(height: digitH),
            SizedBox(width: gap),
            _FlipNumber(value: ss, digitWidth: digitW, digitHeight: digitH, gap: gap),
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
