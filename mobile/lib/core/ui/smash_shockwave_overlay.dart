import 'dart:math' as math;

import 'package:flutter/material.dart';

class SmashShockwaveOverlay extends StatefulWidget {
  const SmashShockwaveOverlay({
    super.key,
    required this.child,
    required this.triggerId,
    this.color = const Color(0xFFFFC857),
  });

  final Widget child;
  final int triggerId;
  final Color color;

  @override
  State<SmashShockwaveOverlay> createState() => _SmashShockwaveOverlayState();
}

class _SmashShockwaveOverlayState extends State<SmashShockwaveOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    if (widget.triggerId > 0) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant SmashShockwaveOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerId != oldWidget.triggerId) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _controller.value;
        final envelope = math.exp(-progress * 5);
        final shake = math.sin(progress * 44) * 13 * envelope;
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(shake, math.sin(progress * 37) * 7 * envelope),
              child: child,
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _ShockwavePainter(
                  progress: progress,
                  color: widget.color,
                  isActive: _controller.isAnimating,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShockwavePainter extends CustomPainter {
  const _ShockwavePainter({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  final double progress;
  final Color color;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive || progress >= 1) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final flashAlpha = ((1 - progress / 0.22).clamp(0, 1) * 0.24).toDouble();
    if (flashAlpha > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = color.withOpacity(flashAlpha),
      );
    }

    for (var wave = 0; wave < 3; wave++) {
      final localProgress = progress - wave * 0.13;
      if (localProgress < 0 || localProgress > 1) continue;
      final radius = maxRadius * localProgress;
      final opacity = (1 - localProgress).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withOpacity(0.72 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - localProgress) + 0.7,
      );
    }

    if (progress < 0.4) {
      final sparkPaint = Paint()
        ..color = Colors.white.withOpacity((1 - progress / 0.4) * 0.8)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var index = 0; index < 18; index++) {
        final angle = math.pi * 2 * index / 18;
        final innerRadius = 20 + progress * 36;
        final outerRadius = innerRadius + (1 - progress / 0.4) * 24;
        canvas.drawLine(
          center +
              Offset(math.cos(angle) * innerRadius, math.sin(angle) * innerRadius),
          center +
              Offset(math.cos(angle) * outerRadius, math.sin(angle) * outerRadius),
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.isActive != isActive;
}
