import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class MyBSplitButton extends StatelessWidget {
  final VoidCallback onSaveAndOpen;
  final VoidCallback onOpen;

  const MyBSplitButton({
    super.key,
    required this.onSaveAndOpen,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(color: AppTokens.textSecondary, width: 1),
      ),
      elevation: 2,
      shadowColor: AppTokens.buttonShadow,
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onSaveAndOpen,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTokens.radius),
                bottomLeft: Radius.circular(AppTokens.radius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppTokens.primary,
                ),
              ),
            ),
            Container(
              width: 1,
              color: AppTokens.textSecondary.withValues(alpha: 0.4),
            ),
            InkWell(
              onTap: onOpen,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(AppTokens.radius),
                bottomRight: Radius.circular(AppTokens.radius),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                child: Text(
                  'MyB',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.textPrimary,
                    fontFamily: AppTokens.fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
