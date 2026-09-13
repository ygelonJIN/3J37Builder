import 'package:flutter/material.dart';
import '../data/services/builder_state.dart';
import '../data/services/dataset_loader.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';

class CapBreakersPanel extends StatelessWidget {
  const CapBreakersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderState>();
    final loader = DatasetLoader();
    final caps = state.getAttributeCaps();
    final ratings = state.ratings;

    // 找出还有空间的属性（rating < cap）
    final attributesWithHeadroom = <int>[];
    for (int i = 0; i < 21; i++) {
      if (ratings[i] < caps[i]) {
        attributesWithHeadroom.add(i);
      }
    }

    if (attributesWithHeadroom.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cap Breakers', style: AppTokens.cardTitleStyle.copyWith(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          'Each attribute can use up to 5 cap breakers to exceed its current cap.',
          style: AppTokens.caption.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 12),
        ...attributesWithHeadroom.map((i) => _buildCapBreakerRow(context, i, ratings[i], caps[i], loader)),
      ],
    );
  }

  Widget _buildCapBreakerRow(BuildContext context, int attrIndex, int rating, int cap, DatasetLoader loader) {
    final gains = loader.getCapBreakerGains(attrIndex, rating);
    final headroom = cap - rating;
    
    // 计算可用的 cap breakers 数量
    int availableBreakers = 0;
    int totalGain = 0;
    for (final gain in gains) {
      if (totalGain + gain.gain <= headroom) {
        availableBreakers++;
        totalGain += gain.gain;
      } else {
        break;
      }
    }

    final attrName = _attrName(attrIndex);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTokens.surfaceAlt,
          border: Border.all(color: AppTokens.cardBorder.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    attrName,
                    style: AppTokens.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$rating/$cap',
                  style: AppTokens.body.copyWith(
                    fontSize: 12,
                    color: AppTokens.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 显示5个 Cap Breaker 格子
            Row(
              children: List.generate(5, (index) {
                final isAvailable = index < gains.length;
                final gain = isAvailable ? gains[index] : null;
                final isUsable = gain != null && (rating + _calculateTotalGain(gains, index)) <= cap;
                
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                    height: 24,
                    decoration: BoxDecoration(
                      color: isUsable 
                          ? AppTokens.primary.withValues(alpha: 0.2)
                          : AppTokens.surface,
                      border: Border.all(
                        color: isUsable 
                            ? AppTokens.primary 
                            : AppTokens.keyOff.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(
                      child: isUsable && gain != null
                          ? Text(
                              '+${gain.gain}',
                              style: AppTokens.caption.copyWith(
                                fontSize: 10,
                                color: AppTokens.primary,
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
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateTotalGain(List<dynamic> gains, int upToIndex) {
    int total = 0;
    for (int i = 0; i <= upToIndex && i < gains.length; i++) {
      total += (gains[i] as dynamic).gain as int;
    }
    return total;
  }

  String _attrName(int index) {
    const names = [
      'Close Shot', 'Driving Layup', 'Driving Dunk', 'Standing Dunk', 'Post Control',
      'Mid Range', '3PT', 'Free Throw', 'Pass Acc', 'Ball Handle', 'Spd w/ Ball',
      'Int Def', 'Per Def', 'Steal', 'Block', 'OReb', 'DReb', 'Speed', 'Agility', 'Strength', 'Vertical',
    ];
    return index < names.length ? names[index] : 'Attr $index';
  }
}
