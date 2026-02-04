import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A subtle, consistent entrance animation for full pages.
///
/// Wrap any non-home screen body with this to get a small fade + slide up.
///
/// Design goals:
/// - Minimal (fast + subtle) to avoid feeling "jumpy"
/// - Plays once when the route is pushed (state is preserved across rebuilds)
/// - Centralized so we can tune the whole app in one place
class PageEntrance extends StatelessWidget {
  final Widget child;

  /// Delay before starting the animation.
  final Duration delay;

  /// Duration for the fade/slide effects.
  final Duration duration;

  /// The initial offset for the slide effect.
  final Offset beginOffset;

  /// Curve used for both effects.
  final Curve curve;

  /// Allows turning the animation off (useful for tests or reduced motion).
  final bool enabled;

  const PageEntrance({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 260),
    this.beginOffset = const Offset(0, 0.04),
    this.curve = Curves.easeOutCubic,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: curve)
        .slide(begin: beginOffset, end: Offset.zero, duration: duration, curve: curve);
  }
}
