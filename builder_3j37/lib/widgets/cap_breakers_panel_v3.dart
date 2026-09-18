import 'center_dialog.dart';
import 'package:flutter/material.dart';
import '../data/services/builder_state_v4.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';
import '../extensions/context_extensions.dart';

/// Interactive Cap Breakers panel
/// 使用解密模型数据计算，无服务端依赖
class CapBreakersPanelV3 extends StatelessWidget {
  const CapBreakersPanelV3({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderStateV4>();
    
    final attributesWithPotential = <int>[];
    for (int i = 0; i < 21; i++) {
      final attrState = state.getAttributeState(i);
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
            Text(context.tr('cap_breakers'), style: AppTokens.cardTitleStyle.copyWith(fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.memory, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Model Data',
                    style: TextStyle(fontSize: 10, color: Colors.green),
                  ),
                ],
              ),
            ),
            if (state.hasAnyCapBreakers) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _showClearAllDialog(context, state),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text(context.tr('clear_all'), style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Apply up to 5 cap breakers per attribute to exceed the physical cap.',
          style: AppTokens.caption.copyWith(fontSize: 11),
        ),
        if (state.hasAnyCapBreakers) ...[
          const SizedBox(height: 4),
          Text(
            'Total applied: ${state.totalCapBreakersApplied}',
            style: AppTokens.caption.copyWith(
              fontSize: 11,
              color: AppTokens.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...attributesWithPotential.map((attrIndex) => _buildAttributeRow(context, state, attrIndex)),
      ],
    );
  }

  Widget _buildAttributeRow(BuildContext context, BuilderStateV4 state, int attrIndex) {
    final attrState = state.getAttributeState(attrIndex);
    final nextGain = state.getNextCapBreakerGain(attrIndex);
    final canApply = nextGain != null;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: _getCategoryColor(attrIndex),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _attrName(attrIndex),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${attrState.finalValue}',
                style: TextStyle(
                  fontSize: 13,
                  color: canApply ? AppTokens.primary : AppTokens.keyOff,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/${attrState.baseCap}',
                style: TextStyle(
                  fontSize: 11,
                  color: _getCategoryColor(attrIndex),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canApply ? () => _applyCapBreaker(context, state, attrIndex) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: canApply 
                        ? AppTokens.primary.withValues(alpha: 0.2)
                        : AppTokens.keyOff.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: canApply 
                          ? AppTokens.primary.withValues(alpha: 0.5)
                          : AppTokens.keyOff.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    canApply ? '+$nextGain' : 'MAX',
                    style: TextStyle(
                      fontSize: 11,
                      color: canApply ? AppTokens.primary : AppTokens.keyOff,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(5, (index) {
              final isApplied = index < attrState.appliedGains.length;
              final gain = isApplied ? attrState.appliedGains[index] : null;
              
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: isApplied ? () => _removeCapBreaker(context, state, attrIndex) : null,
                  child: Container(
                    width: 32,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isApplied 
                          ? _getTierColor(index).withValues(alpha: 0.3)
                          : AppTokens.keyOff.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isApplied 
                            ? _getTierColor(index)
                            : AppTokens.keyOff.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: isApplied
                          ? Text(
                              '+${attrState.appliedGains[index]}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : gain != null
                              ? Text(
                                  '+$gain',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _getTierColor(index),
                                    fontWeight: FontWeight.w800,
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
          if (attrState.hasCapBreakers) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => state.removeCapBreaker(attrIndex),
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
    );
  }

  void _applyCapBreaker(BuildContext context, BuilderStateV4 state, int attrIndex) {
    final success = state.applyCapBreaker(attrIndex);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(context.tr('cannot_apply_cap_breaker')),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeCapBreaker(BuildContext context, BuilderStateV4 state, int attrIndex) {
    state.removeCapBreaker(attrIndex);
  }

  void _showClearAllDialog(BuildContext context, BuilderStateV4 state) {
    CenterDialog.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(context.tr('clear_all_cap_breakers'), style: AppTokens.cardTitleStyle),
            const SizedBox(height: 16),
            Text('Remove all ${state.totalCapBreakersApplied} cap breakers?', style: AppTokens.body),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(context.tr('cancel')),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    state.clearAllCapBreakers();
                    Navigator.pop(context);
                  },
                  child: const Text(context.tr('clear_all'), style: TextStyle(color: Colors.red)),
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
    if (index < 5) return const Color(0xFF60A5FA);
    if (index < 8) return const Color(0xFF4ADE80);
    if (index < 11) return const Color(0xFFFACC15);
    if (index < 15) return const Color(0xFFF87171);
    if (index < 17) return const Color(0xFFC084FC);
    return const Color(0xFFC4A882);
  }

  Color _getTierColor(int tier) {
    const colors = [
      Color(0xFF06B6D4),
      Color(0xFF3B82F6),
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFD946EF),
    ];
    return tier < colors.length ? colors[tier] : colors[0];
  }
}
