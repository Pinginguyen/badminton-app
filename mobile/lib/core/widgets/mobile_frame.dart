import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MobileFrame extends StatelessWidget {
  const MobileFrame({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.maxHeight = 920,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF070A0F),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, maxWidth).toDouble();
          final height = constraints.hasBoundedHeight
              ? math.min(constraints.maxHeight, maxHeight).toDouble()
              : maxHeight;

          return Center(
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.courtNavy,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonGreen.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        },
      ),
    );
  }
}
