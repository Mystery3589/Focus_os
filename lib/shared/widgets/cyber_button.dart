
import 'package:flutter/material.dart';
import '../../config/theme.dart';

enum CyberButtonVariant {
  primary,
  outline,
  ghost,
}

class CyberButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CyberButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;

  const CyberButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = CyberButtonVariant.primary,
    this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    // Base style
    final baseStyle = ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    );

    // Variant specific styles
    ButtonStyle style;
    Color iconColor;

    switch (variant) {
      case CyberButtonVariant.primary:
        style = baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.all(AppTheme.primary),
          foregroundColor: WidgetStateProperty.all(Colors.black), // Text color on primary
        );
        iconColor = Colors.black;
        break;
      case CyberButtonVariant.outline:
        style = baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          foregroundColor: WidgetStateProperty.all(AppTheme.primary),
          side: WidgetStateProperty.all(const BorderSide(color: AppTheme.primary)),
          overlayColor: WidgetStateProperty.all(AppTheme.primary.withOpacity(0.1)),
        );
        iconColor = AppTheme.primary;
        break;
      case CyberButtonVariant.ghost:
        style = baseStyle.copyWith(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          foregroundColor: WidgetStateProperty.all(AppTheme.primary), // Or textPrimary?
          overlayColor: WidgetStateProperty.all(AppTheme.primary.withOpacity(0.1)),
          elevation: WidgetStateProperty.all(0),
        );
        iconColor = AppTheme.primary; // Or textPrimary? Web app uses text-primary for ghost usually but specific context might differ
        break;
    }

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        // CyberButton can be placed inside a Row, where children often receive
        // unbounded width constraints. In that case, using Flexible/Expanded
        // would throw:
        //   "RenderFlex children have non-zero flex but incoming width constraints are unbounded."
        final hasBoundedWidth = constraints.hasBoundedWidth && constraints.maxWidth.isFinite;

        final textWidget = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          textAlign: TextAlign.center,
        );

        final label = hasBoundedWidth
            ? Flexible(child: textWidget)
            : ConstrainedBox(
                // Prevent a single long label from growing without bound when
                // our own width is unconstrained (common inside Row).
                constraints: const BoxConstraints(maxWidth: 260),
                child: textWidget,
              );

        return Row(
          mainAxisSize: hasBoundedWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
            ],
            label,
          ],
        );
      },
    );

    if (fullWidth) {
      content = SizedBox(width: double.infinity, child: Center(child: content));
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: content,
    );
  }
}
