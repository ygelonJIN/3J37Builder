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
  bool _expanded = true;

  void _toggleExpanded() {
    FocusScope.of(context).unfocus();
    setState(() {
      _expanded = !_expanded;
      widget.onExpandedChanged?.call(_expanded);
    });
  }

  String _fmtHeight(int inches) {
    final feet = inches ~/ 12;
    final inc = inches % 12;
    final cm = (inches * 2.54).round();
    return "$feet'$inc\"/${cm}cm";
  }

  String _fmtWeight(int lb) {
    final kg = (lb * 0.453592).round();
    return "$lb lbs/${kg}kg";
  }

  String _fmtWingspan(int inches) {
    final feet = inches ~/ 12;
    final inc = inches % 12;
    final cm = (inches * 2.54).round();
    return "$feet'$inc\"/${cm}cm";
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderState>();

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
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${state.position.label}  ${_fmtHeight(state.heightInches)}  ${_fmtWeight(state.weightLb)}  ${_fmtWingspan(state.wingspanInches)}',
                    style: TextStyle(
                      fontFamily: AppTokens.fontFamily,
                      fontSize: 9,
                      fontWeight: FontWeight.w300,
                      color: AppTokens.textSecondary,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTokens.textSecondary,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              PositionSelector(selected: state.position, onSelected: state.setPosition),
              const SizedBox(height: 12),
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
