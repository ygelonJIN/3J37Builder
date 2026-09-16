import 'center_dialog.dart';
import 'package:flutter/material.dart';
import '../data/services/builder_state_v2.dart';
import '../data/services/dataset_loader.dart';
import '../data/models/cap_breaker.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';

/// Interactive Cap Breakers panel that allows applying/removing cap breakers
class CapBreakersPanelV2 extends StatelessWidget {
  const CapBreakersPanelV2({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderStateV2>();
    
    // Find attributes that can have cap breakers applied
    final attributesWithPotential = <int>[];
    for (int i = 0; i < 21; i++) {
      final attrState = state.getAttributeState(i);
      // Show if: has cap breakers applied, OR has headroom for cap breakers
      if (attrState.hasCapBreakers || attrState.canApplyMoreCapBreakers) {
        attributesWithPotential.add(i);
      }
    }

    if (attributesWithPotential.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Cap Breakers', style: AppTokens.cardTitleStyle.copyWith(fontSize: 14)),
            const Spacer(),
            if (state.capBreakerState.hasAnyApplied)
              TextButton.icon(
                onPressed: () => _showClearAllDialog(context, state),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Apply up to 5 cap breakers per attribute to exceed the physical cap.',
          style: AppTokens.caption.copyWith(fontSize: 11),
        ),
        if (state.capBreakerState.hasAnyApplied) ...[
          const SizedBox(height: 4),
          Text(
            'Total applied: ${state.capBreakerState.totalApplied}',
            style: AppTokens.caption.copyWith(
              fontSize: 11,
              color: AppTokens.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...attributesWithPotential.map((i) => _buildAttributeRow(context, state, i)),
      ],
    );
  }

  Widget _buildAttributeRow(BuildContext context, BuilderStateV2 state, int attrIndex) {
    final attrState = state.getAttributeState(attrIndex);
    // availableGains no longer used - slots use getNextCapBreakerGain directly
    final appliedGains = state.capBreakerState.getAppliedGains(attrIndex);
    final canApply = state.canApplyCapBreaker(attrIndex);
    
    final attrName = _attrName(attrIndex);
    final categoryColor = _getCategoryColor(attrIndex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTokens.surfaceAlt,
          border: Border.all(
            color: attrState.hasCapBreakers 
                ? AppTokens.primary.withValues(alpha: 0.5)
                : AppTokens.cardBorder.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attrName,
                        style: AppTokens.body.copyWith(
                          fontSize: 12, 
                          fontWeight: FontWeight.w600,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Base: ${attrState.baseValue}',
                            style: AppTokens.caption.copyWith(fontSize: 10),
                          ),
                          if (attrState.hasCapBreakers) ...[
                            Text(
                              ' + ${attrState.capBreakerGain} CB',
                              style: AppTokens.caption.copyWith(
                                fontSize: 10,
                                color: AppTokens.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          Text(
                            ' / Cap: ${attrState.baseCap}',
                            style: AppTokens.caption.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Final value display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: attrState.hasCapBreakers 
                        ? AppTokens.primary.withValues(alpha: 0.15)
                        : AppTokens.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: attrState.hasCapBreakers 
                          ? AppTokens.primary 
                          : AppTokens.cardBorder.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${attrState.finalValue}',
                    style: AppTokens.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: attrState.hasCapBreakers 
                          ? AppTokens.primary 
                          : AppTokens.body.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 5 cap breaker slots
            Row(
              children: List.generate(5, (index) {
                final isApplied = index < appliedGains.length;
                // Slot is available if: not yet applied, can still apply more, and within 5 max
                final isAvailable = !isApplied && canApply && index >= appliedGains.length && index < 5;
                // Get gain: for applied slots use stored gain, for available slots use next gain
                final gain = isApplied ? appliedGains[index] : 
                             (isAvailable ? (state.getNextCapBreakerGain(attrIndex) ?? 0) : 0);
                
                // Calculate what the value would be after this CB
                int valueAfter = attrState.baseValue;
                if (isApplied) {
                  // Sum all gains up to and including this one
                  for (int j = 0; j <= index; j++) {
                    valueAfter += appliedGains[j];
                  }
                }
                
                // Determine if this slot is usable
                bool isUsable = false;
                if (isApplied) {
                  isUsable = true; // Already applied
                } else if (isAvailable && canApply && index >= appliedGains.length) {
                  isUsable = true; // All remaining available slots
                }
                
                return Expanded(
                  child: GestureDetector(
                    onTap: isUsable && !isApplied 
                        ? () => _applyCapBreaker(context, state, attrIndex)
                        : isApplied 
                            ? () => _removeCapBreaker(context, state, attrIndex, index)
                            : null,
                    child: Container(
                      margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                      height: 28,
                      decoration: BoxDecoration(
                        color: isApplied 
                            ? _getTierColor(index)
                            : isUsable 
                                ? _getTierColor(index).withValues(alpha: 0.15)
                                : AppTokens.surface,
                        border: Border.all(
                          color: isApplied 
                              ? _getTierColor(index)
                              : isUsable 
                                  ? _getTierColor(index).withValues(alpha: 0.5)
                                  : AppTokens.keyOff.withValues(alpha: 0.3),
                          width: isUsable ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: isApplied
                            ? Text(
                                '+${appliedGains[index]}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : isAvailable
                                ? Text(
                                    '+$gain',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _getTierColor(index),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : Icon(
                                    Icons.lock,
                                    size: 12,
                                    color: AppTokens.keyOff,
                                  ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            
            // Action buttons
            if (attrState.hasCapBreakers) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _removeLastCapBreaker(state, attrIndex),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Undo Last',
                      style: TextStyle(fontSize: 10, color: AppTokens.keyOff),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => state.removeAllCapBreakers(attrIndex),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Remove All',
                      style: TextStyle(fontSize: 10, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _applyCapBreaker(BuildContext context, BuilderStateV2 state, int attrIndex) {
    final success = state.applyCapBreaker(attrIndex);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot apply cap breaker: no more headroom or max reached'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeCapBreaker(BuildContext context, BuilderStateV2 state, int attrIndex, int index) {
    // For simplicity, remove the last one (you could implement removing specific ones)
    _removeLastCapBreaker(state, attrIndex);
  }

  void _removeLastCapBreaker(BuilderStateV2 state, int attrIndex) {
    state.removeCapBreaker(attrIndex);
  }

  void _showClearAllDialog(BuildContext context, BuilderStateV2 state) {
    CenterDialog.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clear All Cap Breakers', style: AppTokens.cardTitleStyle),
            const SizedBox(height: 16),
            Text('Remove all ${state.capBreakerState.totalApplied} cap breakers?', style: AppTokens.body),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    state.clearAllCapBreakers();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
      onClose: () {
        FocusScope.of(context).unfocus();
        Navigator.of(context).pop();
      },
    );
  }


  String _attrName(int index) {
    const names = [
      'Close Shot', 'Driving Layup', 'Driving Dunk', 'Standing Dunk', 'Post Control',
      'Mid Range', '3PT', 'Free Throw', 'Pass Acc', 'Ball Handle', 'Spd w/ Ball',
      'Int Def', 'Per Def', 'Steal', 'Block', 'OReb', 'DReb', 'Speed', 'Agility', 'Strength', 'Vertical',
    ];
    return index < names.length ? names[index] : 'Attr $index';
  }

  Color _getCategoryColor(int index) {
    if (index < 5) return const Color(0xFF60A5FA); // Finishing - blue
    if (index < 8) return const Color(0xFF4ADE80); // Shooting - green
    if (index < 11) return const Color(0xFFFACC15); // Playmaking - yellow
    if (index < 15) return const Color(0xFFF87171); // Defense - red
    if (index < 17) return const Color(0xFFC084FC); // Rebounding - purple
    return const Color(0xFFC4A882); // Physicals - tan
  }

  Color _getTierColor(int tier) {
    const colors = [
      Color(0xFF06B6D4), // cyan
      Color(0xFF3B82F6), // blue
      Color(0xFF6366F1), // indigo
      Color(0xFF8B5CF6), // violet
      Color(0xFFD946EF), // fuchsia
    ];
    return tier < colors.length ? colors[tier] : colors[0];
  }
}
