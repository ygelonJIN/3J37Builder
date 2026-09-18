import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../data/models/enums.dart';
import '../data/models/badge_data.dart';
import '../data/services/builder_state_v3.dart';
import '../theme/app_tokens.dart';
import '../extensions/context_extensions.dart';

class ShareBuildCard extends StatelessWidget {
  final String? buildName;
  final BuilderStateV3 state;
  final GlobalKey repaintKey;
  final double textScaleFactor;

  const ShareBuildCard({
    this.buildName,
    super.key,
    required this.state,
    required this.repaintKey,
    this.textScaleFactor = 1.0,
  });

  /// Get platform-specific text scale factor
  static double getPlatformTextScaleFactor() {
    if (kIsWeb) return 1.3;
    if (Platform.isAndroid) return 1.35;
    return 1.3; // iOS and others
  }

  static Future<Uint8List?> capture(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('ShareBuildCard capture error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 1080,
        height: 1920,
        color: const Color(0xFF0E0D10),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                'assets/images/share_bg.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: const Color(0xFF0E0D10));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 48, 56, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (buildName != null && buildName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: Text(
                          buildName!,
                          style: TextStyle(
                            fontFamily: AppTokens.fontFamily,
                            fontSize: 24 * textScaleFactor,
                            fontWeight: FontWeight.w900,
                            color: AppTokens.primary,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  _buildTopRow(context),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: Discipline.values.map((d) => _buildDisciplineSection(context, d)).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Row ───────────────────────────────────────────────

  Widget _buildTopRow(BuildContext context) {
    final hFeet = state.heightInches ~/ 12;
    final hInc = state.heightInches % 12;
    final hCm = (state.heightInches * 2.54).round();
    final wKg = (state.weightLb * 0.453592).round();
    final wsFeet = state.wingspanInches ~/ 12;
    final wsInc = state.wingspanInches % 12;
    final wsCm = (state.wingspanInches * 2.54).round();

    // Single row: POS | HT | WT | WS — full width
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTokens.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTokens.primary.withValues(alpha: 0.3), width: 2.5),
        boxShadow: [
          BoxShadow(color: AppTokens.primary.withValues(alpha: 0.06), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _infoCellCompact(context.tr('share_pos'), state.position.label, sub: ''),
          _infoCellSep(),
          _infoCellCompact(context.tr('share_ht'), '${hCm}cm', sub: "$hFeet'$hInc\""),
          _infoCellSep(),
          _infoCellCompact(context.tr('share_wt'), '${wKg}kg', sub: '${state.weightLb}lb'),
          _infoCellSep(),
          _infoCellCompact(context.tr('share_ws'), '${wsCm}cm', sub: "$wsFeet'$wsInc\""),
        ],
      ),
    );
  }

  // ── Info Cell (compact, for single-row body info) ─────────

  Widget _infoCellCompact(String label, String value, {String? sub}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 13 * textScaleFactor,
          fontWeight: FontWeight.w700, color: AppTokens.textSecondary,
          letterSpacing: 2,
        )),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 20 * textScaleFactor,
          fontWeight: FontWeight.w900, color: AppTokens.textPrimary,
        )),
        if (sub != null) ...[
          const SizedBox(height: 1),
          Text(sub, style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 13 * textScaleFactor,
            fontWeight: FontWeight.w500, color: AppTokens.textSecondary,
          )),
        ],
      ],
    );
  }

  Widget _infoCellSep() {
    return Container(
      width: 1, height: 40,
      color: AppTokens.primary.withValues(alpha: 0.12),
    );
  }



  static const List<List<int>> _disciplineAttrIndices = [
    [0, 1, 2, 3, 4],
    [5, 6, 7],
    [8, 9, 10],
    [11, 12, 13, 14],
    [15, 16],
    [17, 18, 19, 20],
  ];

  static const List<String> _attrKeys = [
    'close_shot', 'driving_layup', 'driving_dunk', 'standing_dunk', 'post_control',
    'mid_range', 'three_point', 'free_throw',
    'pass_accuracy', 'ball_handle', 'speed_with_ball',
    'interior_defense', 'perimeter_defense', 'steal', 'block',
    'offensive_rebound', 'defensive_rebound',
    'speed', 'agility', 'strength', 'vertical',
  ];



  Widget _buildAttributeRow(BuildContext context, List<int> indices, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Expanded(child: _buildAttributeItem(context, indices[0], color)),
        const SizedBox(width: 14),
        Expanded(child: indices.length > 1 ? _buildAttributeItem(context, indices[1], color) : const SizedBox()),
      ]),
    );
  }

  Widget _buildAttributeItem(BuildContext context, int attrIndex, Color color) {
    final attrState = state.getAttributeState(attrIndex);
    final name = context.tr(_attrKeys[attrIndex]);
    final hasCB = attrState.hasCapBreakers;
    final cbGain = attrState.capBreakerGain;

    // Build cap breaker breakdown string (always expanded, e.g. "+2+2+2+2+2")
    String cbBreakdown = '';
    if (hasCB) {
      final gains = state.getAppliedCapBreakerGains(attrIndex);
      if (gains.isNotEmpty) {
        cbBreakdown = gains.map((g) => '+$g').join('');
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTokens.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
        border: Border(left: BorderSide(color: color.withValues(alpha: 0.15), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name, style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 14 * textScaleFactor,
            fontWeight: FontWeight.w400, color: AppTokens.textSecondary,
          ), overflow: TextOverflow.ellipsis)),
          if (hasCB && cbGain > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$cbBreakdown/', style: TextStyle(
                fontFamily: AppTokens.fontFamily, fontSize: 10 * textScaleFactor,
                fontWeight: FontWeight.w600, color: AppTokens.primary.withValues(alpha: 0.45),
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTokens.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: AppTokens.primary.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Text('+$cbGain', style: TextStyle(
                  fontFamily: AppTokens.fontFamily, fontSize: 10 * textScaleFactor,
                  fontWeight: FontWeight.w800, color: AppTokens.primary,
                )),
              ),
            ]),
          if (hasCB && cbGain == 0)
            Text(cbBreakdown, style: TextStyle(
              fontFamily: AppTokens.fontFamily, fontSize: 10 * textScaleFactor,
              fontWeight: FontWeight.w600, color: AppTokens.primary.withValues(alpha: 0.45),
            )),
          const SizedBox(width: 4),
          Text('${attrState.finalValue}', style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 18 * textScaleFactor,
            fontWeight: FontWeight.w800,
            color: hasCB ? AppTokens.primary : AppTokens.textPrimary,
          )),
          Text('/${attrState.baseCap}', style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 13 * textScaleFactor,
            fontWeight: FontWeight.w400, color: AppTokens.keyOff,
          )),
        ],
      ),
    );
  }

  // ── Merged Discipline Section (header + attributes + badges) ──

  Widget _buildDisciplineSection(BuildContext context, Discipline discipline) {
    final color = AppTokens.disciplineColours[discipline.name] ?? AppTokens.textSecondary;
    final discIdx = Discipline.values.indexOf(discipline);
    final tokens = state.getTokenBudget();
    final slotsRemaining = state.getSlotsRemaining();
    final slots = state.getSlotBudget();
    final badges = _getBadgesForDiscipline(discipline);
    final attrIndices = _disciplineAttrIndices[discIdx];

    // Build attribute rows
    final rows = <List<int>>[];
    for (var i = 0; i < attrIndices.length; i += 2) {
      rows.add(i + 1 < attrIndices.length
          ? [attrIndices[i], attrIndices[i + 1]]
          : [attrIndices[i]]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Discipline name + Tokens + Slots ──
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              Container(width: 4, height: 16, color: color),
              const SizedBox(width: 8),
              Text(context.tr(discipline.name).toUpperCase(), style: TextStyle(
                fontFamily: AppTokens.fontFamily, fontSize: 17 * textScaleFactor,
                fontWeight: FontWeight.w800, color: color, letterSpacing: 2.5,
              )),
              Container(
                width: 1, height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: AppTokens.primary.withValues(alpha: 0.15),
              ),
              Text('${context.tr("tokens")} ${tokens[discIdx]}', style: TextStyle(
                fontFamily: AppTokens.fontFamily, fontSize: 14 * textScaleFactor,
                fontWeight: FontWeight.w500, color: AppTokens.textSecondary,
              )),
              Container(
                width: 1, height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppTokens.primary.withValues(alpha: 0.1),
              ),
              Text('${context.tr("slots")} ${slotsRemaining[discIdx]}/${slots[discIdx]}', style: TextStyle(
                fontFamily: AppTokens.fontFamily, fontSize: 14 * textScaleFactor,
                fontWeight: FontWeight.w500, color: AppTokens.textSecondary,
              )),
            ]),
          ),

          // ── Attributes ──
          ...rows.map((row) => _buildAttributeRow(context, row, color)),

          // ── Badges ──
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 5, runSpacing: 5,
              children: badges.map((b) => _buildBadgeChip(b, context)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadgeChip(BadgeDef badge, BuildContext context) {
    final equippedTier = state.equippedBadges[badge.badgeId];
    final isEquipped = equippedTier != null;
    final tierColor = isEquipped
        ? AppTokens.badgeTierColours[equippedTier.key] ?? AppTokens.keyOff
        : AppTokens.keyOff;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEquipped ? tierColor.withValues(alpha: 0.12) : AppTokens.surface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: tierColor.withValues(alpha: isEquipped ? 0.5 : 0.08),
          width: isEquipped ? 1.2 : 0.8,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isEquipped) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(
            shape: BoxShape.circle, color: tierColor,
            boxShadow: [BoxShadow(color: tierColor.withValues(alpha: 0.5), blurRadius: 3)],
          )),
          const SizedBox(width: 5),
        ],
        Text(context.tr(badge.name), style: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: (isEquipped ? 15 : 13) * textScaleFactor,
          fontWeight: isEquipped ? FontWeight.w600 : FontWeight.w300,
          color: isEquipped ? tierColor : AppTokens.keyOff,
        )),
      ]),
    );
  }

  List<BadgeDef> _getBadgesForDiscipline(Discipline discipline) {
    return state.loader.badgeDefinitions.where((b) => b.discipline == discipline && b.allowed).toList();
  }
}

// ── Background Painter (no corner diamonds) ─────────────────


