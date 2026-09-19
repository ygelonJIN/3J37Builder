import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// 居中弹窗组件，背景模糊，点击旁边返回
class CenterDialog extends StatelessWidget {
  final Widget child;
  final VoidCallback? onClose;

  const CenterDialog({
    super.key,
    required this.child,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onClose ?? () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // 防止点击内容时关闭
              child: Container(
                constraints: BoxConstraints(
                  minWidth: 280,
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  minHeight: 50,
                ),
                decoration: BoxDecoration(
                  color: AppTokens.surface,
                  border: Border.all(color: AppTokens.primary.withValues(alpha: 0.4), width: 1),
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示居中弹窗，带背景模糊效果
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    VoidCallback? onClose,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CenterDialog(
          onClose: onClose,
          child: child,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}
