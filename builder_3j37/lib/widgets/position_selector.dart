import 'package:flutter/material.dart';
import '../data/models/enums.dart';
import '../theme/app_tokens.dart';

class PositionSelector extends StatelessWidget {
  final Position selected;
  final ValueChanged<Position> onSelected;

  const PositionSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: Position.values.map((pos) {
        final isActive = pos == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => onSelected(pos),
              child: AnimatedContainer(
                duration: AppTokens.animShort,
                curve: AppTokens.curveOut,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive ? AppTokens.primary : AppTokens.surface,
                  border: Border.all(
                    color: isActive ? AppTokens.primary : AppTokens.chipBorder,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  boxShadow: isActive
                      ? [BoxShadow(color: AppTokens.buttonShadow, blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  pos.label,
                  style: AppTokens.buttonLabel.copyWith(
                    color: isActive ? AppTokens.onPrimary : AppTokens.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
