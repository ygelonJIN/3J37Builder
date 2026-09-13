import 'package:flutter/material.dart';
import '../data/services/builder_state.dart';
import '../data/services/dataset_loader.dart';
import '../data/models/enums.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';
import 'position_selector.dart';
import 'body_configurator.dart';

class OverallDisplay extends StatefulWidget {
  final ValueChanged<bool>? onExpandedChanged;
  
  const OverallDisplay({super.key, this.onExpandedChanged});

  @override
  State<OverallDisplay> createState() => _OverallDisplayState();
}

class _OverallDisplayState extends State<OverallDisplay> {
  bool _expanded = true; // 默认展开

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      widget.onExpandedChanged?.call(_expanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderState>();
    final loader = DatasetLoader();
    final ovr = state.overallRating;
    final pos = state.position;
    final preciseOvr = loader.getOvr(pos, state.heightInches, state.ratings);

    return GestureDetector(
      onTap: _toggleExpanded,
      child: AnimatedContainer(
        duration: AppTokens.animShort,
        curve: AppTokens.curveOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.surfaceAlt,
          border: Border.all(color: AppTokens.primary.withValues(alpha: 0.4), width: 1),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 最小化状态：总评和展开/收起按钮
            Row(
              children: [
                Text(
                  '$ovr',
                  style: AppTokens.brandMark.copyWith(fontSize: 22, letterSpacing: 0),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${preciseOvr.toStringAsFixed(1)})',
                  style: AppTokens.caption.copyWith(fontSize: 11, color: AppTokens.keyOff),
                ),
                const Spacer(),
                Text(
                  _expanded ? 'Collapse' : 'Expand',
                  style: AppTokens.caption.copyWith(
                    fontSize: 11,
                    color: AppTokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppTokens.textSecondary,
                ),
              ],
            ),
            // 展开状态：Position 和 Body
            if (_expanded) ...[
              const SizedBox(height: 12),
              // Position 选择器
              PositionSelector(selected: state.position, onSelected: state.setPosition),
              const SizedBox(height: 12),
              // Body 配置器
              BodyConfigurator(
                position: state.position,
                heightInches: state.heightInches,
                weightLb: state.weightLb,
                wingspanInches: state.wingspanInches,
                onHeightChanged: state.setHeight,
                onWeightChanged: state.setWeight,
                onWingspanChanged: state.setWingspan,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
