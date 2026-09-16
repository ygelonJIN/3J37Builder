import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/enums.dart';
import '../data/models/attribute.dart';
import '../data/models/badge_data.dart';
import '../data/services/dataset_loader.dart';
import '../data/services/cap_breaker_engine.dart';
import '../data/services/builder_state.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';
import 'plus_minus_control.dart';
import 'center_dialog.dart';

class AttributeGroups extends StatelessWidget {
  const AttributeGroups({super.key});

  @override
  Widget build(BuildContext context) {
    final loader = DatasetLoader();
    final state = context.watch<BuilderState>();
    final caps = state.getAttributeCaps();
    final attributes = loader.attributes;
    final isOvrMax = state.overallRating >= 99;
    final remaining = state.getTokensRemaining();
    final budget = state.getTokenBudget();

    final grouped = <Discipline, List<AttributeDef>>{};
    for (final attr in attributes) {
      grouped.putIfAbsent(attr.discipline, () => []).add(attr);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...Discipline.values.map((disc) {
          final attrs = grouped[disc] ?? [];
          if (attrs.isEmpty) return const SizedBox.shrink();
          final colour = AppTokens.disciplineColours[disc.name] ?? AppTokens.textSecondary;
          final tokenRemaining = remaining[disc.index];
          final tokenBudget = budget[disc.index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    Text(disc.displayName, style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 15, fontWeight: FontWeight.w600, color: colour)),
                    const SizedBox(width: 6),
                    Text('$tokenRemaining/$tokenBudget', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: colour)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...attrs.map((attr) {
                return _AttributeControl(
                  attribute: attr,
                  value: state.ratings[attr.index],
                  cap: caps[attr.index],
                  colour: colour,
                  onChanged: (v) => state.setRating(attr.index, v),
                  isOvrMax: isOvrMax,
                  isLocked: state.isAttributeLocked(attr.index),
                  onToggleLock: () => state.toggleAttributeLock(attr.index),
                  canAdjust: state.canAdjustAttribute(attr.index),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}

class _AttributeControl extends StatefulWidget {
  final AttributeDef attribute;
  final int value;
  final int cap;
  final Color colour;
  final ValueChanged<int> onChanged;
  final bool isOvrMax;
  final bool isLocked;
  final VoidCallback onToggleLock;
  final bool canAdjust;

  const _AttributeControl({
    required this.attribute,
    required this.value,
    required this.cap,
    required this.colour,
    required this.onChanged,
    this.isOvrMax = false,
    required this.isLocked,
    required this.onToggleLock,
    required this.canAdjust,
  });

  @override
  State<_AttributeControl> createState() => _AttributeControlState();
}

class _AttributeControlState extends State<_AttributeControl> {
  bool _expanded = false;
  bool _xEditing = false;
  late TextEditingController _xController;
  final FocusNode _xFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _xController = TextEditingController(text: '${widget.value}');
    _xFocus.addListener(_onXFocusChange);
  }

  @override
  void didUpdateWidget(covariant _AttributeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_xEditing && oldWidget.value != widget.value) {
      _xController.text = '${widget.value}';
    }
  }

  void _onXFocusChange() {
    if (!_xFocus.hasFocus && _xEditing) {
      final v = int.tryParse(_xController.text);
      if (v != null) {
        widget.onChanged(v.clamp(25, widget.cap));
      } else {
        _xController.text = '${widget.value}';
      }
      _xEditing = false;
    }
  }


  @override
  void dispose() {
    _xController.dispose();
    _xFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atCap = widget.value >= widget.cap;
    final bool isMaxed = widget.isOvrMax || atCap;
    final Color xColor = (isMaxed || widget.isLocked) ? AppTokens.keyOff : widget.colour;
    const Color yColor = AppTokens.keyOff;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _expanded = !_expanded);
                },
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(widget.attribute.displayName, style: AppTokens.caption.copyWith(color: isMaxed ? AppTokens.keyOff : AppTokens.textPrimary, fontSize: 11))),
                      Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: AppTokens.textSecondary),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PlusMinusControl(
                value: widget.value,
                min: 25,
                max: widget.cap,
                onChanged: widget.canAdjust ? widget.onChanged : null,
                activeColor: widget.colour,
              ),
              const SizedBox(width: 4),
              _buildNormalDisplay(xColor, yColor),
              const SizedBox(width: 6),
              _buildLockIcon(),
            ],
          ),
        ),
        if (_expanded) ...[
          _buildBadgeList(context),
          _buildCapBreakers(context),
        ],
      ],
    );
  }


  // ── Normal display: X input + /cap ────────────────────
  Widget _buildNormalDisplay(Color xColor, Color yColor) {
    return SizedBox(
      width: 70,
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 40,
            height: 28,
            child: TextField(
              controller: _xController,
              focusNode: _xFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              cursorWidth: 0,
              style: AppTokens.body.copyWith(color: xColor, fontSize: 12, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  borderSide: BorderSide(color: widget.colour.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  borderSide: BorderSide(color: widget.colour.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  borderSide: BorderSide(color: widget.colour, width: 1.5),
                ),
              ),
              onTap: () {
                _xEditing = true;
                _xController.selection = TextSelection(baseOffset: 0, extentOffset: _xController.text.length);
              },
              onSubmitted: (_) {
                final v = int.tryParse(_xController.text);
                if (v != null) widget.onChanged(v.clamp(25, widget.cap));
                _xEditing = false;
              },
            ),
          ),
          const SizedBox(width: 2),
          Text('/', style: AppTokens.body.copyWith(color: yColor, fontSize: 12)),
          Text('${widget.cap}', style: AppTokens.body.copyWith(color: yColor, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Lock icon ──────────────────────────────────────────
  Widget _buildLockIcon() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
      onTap: widget.onToggleLock,
      child: Container(
        width: 20, height: 28,
        decoration: BoxDecoration(
          color: widget.isLocked ? AppTokens.primary.withValues(alpha: 0.15) : AppTokens.surface,
          border: Border.all(color: widget.isLocked ? AppTokens.primary.withValues(alpha: 0.5) : AppTokens.keyOff.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Icon(widget.isLocked ? Icons.lock : Icons.lock_open, size: 14, color: widget.isLocked ? AppTokens.primary : AppTokens.keyOff.withValues(alpha: 0.5)),
      ),
    ),
    );
  }

  Widget _buildBadgeList(BuildContext context) {
    final loader = DatasetLoader();
    final state = context.read<BuilderState>();
    final badges = loader.badgeDefinitions.where((b) {
      final reqs = loader.tierRequirements.where((r) => r.badgeId == b.badgeId);
      for (final req in reqs) {
        for (final r in req.requirements) {
          if (r.attributeIndex == widget.attribute.index) return true;
        }
      }
      return false;
    }).toList();

    if (badges.isEmpty) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('No related badges', style: AppTokens.caption.copyWith(fontSize: 10)));
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppTokens.surfaceAlt, border: Border.all(color: AppTokens.cardBorder.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(AppTokens.radius)),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: badges.map((badge) {
          final status = state.getBadgeStatuses().firstWhere((s) => s.badge.badgeId == badge.badgeId, orElse: () => BadgeStatus(badge: badge, heightEligible: false));
          final tierColours = AppTokens.badgeTierColours;
          final isEquipped = status.isEquipped;
          final borderWidth = isEquipped ? 3.0 : 1.0;
          Color borderColor;
          if (isEquipped) {
            final equippedTier = state.equippedBadges[badge.badgeId];
            borderColor = equippedTier != null ? Color(int.parse(tierColours[equippedTier.key]!.value.toRadixString(16).padLeft(8, '0'), radix: 16)) : AppTokens.primary;
          } else if (status.isUnlocked) {
            borderColor = AppTokens.textSecondary.withValues(alpha: 0.5);
          } else {
            borderColor = AppTokens.keyOff.withValues(alpha: 0.3);
          }
          final blockColor = status.highestTier != null ? Color(int.parse(tierColours[status.highestTier!.key]!.value.toRadixString(16).padLeft(8, '0'), radix: 16)) : Colors.transparent;

          return GestureDetector(
            onTap: () => _showBadgeDetails(context, badge, status),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: status.isUnlocked ? AppTokens.surface : AppTokens.surface.withValues(alpha: 0.5), border: Border.all(color: borderColor, width: borderWidth), borderRadius: BorderRadius.circular(AppTokens.radius)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(badge.displayName, style: AppTokens.caption.copyWith(color: status.isUnlocked ? AppTokens.textPrimary : AppTokens.keyOff, fontSize: 10)),
                const SizedBox(width: 4),
                Container(width: 8, height: 8, color: blockColor),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCapBreakers(BuildContext context) {
    final loader = DatasetLoader();
    final state = context.read<BuilderState>();
    final rating = widget.value;
    final cap = widget.cap;
    final headroom = cap - rating;
    if (headroom <= 0) return const SizedBox.shrink();

    final gains = state.getCapBreakerSequence(widget.attribute.index);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppTokens.surfaceAlt, border: Border.all(color: AppTokens.cardBorder.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(AppTokens.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Cap Breakers', style: AppTokens.caption.copyWith(fontSize: 10, color: AppTokens.textSecondary)),
            const Spacer(),
            Builder(builder: (ctx) {
              try {
                final allGains = ctx.read<BuilderState>().getCapBreakerSequence(widget.attribute.index);
                final totalAllGains = allGains.fold<int>(0, (sum, g) => sum + g);
                final fullMax = widget.cap + totalAllGains;
                return Text('Max $fullMax', style: AppTokens.caption.copyWith(fontSize: 10, color: AppTokens.primary, fontWeight: FontWeight.w600));
              } catch (_) {
                return Text('Max ${widget.cap + gains.fold<int>(0, (sum, g) => sum + g)}', style: AppTokens.caption.copyWith(fontSize: 10, color: AppTokens.primary, fontWeight: FontWeight.w600));
              }
            }),
          ]),
          const SizedBox(height: 6),
          Row(children: List.generate(5, (index) {
            final isAvailable = index < gains.length;
            final gain = isAvailable ? gains[index] : null;
            final totalGain = _calculateTotalGain(gains, index);
            final isUsable = gain != null && (rating + totalGain) <= cap;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                height: 24,
                decoration: BoxDecoration(
                  color: isUsable ? AppTokens.primary.withValues(alpha: 0.2) : AppTokens.surface,
                  border: Border.all(color: isUsable ? AppTokens.primary : AppTokens.keyOff.withValues(alpha: 0.3), width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Center(child: isUsable && gain != null ? Text('+$gain', style: AppTokens.caption.copyWith(fontSize: 10, color: AppTokens.primary, fontWeight: FontWeight.w600)) : Icon(Icons.lock, size: 12, color: AppTokens.keyOff)),
              ),
            );
          })),
        ],
      ),
    );
  }

  int _calculateTotalGain(List<int> gains, int upToIndex) {
    int total = 0;
    for (int i = 0; i <= upToIndex && i < gains.length; i++) {
      total += gains[i];
    }
    return total;
  }

  void _showBadgeDetails(BuildContext context, BadgeDef badge, BadgeStatus status) {
    final loader = DatasetLoader();
    final state = context.read<BuilderState>();
    final tierColours = AppTokens.badgeTierColours;
    final remaining = state.getTokensRemaining();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentEquipped = state.equippedBadges[badge.badgeId];
            return Dialog(
              backgroundColor: AppTokens.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius), side: BorderSide(color: AppTokens.primary.withValues(alpha: 0.4))),
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85, maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(children: [
                      Icon(currentEquipped != null ? Icons.check_circle : Icons.lock_open, size: 18, color: currentEquipped != null ? AppTokens.primary : AppTokens.keyOff),
                      const SizedBox(width: 6),
                      Expanded(child: Text(badge.displayName, style: AppTokens.cardTitleStyle)),
                    ]),
                    const SizedBox(height: 8),
                    _buildHeightRequirement(context, badge, state),
                    const SizedBox(height: 16),
                    Text('Tap tier to equip/unequip', style: AppTokens.caption),
                    const SizedBox(height: 8),
                    ...[BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold, BadgeTier.hallOfFame].map((tier) {
                      final reqs = loader.tierRequirements.where((r) => r.badgeId == badge.badgeId && r.tier == tier);
                      final tierColour = Color(int.parse(tierColours[tier.key]!.value.toRadixString(16).padLeft(8, '0'), radix: 16));
                      final tokenCost = loader.getBadgeTokenCost(badge.badgeId, tier, state.heightInches);
                      final canAfford = tokenCost <= remaining[badge.discipline.index];
                      final meetsReqs = _meetsRequirements(reqs, state);
                      final meetsHeight = status.heightEligible;
                      final isCurrentTier = currentEquipped == tier;
                      final canEquip = meetsReqs && canAfford && meetsHeight;

                      return GestureDetector(
                        onTap: canEquip ? () {
                          if (isCurrentTier) { state.equipBadge(badge.badgeId, null); } else { state.equipBadge(badge.badgeId, tier); }
                          setDialogState(() {});
                        } : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrentTier ? AppTokens.surfaceAlt : AppTokens.surface,
                            border: Border.all(color: isCurrentTier ? tierColour : (canEquip ? AppTokens.cardBorder : AppTokens.keyOff.withValues(alpha: 0.3)), width: isCurrentTier ? 3 : 1),
                            borderRadius: BorderRadius.circular(AppTokens.radius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: tierColour.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)), child: Text(tier.key.toUpperCase(), style: AppTokens.caption.copyWith(color: tierColour, fontWeight: FontWeight.w600))),
                                const Spacer(),
                                if (tokenCost > 0) Text('$tokenCost tokens', style: AppTokens.caption.copyWith(color: canAfford ? AppTokens.primary : Colors.red)),
                              ]),
                              const SizedBox(height: 8),
                              if (!meetsHeight) Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Icon(Icons.close, size: 12, color: Colors.red), const SizedBox(width: 4), Text('Height not eligible', style: AppTokens.caption.copyWith(fontSize: 11, color: Colors.red))])),
                              ...reqs.expand((req) => req.requirements.map((r) {
                                final attrName = loader.attributes[r.attributeIndex].displayName;
                                final currentVal = state.ratings[r.attributeIndex];
                                final meets = currentVal >= r.minimum;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(children: [
                                    Icon(meets ? Icons.check : Icons.close, size: 12, color: meets ? Colors.green : Colors.red),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text('$attrName: ${r.minimum}', style: AppTokens.caption.copyWith(fontSize: 11))),
                                    Text('($currentVal)', style: AppTokens.caption.copyWith(fontSize: 10, color: meets ? Colors.green : AppTokens.keyOff)),
                                  ]),
                                );
                              })),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeightRequirement(BuildContext context, BadgeDef badge, BuilderState state) {
    final minHeight = badge.minHeight;
    final maxHeight = badge.maxHeight;
    final currentHeight = state.heightInches;
    final meetsHeight = currentHeight >= minHeight && currentHeight <= maxHeight;
    String formatHeight(int inches) { final feet = inches ~/ 12; final inc = inches % 12; return "$feet'$inc\""; }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppTokens.surfaceAlt, border: Border.all(color: AppTokens.cardBorder.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(AppTokens.radius)),
      child: Row(children: [
        Icon(meetsHeight ? Icons.check_circle : Icons.cancel, size: 16, color: meetsHeight ? Colors.green : Colors.red),
        const SizedBox(width: 6),
        Expanded(child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Height: ', style: AppTokens.caption.copyWith(fontSize: 11)),
          TextSpan(text: '${formatHeight(minHeight)} - ${formatHeight(maxHeight)}', style: AppTokens.caption.copyWith(fontSize: 11, color: meetsHeight ? AppTokens.textPrimary : AppTokens.keyOff)),
        ]))),
        Text('(Now: ${formatHeight(currentHeight)})', style: AppTokens.caption.copyWith(fontSize: 10, color: meetsHeight ? Colors.green : Colors.red)),
      ]),
    );
  }

  bool _meetsRequirements(Iterable<BadgeTierRequirement> reqs, BuilderState state) {
    for (final req in reqs) {
      for (final r in req.requirements) {
        if (state.ratings[r.attributeIndex] < r.minimum) return false;
      }
    }
    return true;
  }
}
