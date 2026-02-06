import 'dart:async';

import 'package:flutter/material.dart';

/// Full-width bottom "toast" (styled like a desktop notification bar).
///
/// Uses an [OverlayEntry] for consistent styling across platforms.
/// Falls back to SnackBar when no overlay is available.
class AppToast {
  static OverlayEntry? _entry;
  static VoidCallback? _dismissActive;

  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 6),
  }) {
    // Dismiss any existing toast first.
    hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      // Fallback: still show something (use SnackBar plumbing).
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.hideCurrentSnackBar();
      final bg = const Color(0xFFD9F0FF);
      final fg = Colors.black;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          elevation: 0,
          backgroundColor: bg,
          duration: duration,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          content: Text(message, style: TextStyle(color: fg)),
          action: (actionLabel != null && onAction != null)
              ? SnackBarAction(label: actionLabel, textColor: fg, onPressed: onAction)
              : null,
        ),
      );
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return _AppToastOverlay(
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration,
          onDismissed: () {
            if (_entry == entry) {
              _entry = null;
              _dismissActive = null;
            }
            entry.remove();
          },
          onRegisterDismiss: (d) {
            _dismissActive = d;
          },
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);
  }

  static void hide() {
    // Prefer animating out if possible.
    final d = _dismissActive;
    if (d != null) {
      d();
      return;
    }
    final e = _entry;
    if (e != null) {
      _entry = null;
      _dismissActive = null;
      e.remove();
    }
  }
}

class _AppToastOverlay extends StatefulWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismissed;
  final void Function(VoidCallback dismiss) onRegisterDismiss;

  const _AppToastOverlay({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onDismissed,
    required this.onRegisterDismiss,
  });

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay> {
  bool _visible = false;
  bool _dismissed = false;
  late final Duration _anim = const Duration(milliseconds: 180);
  late final Timer _timer;

  @override
  void initState() {
    super.initState();

    widget.onRegisterDismiss(_dismiss);

    // Slide/fade in on next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
    });

    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;

    if (mounted) {
      setState(() => _visible = false);
    }
    Future.delayed(_anim + const Duration(milliseconds: 30), () {
      widget.onDismissed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFD9F0FF);
    final fg = Colors.black;
    final border = const Color(0xFF9DD7FF);

    final hasAction = widget.actionLabel != null && widget.onAction != null;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, 0.15),
            duration: _anim,
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: _anim,
              curve: Curves.easeOut,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(top: BorderSide(color: border, width: 1)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (hasAction) ...[
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          final cb = widget.onAction;
                          if (cb != null) cb();
                          _dismiss();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        child: Text(widget.actionLabel!),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
