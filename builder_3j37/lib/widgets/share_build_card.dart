import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../data/models/enums.dart';
import '../data/models/badge_data.dart';
import '../data/services/builder_state_v3.dart';
import '../theme/app_tokens.dart';

/// Generates a shareable build card image (1080x1920, 9:16)
/// All dimensions are 3x the app UI for high-res output
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
            // Background effects
            Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(60, 80, 60, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildBodyInfo(),
                  const SizedBox(height: 40),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAttributes(),
                          const SizedBox(height: 40),
                          _buildBadgesTokensSlots(),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          // Decorative line
          Container(width: 240, height: 2, color: AppTokens.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 20),
          // Title
          Text(
            '3J37',
            style: TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 108, // 36 * 3
              fontWeight: FontWeight.w900,
              color: AppTokens.primary,
              letterSpacing: 24,
              shadows: [
                Shadow(
                  color: AppTokens.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'BUILD CARD',
            style: TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 30, // 10 * 3
              fontWeight: FontWeight.w300,
              color: AppTokens.textSecondary,
              letterSpacing: 18,
            ),
          ),
          const SizedBox(height: 20),
          Container(width: 240, height: 2, color: AppTokens.primary.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  // ── Body Info ─────────────────────────────────────────────

  Widget _buildBodyInfo() {
    final hFeet = state.heightInches ~/ 12;
    final hInc = state.heightInches % 12;
    final hCm = (state.heightInches * 2.54).round();
    final wKg = (state.weightLb * 0.453592).round();
    final wsFeet = state.wingspanInches ~/ 12;
    final wsInc = state.wingspanInches % 12;
    final wsCm = (state.wingspanInches * 2.54).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      decoration: BoxDecoration(
        color: AppTokens.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTokens.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          // Position + OVR row
          Row(
            children: [
              _infoChip('POSITION', state.position.label, AppTokens.primary, large: true),
              const Spacer(),
              _infoChip('OVR', '${state.overallRating}', AppTokens.primary, large: true),
            ],
          ),
          const SizedBox(height: 20),
          // Body measurements row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoChip('HEIGHT', "$hFeet'$hInc\"", AppTokens.textPrimary),
              _infoChip('WEIGHT', '${state.weightLb}lb', AppTokens.textPrimary),
              _infoChip('WING', "$wsFeet'$wsInc\"", AppTokens.textPrimary),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoChip('', '${hCm}cm', AppTokens.textSecondary),
              _infoChip('', '${wKg}kg', AppTokens.textSecondary),
              _infoChip('', '${wsCm}cm', AppTokens.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, Color valueColor, {bool large = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(label, style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 18,
            fontWeight: FontWeight.w400, color: AppTokens.textSecondary, letterSpacing: 3,
          )),
        if (label.isNotEmpty) const SizedBox(height: 6),
        Text(value, style: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: large ? 48 : 30,
          fontWeight: large ? FontWeight.w800 : FontWeight.w600,
          color: valueColor,
        )),
      ],
    );
  }

  // ── Attributes ────────────────────────────────────────────

  Widget _buildAttributes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ATTRIBUTES'),
        const SizedBox(height: 20),
        ...Discipline.values.map((d) => _buildDisciplineGroup(d)),
      ],
    );
  }

  Widget _buildDisciplineGroup(Discipline discipline) {
    final color = AppTokens.disciplineColours[discipline.name] ?? AppTokens.textSecondary;
    final attrIndices = _getAttributesForDiscipline(discipline);
    final rows = <List<int>>[];
    for (var i = 0; i < attrIndices.length; i += 2) {
      rows.add(i + 1 < attrIndices.length
          ? [attrIndices[i], attrIndices[i + 1]]
          : [attrIndices[i]]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Discipline header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: [
                Container(width: 6, height: 24, color: color),
                const SizedBox(width: 12),
                Text(discipline.displayName.toUpperCase(), style: TextStyle(
                  fontFamily: AppTokens.fontFamily, fontSize: 24,
                  fontWeight: FontWeight.w800, color: color, letterSpacing: 4,
                )),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) => _buildAttributeRow(row, color)),
        ],
      ),
    );
  }

  Widget _buildAttributeRow(List<int> indices, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(child: _buildAttributeItem(indices[0], color)),
        const SizedBox(width: 36),
        Expanded(child: indices.length > 1 ? _buildAttributeItem(indices[1], color) : const SizedBox()),
      ]),
    );
  }

  Widget _buildAttributeItem(int attrIndex, Color color) {
    final attrState = state.getAttributeState(attrIndex);
    final name = _getAttributeShortName(attrIndex);
    final cbGain = attrState.capBreakerGain;
    final isMaxed = attrState.finalValue >= attrState.baseCap;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Name
          Expanded(
            child: Text(name, style: TextStyle(
              fontFamily: AppTokens.fontFamily, fontSize: 21,
              fontWeight: FontWeight.w400, color: AppTokens.textSecondary,
            ), overflow: TextOverflow.ellipsis),
          ),
          // Value
          Text('${attrState.finalValue}', style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 27,
            fontWeight: FontWeight.w800,
            color: isMaxed ? AppTokens.primary : AppTokens.textPrimary,
          )),
          Text('/${attrState.baseCap}', style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 21,
            fontWeight: FontWeight.w400, color: AppTokens.textSecondary,
          )),
          // Cap breaker badge
          if (cbGain > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTokens.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppTokens.primary.withValues(alpha: 0.4), width: 1),
              ),
              child: Text('+$cbGain', style: TextStyle(
                fontFamily: AppTokens.fontFamily, fontSize: 18,
                fontWeight: FontWeight.w800, color: AppTokens.primary,
              )),
            ),
          ],
        ],
      ),
    );
  }

  // ── Badges, Tokens & Slots ────────────────────────────────

  Widget _buildBadgesTokensSlots() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('BADGES · TOKENS · SLOTS'),
        const SizedBox(height: 20),
        _buildBadgesGrid(),
        const SizedBox(height: 24),
        _buildTokensAndSlotsRow(),
      ],
    );
  }

  Widget _buildBadgesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: Discipline.values.map((d) => _buildBadgeDisciplineRow(d)).toList(),
    );
  }

  Widget _buildBadgeDisciplineRow(Discipline discipline) {
    final color = AppTokens.disciplineColours[discipline.name] ?? AppTokens.textSecondary;
    final badges = _getBadgesForDiscipline(discipline);
    if (badges.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 6, height: 18, color: color),
            const SizedBox(width: 10),
            Text(discipline.displayName.toUpperCase(), style: TextStyle(
              fontFamily: AppTokens.fontFamily, fontSize: 18,
              fontWeight: FontWeight.w700, color: color, letterSpacing: 3,
            )),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isEquipped ? tierColor.withValues(alpha: 0.15) : AppTokens.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: tierColor.withValues(alpha: isEquipped ? 0.6 : 0.15),
          width: isEquipped ? 1.5 : 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isEquipped) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tierColor,
              boxShadow: [BoxShadow(color: tierColor.withValues(alpha: 0.5), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(badge.displayName, style: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontSize: isEquipped ? 18 : 15,
          fontWeight: isEquipped ? FontWeight.w700 : FontWeight.w300,
          color: isEquipped ? tierColor : AppTokens.keyOff,
        )),
      ]),
    );
  }

  Widget _buildTokensAndSlotsRow() {
    final tokens = state.getTokenBudget();
    final slots = state.getSlotBudget();
    final totalTokens = tokens.reduce((a, b) => a + b);
    final discNames = ['FIN', 'SHT', 'PLY', 'DEF', 'REB', 'PHY'];
    final discColors = [
      AppTokens.disciplineColours['finishing'],
      AppTokens.disciplineColours['shooting'],
      AppTokens.disciplineColours['playmaking'],
      AppTokens.disciplineColours['defense'],
      AppTokens.disciplineColours['rebounding'],
      AppTokens.disciplineColours['physicals'],
    ];

    return Row(children: [
      // Tokens
      Expanded(child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTokens.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTokens.primary.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('TOKENS', style: TextStyle(
              fontFamily: AppTokens.fontFamily, fontSize: 21,
              fontWeight: FontWeight.w800, color: AppTokens.primary, letterSpacing: 4,
            )),
            const Spacer(),
            Text('$totalTokens', style: TextStyle(
              fontFamily: AppTokens.fontFamily, fontSize: 36,
              fontWeight: FontWeight.w900, color: AppTokens.primary,
            )),
          ]),
          const SizedBox(height: 16),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _tokenSlotItem(discNames[i * 2], tokens[i * 2], discColors[i * 2]!),
                _tokenSlotItem(discNames[i * 2 + 1], tokens[i * 2 + 1], discColors[i * 2 + 1]!),
              ],
            ),
          )),
        ]),
      )),
      const SizedBox(width: 20),
      // Slots
      Expanded(child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTokens.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTokens.primary.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SLOTS', style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 21,
            fontWeight: FontWeight.w800, color: AppTokens.primary, letterSpacing: 4,
          )),
          const SizedBox(height: 16),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _tokenSlotItem(discNames[i * 2], slots[i * 2], discColors[i * 2]!),
                _tokenSlotItem(discNames[i * 2 + 1], slots[i * 2 + 1], discColors[i * 2 + 1]!),
              ],
            ),
          )),
        ]),
      )),
    ]);
  }

  Widget _tokenSlotItem(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text('$label ', style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 18,
          fontWeight: FontWeight.w400, color: AppTokens.textSecondary,
        )),
        Text('$value', style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 24,
          fontWeight: FontWeight.w700, color: AppTokens.textPrimary,
        )),
      ],
    );
  }

  // ── Section Title ─────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Row(children: [
      Expanded(child: Container(height: 2, color: AppTokens.primary.withValues(alpha: 0.25))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppTokens.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTokens.primary.withValues(alpha: 0.3), width: 1),
          ),
          child: Text(title, style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 27,
            fontWeight: FontWeight.w800, color: AppTokens.primary, letterSpacing: 6,
          )),
        ),
      ),
      Expanded(child: Container(height: 2, color: AppTokens.primary.withValues(alpha: 0.25))),
    ]);
  }

  // ── Footer ────────────────────────────────────────────────

  Widget _buildFooter() {
    return Center(
      child: Column(children: [
        Container(width: 240, height: 1.5, color: AppTokens.primary.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text('3J37 BUILDER', style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 18,
          fontWeight: FontWeight.w300, color: AppTokens.textSecondary.withValues(alpha: 0.5), letterSpacing: 6,
        )),
      ]),
    );
  }

  // ── Data Helpers ──────────────────────────────────────────

  List<int> _getAttributesForDiscipline(Discipline discipline) {
    final indices = <int>[];
    for (var i = 0; i < 21; i++) {
      if (_getAttributeDiscipline(i) == discipline) indices.add(i);
    }
    return indices;
  }

  Discipline _getAttributeDiscipline(int index) {
    if (index < 4) return Discipline.finishing;
    if (index < 8) return Discipline.shooting;
    if (index < 12) return Discipline.playmaking;
    if (index < 16) return Discipline.defense;
    if (index < 19) return Discipline.rebounding;
    return Discipline.physicals;
  }

  String _getAttributeShortName(int index) {
    const names = [
      'Close Shot', 'Layup', 'Dunk', 'Stnd Dunk',
      'Post Ctrl', 'Mid-Range', '3PT', 'FT',
      'Pass Acc', 'Ball Handle', 'Spd w/Ball', 'Pass IQ',
      'Int Def', 'Per Def', 'Steal', 'Block',
      'Off Reb', 'Def Reb', 'Def Cons',
      'Speed', 'Agility',
    ];
    return index < names.length ? names[index] : 'Attr$index';
  }

  List<BadgeDef> _getBadgesForDiscipline(Discipline discipline) {
    return state.loader.badgeDefinitions.where((b) => b.discipline == discipline && b.allowed).toList();
  }
}

// ── Background Painter ──────────────────────────────────────

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle grid
    final gridPaint = Paint()
      ..color = AppTokens.primary.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 54) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 54) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Corner decorations (thick L-shapes)
    final cornerPaint = Paint()
      ..color = AppTokens.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const c = 80.0, m = 24.0;

    // Top-left
    canvas.drawLine(Offset(m, m), Offset(m + c, m), cornerPaint);
    canvas.drawLine(Offset(m, m), Offset(m, m + c), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m - c, m), cornerPaint);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + c), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(m, size.height - m), Offset(m + c, size.height - m), cornerPaint);
    canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - c), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m - c, size.height - m), cornerPaint);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m, size.height - m - c), cornerPaint);

    // Vertical accent lines on sides
    final accentPaint = Paint()
      ..color = AppTokens.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(36, 0), Offset(36, size.height), accentPaint);
    canvas.drawLine(Offset(size.width - 36, 0), Offset(size.width - 36, size.height), accentPaint);

    // Center horizontal accent
    canvas.drawLine(Offset(0, size.height * 0.42), Offset(size.width, size.height * 0.42), 
      Paint()..color = AppTokens.primary.withValues(alpha: 0.04)..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
