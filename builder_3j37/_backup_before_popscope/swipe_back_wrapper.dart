import 'package:flutter/material.dart';

/// 左边缘滑动返回。只检测手势，不做任何视觉动画，零性能开销。
class SwipeBackWrapper extends StatelessWidget {
  final VoidCallback onSwipeBack;
  final Widget child;
  const SwipeBackWrapper({super.key, required this.onSwipeBack, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final dx = details.primaryVelocity ?? 0;
        if (dx > 300) onSwipeBack();
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
