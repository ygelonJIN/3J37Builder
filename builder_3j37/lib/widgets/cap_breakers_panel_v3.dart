import 'package:flutter/material.dart';
import '../data/services/builder_state_v4.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';

/// Interactive Cap Breakers panel with server data support
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
            Text('Cap Breakers', style: AppTokens.cardTitleStyle.copyWith(fontSize: 14)),
            const Spacer(),
            // Server data indicator
            if (state.isUsingServerData)
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
                    Icon(Icons.cloud_done, size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Live Data',
                      style: TextStyle(fontSize: 10, color: Colors.green),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storage, size: 12, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Local Data',
                      style: TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            // Fetch from server button
            TextButton.icon(
              onPressed: state.isLoadingServerData 
                  ? null 
                  : () => _fetchFromServer(context, state),
              icon: state.isLoadingServerData
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.refresh, size: 16),
              label: Text(
                state.isLoadingServerData ? 'Loading...' : 'Fetch Live',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            if (state.hasAnyCapBreakers)
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
        if (!state.isUsingServerData)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Tap "Fetch Live" to get accurate values for your build.',
              style: AppTokens.caption.copyWith(fontSize: 10, color: Colors.orange),
            ),
          ),
        if (state.hasAnyCapBreakers) ...[
          const SizedBox(height: 4),
          Text(
            'Total applied: ${state.totalCapBreakersApplied}',
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

  Future<void> _fetchFromServer(BuildContext context, BuilderStateV4 state) async {
    final success = await state.fetchServerData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Live data fetched successfully!' 
              : 'Failed to fetch live data. Using local data.'),
          duration: Duration(seconds: 2),
          backgroundColor: success ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Widget _buildAttributeRow(BuildContext context, BuilderStateV4 state, int attrIndex) {
    final attrState = state.getAttributeState(attrIndex);
    final nextGain = state.getNextCapBreakerGain(attrIndex);
    final appliedGains = attrState.appliedGains;
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
            Row(
              children: List.generate(5, (index) {
                final isApplied = index < appliedGains.length;
                final gain = isApplied ? appliedGains[index] : (index == appliedGains.length ? nextGain : null);
                final isUsable = isApplied || (index == appliedGains.length && canApply);
                
                return Expanded(
                  child: GestureDetector(
                    onTap: isUsable && !isApplied 
                        ? () => _applyCapBreaker(context, state, attrIndex)
                        : isApplied 
                            ? () => _removeCapBreaker(context, state, attrIndex)
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
                            : gain != null
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
      ),
    );
  }

  void _applyCapBreaker(BuildContext context, BuilderStateV4 state, int attrIndex) {
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

  void _removeCapBreaker(BuildContext context, BuilderStateV4 state, int attrIndex) {
    state.removeCapBreaker(attrIndex);
  }

  void _showClearAllDialog(BuildContext context, BuilderStateV4 state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Cap Breakers'),
        content: Text('Remove all ${state.totalCapBreakersApplied} cap breakers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              state.clearAllCapBreakers();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
