import 'dart:ui';

import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 16,
    this.backgroundColor = const Color(0xB8151F29),
    this.highlightColor = const Color(0x66C6FF00),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color backgroundColor;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              highlightColor,
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.025),
            ],
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(color: backgroundColor),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
