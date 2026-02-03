
import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class CyberProgress extends StatelessWidget {
  final double value; // 0.0 to 1.0 (or 0 to 100 if specified?) Assuming 0-100 based on usage
  final double height;
  final Color backgroundColor;
  final Color progressColor;

  const CyberProgress({
    super.key,
    required this.value,
    this.height = 8.0,
    this.backgroundColor = const Color(0xFF1e2a3a),
    this.progressColor = const Color(0xFF4cc9ff),
  });

  @override
  Widget build(BuildContext context) {
    return LinearPercentIndicator(
      padding: EdgeInsets.zero,
      lineHeight: height,
      percent: (value / 100).clamp(0.0, 1.0),
      backgroundColor: backgroundColor,
      barRadius: const Radius.circular(999), // rounded-full
      progressColor: progressColor,
      animation: true,
      animationDuration: 500,
    );
  }
}
