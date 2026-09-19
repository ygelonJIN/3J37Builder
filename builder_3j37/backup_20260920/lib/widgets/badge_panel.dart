import 'package:flutter/material.dart';
import '../data/models/badge_data.dart';
import '../data/models/enums.dart';
import '../data/services/builder_state_v3.dart';
import '../data/services/dataset_loader.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';
import 'center_dialog.dart';
import '../extensions/context_extensions.dart';

class BadgePanel extends StatelessWidget {
  const BadgePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderStateV3>();
    final statuses = state.getBadgeStatuses();
    final budget = state.getTokenBudget();
    final spent = state.getTokensSpent();
    final remaining = state.getTokensRemaining();
    final totalBudget = budget.reduce((a, b) => a + b);
    final totalRemaining = remaining.reduce((a, b) => a + b);

    final grouped = <Discipline, List<BadgeStatus>>{};
    for (final s in statuses) {
      grouped.putIfAbsent(s.badge.discipline, () => []).add(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TokenBudgetRow(
          budget: budget,
          remaining: remaining,
          totalBudget: totalBudget,
          totalRemaining: totalRemaining,
          slotBudget: state.getSlotBudget(),
          slotRemaining: state.getSlotsRemaining(),
        ),
        const SizedBox(height: 16),
        ...Discipline.values.map((disc) {
          final badges = grouped[disc] ?? [];
          if (badges.isEmpty) return const SizedBox.shrink();
          final colour = AppTokens.disciplineColours[disc.name] ?? AppTokens.textSecondary;
          final tokenRemaining = remaining[disc.index];
          final tokenBudget = budget[disc.index];
          final slotRemaining = state.getSlotsRemaining();
          final slotBudget = state.getSlotBudget();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    Text(
                      context.tr(disc.name),
                      style: TextStyle(
                        fontFamily: AppTokens.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colour,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$tokenRemaining/$tokenBudget ${context.tr("tokens")} ${slotRemaining[disc.index]}/${slotBudget[disc.index]} ${context.tr("slots")}',
                      style: TextStyle(
                        fontFamily: AppTokens.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colour,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: badges.map((status) {
                  return _BadgeChip(status: status, colour: colour);
                }).toList(),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _TokenBudgetRow extends StatelessWidget {
  final List<int> budget;
  final List<int> remaining;
  final int totalBudget;
  final int totalRemaining;
  final List<int> slotBudget;
  final List<int> slotRemaining;

  const _TokenBudgetRow({
    required this.budget,
    required this.remaining,
    required this.totalBudget,
    required this.totalRemaining,
    required this.slotBudget,
    required this.slotRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.surfaceAlt,
        border: Border.all(color: AppTokens.cardBorder),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        children: [
          // 总数（大号，主题色）
          Text(
            '$totalRemaining/$totalBudget',
            style: TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppTokens.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...Discipline.values.map((disc) {
              final colour = AppTokens.disciplineColours[disc.name] ?? AppTokens.textSecondary;
              final b = budget[disc.index];
              final r = remaining[disc.index];
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${context.tr(disc.name)}  $r/$b ${context.tr("tokens")}  ${slotRemaining[disc.index]}/${slotBudget[disc.index]} ${context.tr("slots")}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTokens.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colour,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final BadgeStatus status;
  final Color colour;

  const _BadgeChip({required this.status, required this.colour});

  @override
  Widget build(BuildContext context) {
    final badge = status.badge;
    final isEquipped = status.isEquipped;
    final isUnlocked = status.isUnlocked;
    final tierColours = AppTokens.badgeTierColours;

    Color borderColor;
    if (isEquipped) {
      final equippedTier = context.read<BuilderStateV3>().equippedBadges[badge.badgeId];
      borderColor = equippedTier != null
          ? Color(int.parse(tierColours[equippedTier.key]!.value.toRadixString(16).padLeft(8, '0'), radix: 16))
          : AppTokens.primary;
    } else if (isUnlocked) {
      borderColor = AppTokens.textSecondary.withValues(alpha: 0.5);
    } else {
      borderColor = AppTokens.keyOff.withValues(alpha: 0.3);
    }

    final blockColor = status.highestTier != null
        ? Color(int.parse(tierColours[status.highestTier!.key]!.value.toRadixString(16).padLeft(8, '0'), radix: 16))
        : Colors.transparent;

    return Material(type: MaterialType.transparency, child: InkWell(
      onTap: () => _showBadgeDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isUnlocked ? AppTokens.surface : AppTokens.surface.withValues(alpha: 0.5),
          border: Border.all(color: borderColor, width: isEquipped ? 2 : 1),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(badge.name),
              style: AppTokens.caption.copyWith(
                color: isUnlocked ? AppTokens.textPrimary : AppTokens.keyOff,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              color: blockColor,
            ),
          ],
        ),
      ),
    ));
  }

  void _showBadgeDetails(BuildContext context) {
    final loader = DatasetLoader();
    final badge = status.badge;
    final state = context.read<BuilderStateV3>();
    final tierColours = AppTokens.badgeTierColours;
    final remaining = state.getTokensRemaining();

    CenterDialog.show(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final currentEquipped = state.equippedBadges[badge.badgeId];
          
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Icon(
                      currentEquipped != null ? Icons.check_circle : Icons.lock_open,
                      size: 18,
                      color: currentEquipped != null ? AppTokens.primary : AppTokens.keyOff,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(context.tr(badge.name), style: AppTokens.cardTitleStyle),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildHeightRequirement(context, badge, state),
                const SizedBox(height: 16),
                Text(context.tr('tap_tier_to_equip'), style: AppTokens.caption),
                const SizedBox(height: 8),
                ...[BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold, BadgeTier.hallOfFame].map((tier) {
                  final reqs = loader.tierRequirements.where(
                    (r) => r.badgeId == badge.badgeId && r.tier == tier,
                  );
                  final tierColour = Color(int.parse(tierColours[tier.key]!.value.toRadixString(16).padLeft(8, '0'), radix: 16));
                  final tokenCost = loader.getBadgeTokenCost(badge.badgeId, tier, state.heightInches);
                  final oldCost = currentEquipped != null ? loader.getBadgeTokenCost(badge.badgeId, currentEquipped, state.heightInches) : 0;
                  final delta = tokenCost - oldCost;
                  final canAfford = delta <= remaining[badge.discipline.index];
                  final meetsReqs = _meetsRequirements(reqs, state);
                  final meetsHeight = status.heightEligible;
                  final isCurrentTier = currentEquipped == tier;
                  final canEquip = meetsReqs && canAfford && meetsHeight;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCurrentTier ? AppTokens.surfaceAlt : AppTokens.surface,
                      border: Border.all(
                        color: isCurrentTier ? tierColour : (canEquip ? AppTokens.cardBorder : AppTokens.keyOff.withValues(alpha: 0.3)),
                        width: isCurrentTier ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tierColour.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                context.tr(tier.key),
                                style: AppTokens.caption.copyWith(color: tierColour, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const Spacer(),
                            if (tokenCost > 0)
                              Text('${tokenCost} ${context.tr("tokens")}',
                                  style: AppTokens.caption.copyWith(color: canAfford ? AppTokens.primary : Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canEquip ? () {
                              if (isCurrentTier) {
                                state.equipBadge(badge.badgeId, null);
                              } else {
                                state.equipBadge(badge.badgeId, tier);
                              }
                              setDialogState(() {});
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCurrentTier ? Colors.red : (canEquip ? AppTokens.primary : AppTokens.keyOff),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTokens.radius),
                              ),
                            ),
                            child: Text(
                              isCurrentTier ? context.tr('unequip') : context.tr('equip'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!meetsHeight)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.close, size: 12, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(
                                  context.tr('height_not_eligible'),
                                  style: AppTokens.caption.copyWith(fontSize: 11, color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ...reqs.expand((req) => req.requirements.map((r) {
                          final attrName = context.tr(r.name);
                          final currentVal = state.ratings[r.attributeIndex];
                          final meets = currentVal >= r.minimum;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(
                                  meets ? Icons.check : Icons.close,
                                  size: 12,
                                  color: meets ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text('$attrName: ${r.minimum}', style: AppTokens.caption.copyWith(fontSize: 11)),
                                ),
                                Text('($currentVal)', style: AppTokens.caption.copyWith(fontSize: 10, color: meets ? Colors.green : AppTokens.keyOff)),
                              ],
                            ),
                          );
                        })),
                      ],
                    ),
                  );
                }),
              ],
            ),
            ),
          );
        },
      ),
      onClose: () {
        FocusScope.of(context).unfocus();
        Navigator.of(context).pop();
      },
    );
  }


  Widget _buildHeightRequirement(BuildContext context, BadgeDef badge, BuilderStateV3 state) {
    final minHeight = badge.minHeight;
    final maxHeight = badge.maxHeight;
    final currentHeight = state.heightInches;
    final meetsHeight = currentHeight >= minHeight && currentHeight <= maxHeight;
    
    String formatHeight(int inches) {
      final feet = inches ~/ 12;
      final inc = inches % 12;
      return "$feet'$inc\"";
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTokens.surfaceAlt,
        border: Border.all(color: AppTokens.cardBorder.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Row(
        children: [
          Icon(
            meetsHeight ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: meetsHeight ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${context.tr("height")}: ',
                    style: AppTokens.caption.copyWith(fontSize: 11),
                  ),
                  TextSpan(
                    text: '${formatHeight(minHeight)} - ${formatHeight(maxHeight)}',
                    style: AppTokens.caption.copyWith(
                      fontSize: 11,
                      color: meetsHeight ? AppTokens.textPrimary : AppTokens.keyOff,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '(${context.tr("current")}: ${formatHeight(currentHeight)})',
            style: AppTokens.caption.copyWith(
              fontSize: 10,
              color: meetsHeight ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  bool _meetsRequirements(Iterable<BadgeTierRequirement> reqs, BuilderStateV3 state) {
    for (final req in reqs) {
      for (final r in req.requirements) {
        if (state.ratings[r.attributeIndex] < r.minimum) return false;
      }
    }
    return true;
  }
}
