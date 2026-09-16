import 'package:flutter/material.dart';
import '../data/services/builder_state.dart';
import '../data/services/cap_breaker_engine.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';

class CapBreakersPanel extends StatelessWidget {
  const CapBreakersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderState>();
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
        Row(
          children: [
            Text('Cap Breakers', style: AppTokens.cardTitleStyle.copyWith(fontSize: 14)),
            const Spacer(),
            if (state.hasAnyCapBreakers)
              TextButton.icon(
                onPressed: () => state.clearAllCapBreakers(),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('重置', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '已使用: ${state.totalCapBreakersApplied} / 28',
          style: AppTokens.caption.copyWith(fontSize: 11, color: AppTokens.primary),
        ),
        const SizedBox(height: 12),
        ...attributesWithHeadroom.map((i) => _buildCapBreakerRow(context, state, i, ratings[i], caps[i])),
      ],
    );
  }

  Widget _buildCapBreakerRow(BuildContext context, BuilderState state, int attrIndex, int rating, int cap) {
    final gains = state.getCapBreakerSequence(attrIndex);
    final appliedCount = state.getAppliedCapBreakerCount(attrIndex);
    final appliedGain = state.getCapBreakerGain(attrIndex);
    final nextGain = state.getNextCapBreakerGain(attrIndex);
    final canApply = state.canApplyCapBreaker(attrIndex);
    
    final attrName = CapBreakerEngine.getAttributeName(attrIndex);
    final categoryColor = _getCategoryColor(attrIndex);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTokens.surfaceAlt,
          border: Border.all(
            color: appliedCount > 0 
                ? AppTokens.primary.withValues(alpha: 0.5)
                : AppTokens.cardBorder.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(attrName, style: AppTokens.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (appliedCount > 0)
                        Text(
                          '+$appliedGain ($appliedCount枚)',
                          style: AppTokens.caption.copyWith(fontSize: 10, color: AppTokens.primary),
                        ),
                    ],
                  ),
                ),
                Text(
                  '$rating → ${rating + appliedGain}',
                  style: AppTokens.body.copyWith(fontSize: 12, color: categoryColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Tier buttons
            Row(
              children: List.generate(5, (index) {
                final isApplied = index < appliedCount;
                final isNext = index == appliedCount && canApply;
                final gain = index < gains.length ? gains[index] : null;
                
                return Expanded(
                  child: GestureDetector(
                    onTap: isApplied 
                        ? () => state.removeCapBreaker(attrIndex)
                        : isNext 
                            ? () => state.applyCapBreaker(attrIndex)
                            : null,
                    child: Container(
                      margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                      height: 28,
                      decoration: BoxDecoration(
                        color: isApplied 
                            ? AppTokens.primary.withValues(alpha: 0.3)
                            : isNext 
                                ? AppTokens.primary.withValues(alpha: 0.1)
                                : AppTokens.surface,
                        border: Border.all(
                          color: isApplied 
                              ? AppTokens.primary 
                              : isNext 
                                  ? AppTokens.primary.withValues(alpha: 0.5)
                                  : AppTokens.keyOff.withValues(alpha: 0.3),
                          width: isApplied ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: gain != null
                            ? Text(
                                '+$gain',
                                style: AppTokens.caption.copyWith(
                                  fontSize: 10,
                                  color: isApplied ? AppTokens.primary : AppTokens.textSecondary,
                                  fontWeight: isApplied ? FontWeight.w700 : FontWeight.w500,
                                ),
                              )
                            : Icon(Icons.lock, size: 12, color: AppTokens.keyOff),
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

  Color _getCategoryColor(int attrIndex) {
    const categoryColors = {
      'finishing': 0xFF00a4ff,
      'shooting': 0xFF31de74,
      'playmaking': 0xFFFFc600,
      'defense': 0xFFFF6466,
      'rebounding': 0xFFb57eff,
      'physical': 0xFFc4a882,
    };
    if (attrIndex < 5) return Color(categoryColors['finishing']!);
    if (attrIndex < 8) return Color(categoryColors['shooting']!);
    if (attrIndex < 11) return Color(categoryColors['playmaking']!);
    if (attrIndex < 15) return Color(categoryColors['defense']!);
    if (attrIndex < 17) return Color(categoryColors['rebounding']!);
    return Color(categoryColors['physical']!);
  }
}
