import 'package:flutter/material.dart';

class BouncyPressable extends StatefulWidget {
  const BouncyPressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.enabled = true,
    this.pressedScale = 0.95,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final BorderRadius borderRadius;
  final bool enabled;
  final double pressedScale;

  @override
  State<BouncyPressable> createState() => _BouncyPressableState();
}

class _BouncyPressableState extends State<BouncyPressable> {
  bool _isPressed = false;

  @override
  void didUpdateWidget(covariant BouncyPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _isPressed) _isPressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && widget.onPressed != null;
    return AnimatedScale(
      scale: _isPressed && isEnabled ? widget.pressedScale : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        child: InkWell(
          onTap: isEnabled ? widget.onPressed : null,
          onHighlightChanged: (highlighted) {
            if (_isPressed != highlighted) {
              setState(() => _isPressed = highlighted);
            }
          },
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}
