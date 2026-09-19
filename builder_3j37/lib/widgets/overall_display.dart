import 'package:flutter/material.dart';
import '../data/services/builder_state_v3.dart';
import '../data/services/dataset_loader.dart';
import '../data/models/enums.dart';
import '../theme/app_tokens.dart';
import '../extensions/context_extensions.dart';
import 'package:provider/provider.dart';
import 'position_selector.dart';
import 'body_configurator.dart';

class OverallDisplay extends StatefulWidget {
  final ValueChanged<bool>? onExpandedChanged;
  final bool initialExpanded;
  final double fontSizeOffset;
  
  const OverallDisplay({super.key, this.onExpandedChanged, this.initialExpanded = false, this.fontSizeOffset = 0});

  @override
  State<OverallDisplay> createState() => _OverallDisplayState();
}

class _OverallDisplayState extends State<OverallDisplay> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

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
    final state = context.watch<BuilderStateV3>();

    return AnimatedContainer(
      duration: AppTokens.animShort,
      curve: AppTokens.curveOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.surfaceAlt,
        border: Border.all(color: AppTokens.primary.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(type: MaterialType.transparency, child: InkWell(
            onTap: _toggleExpanded,
            child: Row(
              children: [
                Text(
                  '${state.position.label}  ${_fmtHeight(state.heightInches)}  ${_fmtWeight(state.weightLb)}  ${_fmtWingspan(state.wingspanInches)}',
                  style: TextStyle(
                    fontFamily: AppTokens.fontFamily,
                    fontSize: 10 + widget.fontSizeOffset,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.primary,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTokens.textSecondary,
                ),
              ],
            ),
          )),
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
    );
  }
}
