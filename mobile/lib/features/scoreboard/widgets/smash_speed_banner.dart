import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Brief celebratory banner for an externally measured smash speed.
class SmashSpeedBanner extends StatefulWidget {
  const SmashSpeedBanner({
    super.key,
    required this.speedKmh,
    this.visibleDuration = const Duration(milliseconds: 2200),
  }) : assert(speedKmh > 0);

  final int speedKmh;
  final Duration visibleDuration;

  @override
  State<SmashSpeedBanner> createState() => _SmashSpeedBannerState();
}

class _SmashSpeedBannerState extends State<SmashSpeedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _play();
  }

  @override
  void didUpdateWidget(covariant SmashSpeedBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speedKmh != widget.speedKmh) _play();
  }

  void _play() {
    _hideTimer?.cancel();
    _controller.forward(from: 0);
    _hideTimer = Timer(widget.visibleDuration, () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = Curves.easeOutBack.transform(_controller.value);
        return Opacity(
          opacity: _controller.value.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: progress, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE55B), Color(0xFFFF8B32)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAAFF7B28),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: Color(0xFF30160B), size: 30),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.speedKmh} KM/H!',
                  style: const TextStyle(
                    color: Color(0xFF30160B),
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'SMASH',
                  style: TextStyle(
                    color: Color(0xFF51230C),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
