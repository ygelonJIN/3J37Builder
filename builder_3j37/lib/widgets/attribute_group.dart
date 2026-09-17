import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../data/models/enums.dart';
import '../data/models/attribute.dart';
import '../data/models/badge_data.dart';
import '../data/services/dataset_loader.dart';
import '../data/services/cap_breaker_engine.dart';
import '../data/services/builder_state_v3.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';
import 'plus_minus_control.dart';
import 'center_dialog.dart';



class AttributeGroups extends StatelessWidget {
  const AttributeGroups({super.key});

  @override
  Widget build(BuildContext context) {
    final loader = DatasetLoader();
    final state = context.watch<BuilderStateV3>();
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
          final slotBudget = state.getSlotBudget();
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
                    Text('$tokenRemaining/$tokenBudget Tokens ${slotBudget[disc.index]} Slots', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: colour)),
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
                  validateChanged: (v) => state.validateRatingChange(attr.index, v),
                  isOvrMax: isOvrMax,
                  isLocked: state.isAttributeLocked(attr.index),
                  onToggleLock: () => state.toggleAttributeLock(attr.index),
                  canAdjust: state.canAdjustAttribute(attr.index),
                  isGoalActive: state.isGoalActive(attr.index),
                  goalValue: state.getGoalRating(attr.index),
                  onRemoveCapBreaker: () => state.removeCapBreaker(attr.index),
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
  final String? Function(int)? validateChanged;
  final bool isOvrMax;
  final bool isLocked;
  final VoidCallback onToggleLock;
  final bool canAdjust;
  final bool isGoalActive;
  final int? goalValue;
  final VoidCallback? onRemoveCapBreaker;

  const _AttributeControl({
    required this.attribute,
    required this.value,
    required this.cap,
    required this.colour,
    required this.onChanged,
    this.validateChanged,
    this.isOvrMax = false,
    required this.isLocked,
    required this.onToggleLock,
    required this.canAdjust,
    this.isGoalActive = false,
    this.goalValue,
    this.onRemoveCapBreaker,
  });

  @override
  State<_AttributeControl> createState() => _AttributeControlState();
}

class _AttributeControlState extends State<_AttributeControl> {
  bool _hasError = false;
  String _errorMessage = '';
  bool _expanded = false;
  bool _xEditing = false;
  late TextEditingController _xController;
  final FocusNode _xFocus = FocusNode();
  Timer? _errorTimer;
  bool _suppressExpand = false;

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
      if (_hasError) {
        _errorTimer?.cancel();
        setState(() {
          _hasError = false;
          _errorMessage = '';
        });
      }
    }
  }


  void _onXFocusChange() {
    if (!_xFocus.hasFocus && _xEditing) {
      _suppressExpand = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _suppressExpand = false;
      });
      final state = context.read<BuilderStateV3>();
      final appliedGain = state.getCapBreakerGainForAttr(widget.attribute.index);
      final displayValue = widget.value;

      final v = int.tryParse(_xController.text);
      final clampedDisplay = (widget.value).clamp(25, widget.cap);
      if (v != null) {
        if (widget.isLocked) {
          _showError('${widget.attribute.displayName}已锁定');
          _xController.text = '$clampedDisplay';
        } else if (v > widget.cap) {
          _showError('Max ${widget.cap}');
        } else {
          final baseValue = v - appliedGain;
          final error = widget.validateChanged?.call(baseValue.clamp(25, widget.cap));
          if (error != null) {
            _showError(error);
          } else {
            setState(() {
              _hasError = false;
              _errorMessage = '';
            });
            widget.onChanged(baseValue.clamp(25, widget.cap));
          }
        }
      } else {
        _xController.text = '${widget.value.clamp(25, widget.cap)}';
      }
      _xEditing = false;
    }
  }

  void _showError(String message) {
    _errorTimer?.cancel();
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
    _errorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        final state = context.read<BuilderStateV3>();
        final appliedGain = state.getCapBreakerGainForAttr(widget.attribute.index);
        final clampedDisplay = (widget.value).clamp(25, widget.cap);
        setState(() {
          _hasError = false;
          _errorMessage = '';
        });
        _xController.text = '$clampedDisplay';
      }
    });
  }



  @override
  void dispose() {
    _errorTimer?.cancel();
    _xController.dispose();
    _xFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<BuilderStateV3>();
    final appliedGain = state.getCapBreakerGainForAttr(widget.attribute.index);
    final displayValue = widget.value;
    
    // Update controller text if not editing (clamped to physical cap)
    if (!_xEditing) {
      _xController.text = '${widget.value.clamp(25, widget.cap)}';
    }
    
    final atCap = widget.value >= widget.cap;
    final bool isMaxed = widget.isOvrMax || atCap;
    // Make X value brighter when cap breakers are applied
    final Color xColor;
    if (widget.isLocked) {
      xColor = AppTokens.keyOff;
    } else if (appliedGain > 0) {
      // Brighter color for cap-broken values
      xColor = AppTokens.primary;
    } else {
      xColor = widget.colour;
    }
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
                  if (_suppressExpand) {
                    _suppressExpand = false;
                    FocusScope.of(context).unfocus();
                  } else {
                    setState(() => _expanded = !_expanded);
                  }
                },
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(widget.attribute.displayName, style: AppTokens.caption.copyWith(color: (isMaxed && appliedGain == 0) ? AppTokens.keyOff : AppTokens.textPrimary, fontSize: 11))),
                      Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: AppTokens.textSecondary),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_hasError)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    _errorMessage,
                    style: AppTokens.caption.copyWith(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                )
              else if (widget.isGoalActive) ...[
                // GOAL: show like error message style - gold color, no plus/minus, no X/Y
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GOAL',
                        style: TextStyle(
                          fontFamily: AppTokens.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.primary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.goalValue ?? widget.value}${appliedGain > 0 ? '+$appliedGain' : ''}',
                        style: TextStyle(
                          fontFamily: AppTokens.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ]
              else ...[
                PlusMinusControl(
                  value: widget.value,
                  min: 25,
                  max: widget.cap,
                  onChanged: widget.canAdjust ? (v) {
                    // With cap breakers: block decrease and prompt to remove them
                    // Covers: at cap (value==cap) or at floor (base==25)
                    final baseVal = widget.value - appliedGain;
                    if (v < widget.value && appliedGain > 0 &&
                        (widget.value >= widget.cap || baseVal <= 25)) {
                      _showError('Remove Cap Breaker first');
                      return;
                    }
                    final baseValue = (v - appliedGain).clamp(25, widget.cap);
                    final error = widget.validateChanged?.call(baseValue);
                    if (error == null) {
                      widget.onChanged(baseValue);
                    } else {
                      _showError(error);
                    }
                  } : null,
                  activeColor: widget.colour,
                ),
                const SizedBox(width: 4),
                _buildNormalDisplay(xColor, yColor, appliedGain),
                const SizedBox(width: 6),
                _buildLockIcon(),
              ],
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
  Widget _buildNormalDisplay(Color xColor, Color yColor, int appliedGain) {
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
              textInputAction: TextInputAction.done,
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
                setState(() { _xEditing = true; });
                if (_hasError) {
                  _errorTimer?.cancel();
                  setState(() {
                    _hasError = false;
                    _errorMessage = '';
                  });
                }
                _xController.selection = TextSelection(baseOffset: 0, extentOffset: _xController.text.length);
              },
              onSubmitted: (_) {
                final v = int.tryParse(_xController.text);
                if (v != null) {
                  if (widget.isLocked) {
                    _showError('${widget.attribute.displayName}已锁定');
                    _xController.text = '${widget.value}';
                  } else if (v > widget.cap) {
                    _showError('Max ${widget.cap}');
                  } else if (v < 25) {
                    _showError('Min 25');
                  } else {
                    final baseValue = v - appliedGain;
                    final error = widget.validateChanged?.call(baseValue.clamp(25, widget.cap));
                    if (error != null) {
                      _showError(error);
                    } else {
                      setState(() {
                        _hasError = false;
                        _errorMessage = '';
                      });
                      widget.onChanged(baseValue.clamp(25, widget.cap));
                    }
                  }
                }
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
    final state = context.read<BuilderStateV3>();
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
    final state = context.read<BuilderStateV3>();
    final rating = widget.value;
    final cap = widget.cap;
    final headroom = cap - rating;
    final appliedCount = state.getAppliedCapBreakerCount(widget.attribute.index);
    // Don't hide when there are applied cap breakers — user needs to see and remove them
    if (headroom <= 0 && appliedCount == 0) return const SizedBox.shrink();

    final gains = state.getCapBreakerSequence(widget.attribute.index, attrCap: widget.cap);
    final totalAllGains = gains.fold<int>(0, (sum, g) => sum + g);
    final maxValue = state.baseRatings[widget.attribute.index] + totalAllGains;

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
            Text('Max $maxValue', style: AppTokens.caption.copyWith(fontSize: 10, color: AppTokens.primary, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          Row(children: List.generate(5, (index) {
            final isAvailable = index < gains.length;
            final gain = isAvailable ? gains[index] : null;
            final isApplied = index < appliedCount;
            final isNext = index == appliedCount && gain != null;
            final canApply = gain != null;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (isApplied) {
                    // Remove this and all subsequent cap breakers
                    for (int i = appliedCount - 1; i >= index; i--) {
                      state.removeCapBreaker(widget.attribute.index);
                    }
                  } else if (gain != null && index >= appliedCount) {
                    // Apply cap breakers up to this index
                    for (int i = appliedCount; i <= index; i++) {
                      if (i < gains.length && !state.applyCapBreakerWithGain(widget.attribute.index, gains[i])) break;
                    }
                  }
                },
                child: Container(
                  margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                  height: 24,
                  decoration: BoxDecoration(
                    color: isApplied ? AppTokens.primary.withValues(alpha: 0.1) : AppTokens.surface,
                    border: Border.all(color: isApplied ? AppTokens.primary.withValues(alpha: 0.5) : AppTokens.keyOff.withValues(alpha: 0.3), width: isApplied ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Center(child: isAvailable && gain != null ? Text('+$gain', style: AppTokens.caption.copyWith(fontSize: 10, color: isApplied ? AppTokens.primary : AppTokens.textSecondary, fontWeight: isApplied ? FontWeight.w700 : FontWeight.w600)) : Icon(Icons.lock, size: 12, color: AppTokens.keyOff)),
                ),
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
    final state = context.read<BuilderStateV3>();
    final tierColours = AppTokens.badgeTierColours;
    final remaining = state.getTokensRemaining();

    CenterDialog.show(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final currentEquipped = state.equippedBadges[badge.badgeId];
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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

                  return Container(
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
                              isCurrentTier ? 'Unequip' : 'Equip',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
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
                  );
                }),
              ],
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

  bool _meetsRequirements(Iterable<BadgeTierRequirement> reqs, BuilderStateV3 state) {
    for (final req in reqs) {
      for (final r in req.requirements) {
        if (state.ratings[r.attributeIndex] < r.minimum) return false;
      }
    }
    return true;
  }
}
