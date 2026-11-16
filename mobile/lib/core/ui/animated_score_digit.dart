import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedScoreDigit extends StatefulWidget {
  const AnimatedScoreDigit({
    super.key,
    required this.value,
    this.color = Colors.white,
    this.fontSize = 36,
    this.width = 38,
  });

  final int value;
  final Color color;
  final double fontSize;
  final double width;

  @override
  State<AnimatedScoreDigit> createState() => _AnimatedScoreDigitState();
}

class _AnimatedScoreDigitState extends State<AnimatedScoreDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant AnimatedScoreDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value > oldWidget.value) _glowController.forward(from: 0);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final glow = 1 - _glowController.value;
          return Container(
            decoration: BoxDecoration(
              boxShadow: glow < 0.02
                  ? null
                  : [
                      BoxShadow(
                        color: widget.color.withOpacity(0.65 * glow),
                        blurRadius: 18 * glow,
                        spreadRadius: 2 * glow,
                      ),
                    ],
            ),
            child: child,
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return ClipRect(
              child: FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.8),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              ),
            );
          },
          child: Text(
            '${widget.value}',
            key: ValueKey(widget.value),
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(
              color: widget.color,
              fontSize: widget.fontSize,
              height: 1,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
