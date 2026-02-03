import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../services/sound_manager.dart';

class LevelUpModal extends StatefulWidget {
  final int newLevel;
  final int statIncrease;
  final VoidCallback onDismiss;

  const LevelUpModal({
    super.key,
    required this.newLevel,
    required this.statIncrease,
    required this.onDismiss,
  });

  @override
  State<LevelUpModal> createState() => _LevelUpModalState();
}

class _LevelUpModalState extends State<LevelUpModal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();

    // Play level-up sound
    SoundManager().playLevelUp();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                  ),
                  child: const Text(
                    'NOTIFICATION',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // "LEVELED UP!" text with glow effect
                      Text(
                        'LEVELED UP!',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              color: AppTheme.primary.withOpacity(0.8),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .shimmer(duration: 2000.ms, color: AppTheme.primary.withOpacity(0.5))
                          .then()
                          .shake(duration: 500.ms, hz: 2),

                      const SizedBox(height: 24),

                      // Level number
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'NEW LEVEL: ',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${widget.newLevel}',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 16),

                      // Stat increases
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.background.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'ALL STATS INCREASED!',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '+${widget.statIncrease}',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 400.ms)
                          .slideY(begin: 0.3, end: 0),

                      const SizedBox(height: 24),

                      // Tap to dismiss hint
                      Text(
                        'Tap anywhere to dismiss',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.6),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat())
                          .fadeIn(duration: 1500.ms)
                          .then()
                          .fadeOut(duration: 1500.ms),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate()
              .custom(
                duration: 600.ms,
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  // Solo Modal Expand animation
                  if (value < 0.5) {
                    // First half: expand horizontally
                    return Transform.scale(
                      scaleX: value * 2,
                      scaleY: 0.1,
                      child: Opacity(
                        opacity: 1.0,
                        child: child,
                      ),
                    );
                  } else {
                    // Second half: expand vertically
                    final progress = (value - 0.5) * 2;
                    return Transform.scale(
                      scaleX: 1.0,
                      scaleY: 0.1 + (0.9 * progress),
                      child: Opacity(
                        opacity: 1.0,
                        child: child,
                      ),
                    );
                  }
                },
              ),
        ),
      ),
    );
  }
}
