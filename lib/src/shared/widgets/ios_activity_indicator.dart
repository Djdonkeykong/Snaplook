import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// A custom iOS-style activity indicator that matches the native UIActivityIndicatorView
/// with customizable stroke width for a thicker appearance.
///
/// This widget recreates the classic iOS spinner with 8 rotating ticks,
/// matching Apple's Human Interface Guidelines design.
class IOSActivityIndicator extends StatefulWidget {
  const IOSActivityIndicator({
    super.key,
    this.radius = 10.0,
    this.strokeWidth = 2.5,
    this.color = const Color(0xFFFFFFFF),
  });

  /// The radius of the indicator (distance from center to tick).
  /// Default is 10.0 to match CupertinoActivityIndicator.
  final double radius;

  /// The width of each tick stroke.
  /// Default is 2.5 for a thicker iOS-native appearance.
  final double strokeWidth;

  /// The color of the indicator ticks.
  final Color color;

  @override
  State<IOSActivityIndicator> createState() => _IOSActivityIndicatorState();
}

class _IOSActivityIndicatorState extends State<IOSActivityIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.radius * 2,
      height: widget.radius * 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _IOSActivityIndicatorPainter(
              position: _controller.value,
              radius: widget.radius,
              strokeWidth: widget.strokeWidth,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _IOSActivityIndicatorPainter extends CustomPainter {
  _IOSActivityIndicatorPainter({
    required this.position,
    required this.radius,
    required this.strokeWidth,
    required this.color,
  });

  final double position;
  final double radius;
  final double strokeWidth;
  final Color color;

  // iOS native spinner has 8 ticks with varying alpha values
  static const List<int> _alphaValues = [147, 122, 97, 72, 47, 47, 47, 47];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw 8 ticks around the circle
    for (int i = 0; i < 8; i++) {
      // Calculate alpha based on current rotation position
      final int alphaIndex = (i + (position * 8).floor()) % 8;
      final int alpha = _alphaValues[alphaIndex];

      paint.color = color.withAlpha(alpha);

      // Calculate tick angle (45 degrees apart)
      final angle = (i * math.pi / 4) - (math.pi / 2);

      // Calculate tick start and end points
      // Ticks are positioned from 0.4 to 0.9 of the radius
      final tickStart = Offset(
        center.dx + math.cos(angle) * radius * 0.4,
        center.dy + math.sin(angle) * radius * 0.4,
      );
      final tickEnd = Offset(
        center.dx + math.cos(angle) * radius * 0.9,
        center.dy + math.sin(angle) * radius * 0.9,
      );

      canvas.drawLine(tickStart, tickEnd, paint);
    }
  }

  @override
  bool shouldRepaint(_IOSActivityIndicatorPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}
