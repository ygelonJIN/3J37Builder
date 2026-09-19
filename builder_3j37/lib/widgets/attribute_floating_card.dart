import 'package:flutter/material.dart';
import '../data/models/attribute.dart';
import '../data/models/enums.dart';
import '../data/services/builder_state_v3.dart';
import '../data/services/dataset_loader.dart';
import '../theme/app_tokens.dart';
import '../extensions/context_extensions.dart';
import 'package:provider/provider.dart';

class AttributeFloatingCard extends StatefulWidget {
  final Set<int> lockedAttributes;
  final ValueChanged<int> onToggleLock;
  final ValueChanged<bool>? onExpandedChanged;
  final bool initialExpanded;
  final double fontSizeOffset;

  const AttributeFloatingCard({
    super.key,
    required this.lockedAttributes,
    required this.onToggleLock,
    this.onExpandedChanged,
    this.initialExpanded = false,
    this.fontSizeOffset = 0,
  });

  @override
  State<AttributeFloatingCard> createState() => _AttributeFloatingCardState();
}

class _AttributeFloatingCardState extends State<AttributeFloatingCard> {
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderStateV3>();
    final loader = DatasetLoader();
    final ovr = state.overallRating;
    final preciseOvr = loader.getOvr(state.position, state.heightInches, state.baseRatings);
    final attributes = loader.attributes;
    final caps = state.getAttributeCaps();

    return AnimatedContainer(
      duration: AppTokens.animShort,
      curve: AppTokens.curveOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  '$ovr',
                  style: AppTokens.brandMark.copyWith(fontSize: 18 + widget.fontSizeOffset, letterSpacing: 0),
                ),
                const SizedBox(width: 2),
                Text(
                  '(${preciseOvr.toStringAsFixed(1)})',
                  style: TextStyle(
                    fontFamily: AppTokens.fontFamily,
                    fontSize: 9 + widget.fontSizeOffset,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.keyOff,
                  ),
                ),
                const Spacer(),
                Text(
                  context.tr('minimap'),
                  style: TextStyle(
                    fontFamily: AppTokens.fontFamily,
                    fontSize: 9 + widget.fontSizeOffset,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.textSecondary,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTokens.textSecondary,
                ),
              ],
            ),
          )),
          if (_expanded) ...[
            const SizedBox(height: 0),
            _buildMinimap(attributes, state, caps),
          ],
        ],
      ),
    );
  }

  Widget _buildMinimap(List<AttributeDef> attributes, BuilderStateV3 state, List<int> caps) {
    // Group attributes by discipline
    final grouped = <Discipline, List<AttributeDef>>{};
    for (final attr in attributes) {
      grouped.putIfAbsent(attr.discipline, () => []).add(attr);
    }
    
    final rows = <Widget>[];
    // Build rows for each discipline group
    for (final disc in Discipline.values) {
      final attrs = grouped[disc];
      if (attrs == null || attrs.isEmpty) continue;
      
      // Add attributes in pairs of 2
      for (int i = 0; i < attrs.length; i += 2) {
        final a1 = attrs[i];
        final a2 = i + 1 < attrs.length ? attrs[i + 1] : null;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Expanded(child: _buildTile(a1, state.ratings[a1.index], caps[a1.index])),
                const SizedBox(width: 2),
                Expanded(child: a2 != null ? _buildTile(a2, state.ratings[a2.index], caps[a2.index]) : const SizedBox()),
              ],
            ),
          ),
        );
      }
    }
    return Column(children: rows);
  }

  Widget _buildTile(AttributeDef attr, int value, int cap) {
    final atCap = value >= cap;
    final isLocked = widget.lockedAttributes.contains(attr.index);
    final colour = AppTokens.disciplineColours[attr.discipline.name] ?? AppTokens.textSecondary;
    final xColor = (atCap || isLocked) ? AppTokens.keyOff : colour;
    const yColor = AppTokens.keyOff;
    final nameColor = (atCap || isLocked) ? AppTokens.keyOff : AppTokens.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: colour.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr(attr.name),
              style: TextStyle(
                fontFamily: AppTokens.fontFamily,
                fontSize: 9 + widget.fontSizeOffset,
                fontWeight: FontWeight.w500,
                color: nameColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 9 + widget.fontSizeOffset,
              fontWeight: FontWeight.w700,
              color: xColor,
            ),
          ),
          Text(
            '/$cap',
            style: TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 9 + widget.fontSizeOffset,
              fontWeight: FontWeight.w500,
              color: yColor,
            ),
          ),
        ],
      ),
    );
  }
}
