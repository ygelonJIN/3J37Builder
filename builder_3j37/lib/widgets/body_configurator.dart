import 'package:flutter/material.dart';
import '../data/models/enums.dart';
import '../data/services/dataset_loader.dart';
import '../theme/app_tokens.dart';
import 'plus_minus_control.dart';

class BodyConfigurator extends StatelessWidget {
  final Position position;
  final int heightInches;
  final int weightLb;
  final int wingspanInches;
  final ValueChanged<int> onHeightChanged;
  final ValueChanged<int> onWeightChanged;
  final ValueChanged<int> onWingspanChanged;

  const BodyConfigurator({
    super.key,
    required this.position,
    required this.heightInches,
    required this.weightLb,
    required this.wingspanInches,
    required this.onHeightChanged,
    required this.onWeightChanged,
    required this.onWingspanChanged,
  });

  String _fmtHeight(int inches) {
    final feet = inches ~/ 12;
    final inc = inches % 12;
    return "$feet'$inc\"";
  }

  @override
  Widget build(BuildContext context) {
    final loader = DatasetLoader();
    final legalBody = loader.getLegalBody(position);
    final bodyRange = loader.getBodyRange(position, heightInches);
    if (legalBody == null) return const SizedBox.shrink();

    final minH = legalBody.minHeight;
    final maxH = legalBody.maxHeight;
    final minW = bodyRange?.minWeight ?? 150;
    final maxW = bodyRange?.maxWeight ?? 300;
    final minWs = bodyRange?.minWingspan ?? heightInches;
    final maxWs = bodyRange?.maxWingspan ?? heightInches + 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Height
        _BodyControl(
          label: 'Height',
          value: heightInches,
          min: minH,
          max: maxH,
          displayValue: _fmtHeight(heightInches),
          onChanged: onHeightChanged,
        ),
        const SizedBox(height: 2),
        // Weight
        _BodyControl(
          label: 'Weight',
          value: weightLb,
          min: minW,
          max: maxW,
          displayValue: '$weightLb lbs',
          onChanged: onWeightChanged,
        ),
        const SizedBox(height: 2),
        // Wingspan
        _BodyControl(
          label: 'Wingspan',
          value: wingspanInches,
          min: minWs,
          max: maxWs,
          displayValue: _fmtHeight(wingspanInches),
          onChanged: onWingspanChanged,
        ),
      ],
    );
  }
}

class _BodyControl extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final String displayValue;
  final ValueChanged<int> onChanged;

  const _BodyControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // 标签 + 数值（紧挨着，不同颜色）
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: AppTokens.caption.copyWith(
                    color: AppTokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextSpan(
                  text: displayValue,
                  style: AppTokens.caption.copyWith(
                    color: AppTokens.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // 中间空间
          const Spacer(),
          // 加减按钮（靠最右侧）
          PlusMinusControl(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
