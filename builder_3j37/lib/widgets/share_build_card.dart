import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../data/models/enums.dart';
import '../data/models/badge_data.dart';
import '../data/services/builder_state_v3.dart';
import '../theme/app_tokens.dart';

class ShareBuildCard extends StatelessWidget {
  final BuilderStateV3 state;
  final GlobalKey repaintKey;

  const ShareBuildCard({
    super.key,
    required this.state,
    required this.repaintKey,
  });

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
            Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 48, 56, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopRow(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAttributes(),
                          const SizedBox(height: 20),
                          _buildBadgesSection(),
                        ],
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

  Widget _buildTopRow() {
    final hFeet = state.heightInches ~/ 12;
    final hInc = state.heightInches % 12;
    final hCm = (state.heightInches * 2.54).round();
    final wKg = (state.weightLb * 0.453592).round();
    final wsFeet = state.wingspanInches ~/ 12;
    final wsInc = state.wingspanInches % 12;
    final wsCm = (state.wingspanInches * 2.54).round();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: Title (no decorative lines) ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppTokens.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTokens.primary.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('3J37', style: TextStyle(
                fontFamily: AppTokens.fontFamily, fontSize: 50,
                fontWeight: FontWeight.w900, color: AppTokens.primary,
                letterSpacing: 8,
                shadows: [
                  Shadow(color: AppTokens.primary.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 3)),
                  Shadow(color: AppTokens.primary.withValues(alpha: 0.2), blurRadius: 40),
                ],
              )),
              const SizedBox(height: 2),
              Text('Builder', style: TextStyle(
                fontFamily: AppTokens.fontFamily, fontSize: 30,
                fontWeight: FontWeight.w500, color: AppTokens.textSecondary,
                letterSpacing: 6,
              )),
            ],
          ),
        ),

        const Spacer(),

        // ── Right: Body Info (wider border) ──
        Container(
          padding: const EdgeInsets.only(left: 0, right: 80, top: 16, bottom: 16),
          decoration: BoxDecoration(
            color: AppTokens.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTokens.primary.withValues(alpha: 0.3), width: 2.5),
            boxShadow: [
              BoxShadow(color: AppTokens.primary.withValues(alpha: 0.06), blurRadius: 12),
            ],
          ),
          child: Column(
            children: [
              _buildInfoRow(
                label1: 'POS',
                bigValue1: state.position.label,
                label2: 'HT',
                bigValue2: '${hCm}cm',
                smallValue2: "$hFeet'$hInc\"",
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(height: 1, width: 500, color: AppTokens.primary.withValues(alpha: 0.12)),
              ),
              _buildInfoRow(
                label1: 'WT',
                bigValue1: '${wKg}kg',
                smallValue1: '${state.weightLb}lb',
                label2: 'WS',
                bigValue2: '${wsCm}cm',
                smallValue2: "$wsFeet'$wsInc\"",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label1, String? value1, String? bigValue1, String? smallValue1,
    required String label2, String? value2, String? bigValue2, String? smallValue2,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _infoCell(label1, value1: value1, bigValue: bigValue1, smallValue: smallValue1),
        Container(
          width: 1, height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: AppTokens.primary.withValues(alpha: 0.15),
        ),
        _infoCell(label2, value2: value2, bigValue: bigValue2, smallValue: smallValue2),
      ],
    );
  }

  Widget _infoCell(String label, {String? value2, String? value1, String? bigValue, String? smallValue}) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 13,
            fontWeight: FontWeight.w800, color: AppTokens.keyOff, letterSpacing: 2,
          )),
          const SizedBox(width: 50),
          if (value1 != null)
            Text(value1, style: TextStyle(
              fontFamily: AppTokens.fontFamily, fontSize: 24,
              fontWeight: FontWeight.w900, color: AppTokens.textPrimary,
            ))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bigValue ?? '', style: TextStyle(
                  fontFamily: AppTokens.fontFamily, fontSize: 24,
                  fontWeight: FontWeight.w900, color: AppTokens.primary,
                )),
                Text(smallValue ?? '', style: TextStyle(
                  fontFamily: AppTokens.fontFamily, fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppTokens.textSecondary,
                )),
              ],
            ),
        ],
      ),
    );
  }

  // ── Attributes (no section title) ─────────────────────────

  static const List<List<int>> _disciplineAttrIndices = [
    [0, 1, 2, 3, 4],
    [5, 6, 7],
    [8, 9, 10],
    [11, 12, 13, 14],
    [15, 16],
    [17, 18, 19, 20],
  ];

  static const List<String> _fullAttrNames = [
    'Close Shot', 'Driving Layup', 'Driving Dunk', 'Standing Dunk', 'Post Control',
    'Mid-Range', 'Three-Point', 'Free Throw',
    'Pass Accuracy', 'Ball Handle', 'Speed w/Ball',
    'Interior Defense', 'Perimeter Defense', 'Steal', 'Block',
    'Offensive Rebound', 'Defensive Rebound',
    'Speed', 'Agility', 'Strength', 'Vertical',
  ];

  Widget _buildAttributes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(6, (i) => _buildDisciplineGroup(
        Discipline.values[i],
        _disciplineAttrIndices[i],
      )),
    );
  }

  Widget _buildDisciplineGroup(Discipline discipline, List<int> attrIndices) {
    final color = AppTokens.disciplineColours[discipline.name] ?? AppTokens.textSecondary;
    final rows = <List<int>>[];
    for (var i = 0; i < attrIndices.length; i += 2) {
      rows.add(i + 1 < attrIndices.length
          ? [attrIndices[i], attrIndices[i + 1]]
          : [attrIndices[i]]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              Container(width: 4, height: 16, color: color),
              const SizedBox(width: 8),
              Text(discipline.displayName.toUpperCase(), style: TextStyle(
                fontFamily: AppTokens.fontFamily, fontSize: 17,
                fontWeight: FontWeight.w800, color: color, letterSpacing: 2.5,
              )),
            ]),
          ),
          ...rows.map((row) => _buildAttributeRow(row, color)),
        ],
      ),
    );
  }

  Widget _buildAttributeRow(List<int> indices, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Expanded(child: _buildAttributeItem(indices[0], color)),
        const SizedBox(width: 14),
        Expanded(child: indices.length > 1 ? _buildAttributeItem(indices[1], color) : const SizedBox()),
      ]),
    );
  }

  Widget _buildAttributeItem(int attrIndex, Color color) {
    final attrState = state.getAttributeState(attrIndex);
    final name = _fullAttrNames[attrIndex];
    final cbGain = attrState.capBreakerGain;
    final isMaxed = attrState.finalValue >= attrState.baseCap;

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
            fontFamily: AppTokens.fontFamily, fontSize: 14,
            fontWeight: FontWeight.w800, color: AppTokens.textSecondary,
          ), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          Text('${attrState.finalValue}', style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isMaxed ? AppTokens.primary : AppTokens.textPrimary,
          )),
          Text('/${attrState.baseCap}', style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 13,
            fontWeight: FontWeight.w800, color: AppTokens.keyOff,
          )),
          if (cbGain > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTokens.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: AppTokens.primary.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text('+$cbGain', style: TextStyle(
                fontFamily: AppTokens.fontFamily, fontSize: 12,
                fontWeight: FontWeight.w800, color: AppTokens.primary,
              )),
            ),
          ],
        ],
      ),
    );
  }

  // ── Badges Section (no section title, +1px fonts) ─────────

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: Discipline.values.map((d) => _buildBadgeDisciplineRow(d)).toList(),
    );
  }

  Widget _buildBadgeDisciplineRow(Discipline discipline) {
    final color = AppTokens.disciplineColours[discipline.name] ?? AppTokens.textSecondary;
    final badges = _getBadgesForDiscipline(discipline);
    if (badges.isEmpty) return const SizedBox();

    final discIdx = Discipline.values.indexOf(discipline);
    final tokens = state.getTokenBudget();
    final slots = state.getSlotBudget();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 14, color: color),
            const SizedBox(width: 7),
            Text(discipline.displayName.toUpperCase(), style: TextStyle(
              fontFamily: AppTokens.fontFamily, fontSize: 16,
              fontWeight: FontWeight.w900, color: color, letterSpacing: 2,
            )),
            Container(
              width: 1, height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppTokens.primary.withValues(alpha: 0.15),
            ),
            Text('Tokens ${tokens[discIdx]}', style: TextStyle(
              fontFamily: AppTokens.fontFamily, fontSize: 14,
              fontWeight: FontWeight.w700, color: AppTokens.textSecondary,
            )),
            Container(
              width: 1, height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: AppTokens.primary.withValues(alpha: 0.1),
            ),
            Text('Slots ${slots[discIdx]}', style: TextStyle(
              fontFamily: AppTokens.fontFamily, fontSize: 14,
              fontWeight: FontWeight.w700, color: AppTokens.textSecondary,
            )),
          ]),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5, runSpacing: 5,
            children: badges.map((b) => _buildBadgeChip(b)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(BadgeDef badge) {
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
        Text(badge.displayName, style: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: isEquipped ? 15 : 13,
          fontWeight: isEquipped ? FontWeight.w800 : FontWeight.w500,
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

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridPaint = Paint()
      ..color = AppTokens.primary.withValues(alpha: 0.018)
      ..strokeWidth = 0.8;
    for (double x = 0; x < size.width; x += 54) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 54) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Side lines
    final sidePaint = Paint()
      ..color = AppTokens.primary.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(28, 0), Offset(28, size.height), sidePaint);
    canvas.drawLine(Offset(size.width - 28, 0), Offset(size.width - 28, size.height), sidePaint);

    // Top/Bottom border
    final borderPaint = Paint()
      ..color = AppTokens.primary.withValues(alpha: 0.15)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, 4), Offset(size.width, 4), borderPaint);
    canvas.drawLine(Offset(0, size.height - 4), Offset(size.width, size.height - 4), borderPaint);

    // Horizontal accent bands
    final bandPaint = Paint()..color = AppTokens.primary.withValues(alpha: 0.015);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.12, size.width, 50), bandPaint);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.88, size.width, 35), bandPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
