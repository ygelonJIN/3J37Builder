import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/goal_data.dart';
import '../data/models/animation_data.dart';
import '../data/services/dataset_loader.dart';
import '../data/services/builder_state_v3.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';
import 'center_dialog.dart';
import '../data/models/enums.dart';
import '../data/models/badge_data.dart';

class GoalCard extends StatefulWidget {
  final ValueChanged<bool>? onExpandedChanged;

  const GoalCard({super.key, this.onExpandedChanged});

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  bool _expanded = false;

  void _toggleExpanded() {
    FocusScope.of(context).unfocus();
    setState(() {
      _expanded = !_expanded;
      widget.onExpandedChanged?.call(_expanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderStateV3>();
    final goalData = state.goalData;
    final badgeCount = goalData.badgeCount;
    final moveCount = goalData.moveCount;
    final attrCount = goalData.attributeCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: AppTokens.surfaceAlt,
        border: Border.all(color: AppTokens.primary.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Minimized header ──────────────────────────────
          GestureDetector(
            onTap: _toggleExpanded,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('GOAL', style: AppTokens.brandMark.copyWith(fontSize: 14, letterSpacing: 2, color: AppTokens.textSecondary)),
                      const Spacer(),
                      Text('Badges:$badgeCount', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 9, fontWeight: FontWeight.w500, color: AppTokens.textSecondary)),
                      const SizedBox(width: 8),
                      Text('Moves:$moveCount', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 9, fontWeight: FontWeight.w500, color: AppTokens.textSecondary)),
                      const SizedBox(width: 8),
                      Text('Attr:$attrCount', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 9, fontWeight: FontWeight.w500, color: AppTokens.textSecondary)),
                      const SizedBox(width: 8),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: AppTokens.textSecondary),
                    ],
                  ),

                ],
              ),
            ),
          ),

          // ── Add button (fixed, not scrollable) ───────────
          if (_expanded) ...[
            const SizedBox(height: 4),
            _buildAddButton(),
          ],

          // ── Expanded content (constrained height) ─────────
          if (_expanded) ...[
            const SizedBox(height: 4),
            if (goalData.badges.isNotEmpty || goalData.moves.isNotEmpty || goalData.attributes.isNotEmpty) ...[
              _buildAttrReqsSummary(goalData),
              const SizedBox(height: 4),
            ],
            const Divider(height: 1, color: AppTokens.keyOff),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    if (goalData.badges.isNotEmpty) ...[
                      _buildSectionHeader('Badges'),
                      ...goalData.badges.map((b) => _buildBadgeItem(b)),
                      const SizedBox(height: 6),
                    ],
                    if (goalData.moves.isNotEmpty) ...[
                      _buildSectionHeader('Moves'),
                      ...goalData.moves.map((m) => _buildMoveItem(m)),
                      const SizedBox(height: 6),
                    ],
                    if (goalData.attributes.isNotEmpty) ...[
                      _buildSectionHeader('Attributes'),
                      ...goalData.attributes.map((a) => _buildAttributeItem(a)),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Attribute requirements summary ─────────────────────────
  Widget _buildAttrReqsSummary(GoalData goalData) {
    final loader = DatasetLoader();
    final combinedReqs = <int, int>{};
    for (final entry in goalData.getAttributeRequirements().entries) {
      combinedReqs[entry.key] = entry.value;
    }
    for (final attr in goalData.attributes) {
      final existing = combinedReqs[attr.attributeIndex] ?? 0;
      if (attr.targetValue > existing) {
        combinedReqs[attr.attributeIndex] = attr.targetValue;
      }
    }
    if (combinedReqs.isEmpty) return const SizedBox.shrink();

    final reqChips = combinedReqs.entries.map((e) {
      final attrName = loader.attributes[e.key].displayName;
      return '$attrName ${e.value}';
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          Text(
            'Attr Reqs:',
            style: TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: AppTokens.keyOff,
            ),
          ),
          ...reqChips.map((t) => Text(
            t,
            style: TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 8,
              fontWeight: FontWeight.w400,
              color: AppTokens.keyOff,
            ),
          )),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(title, style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: AppTokens.textPrimary)),
    );
  }

  // ── Full-width add button ─────────────────────────────────
  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => _showAddDialog(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          border: Border.all(color: AppTokens.primary.withValues(alpha: 0.4), width: 1),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 36, color: AppTokens.primary),
            const SizedBox(width: 4),
            Text('Add Goal', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: AppTokens.primary)),
          ],
        ),
      ),
    );
  }

  // ── Badge item row ────────────────────────────────────────
  Widget _buildBadgeItem(GoalBadge badge) {
    final attrReqs = badge.attributeRequirements;
    final tierColors = {
      'Bronze': const Color(0xFFCD7F32),
      'Silver': const Color(0xFFC0C0C0),
      'Gold': AppTokens.primary,
      'Hall of Fame': const Color(0xFF9B59B6),
      'Legend': const Color(0xFFE74C3C),
    };
    final tierColor = tierColors[badge.tier] ?? AppTokens.primary;
    const darkGold = Color(0xFFB8860B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: badge.badgeName, style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: AppTokens.textSecondary)),
                    TextSpan(text: '  ', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 11)),
                    TextSpan(text: badge.tier, style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 11, fontWeight: FontWeight.w600, color: tierColor)),
                  ]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => context.read<BuilderStateV3>().removeGoalBadge(badge.badgeId),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTokens.surface,
                    border: Border.all(color: AppTokens.primary.withValues(alpha: 0.5), width: 1),
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                  ),
                  child: Icon(Icons.close, size: 14, color: AppTokens.primary),
                ),
              ),
            ],
          ),
          if (attrReqs.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildAttrReqsText(attrReqs),
            ),
          ],
        ],
      ),
    );
  }

  // ── Attr reqs text with discipline colors ──────────────────
  Widget _buildAttrReqsText(List<GoalAttributeRequirement> attrReqs) {
    final loader = DatasetLoader();
    final spans = <TextSpan>[];
    for (int i = 0; i < attrReqs.length; i++) {
      final r = attrReqs[i];
      final attr = loader.attributes[r.attributeIndex];
      final discColor = AppTokens.disciplineColours[attr.discipline.name] ?? AppTokens.textSecondary;
      if (i > 0) spans.add(TextSpan(text: ', ', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 9)));
      spans.add(TextSpan(
        text: '${r.attributeName} ${r.minimum}',
        style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 9, fontWeight: FontWeight.w500, color: discColor),
      ));
    }
    return Text.rich(TextSpan(children: [
      TextSpan(text: 'Attr: ', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 9, fontWeight: FontWeight.w400, color: AppTokens.textSecondary)),
      ...spans,
    ]), overflow: TextOverflow.ellipsis);
  }

  // ── Move item row ─────────────────────────────────────────
  Widget _buildMoveItem(GoalMove move) {
    final color = AppTokens.textSecondary;
    final attrReqs = move.attributeRequirements;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${move.moveName}',
                  style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => context.read<BuilderStateV3>().removeGoalMove(move.moveId),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTokens.surface,
                    border: Border.all(color: AppTokens.primary.withValues(alpha: 0.5), width: 1),
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                  ),
                  child: Icon(Icons.close, size: 14, color: AppTokens.primary),
                ),
              ),
            ],
          ),
          if (attrReqs.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildAttrReqsText(attrReqs),
            ),
          ],
        ],
      ),
    );
  }

  // ── Attribute item row ────────────────────────────────────
  Widget _buildAttributeItem(GoalAttribute attr) {
    final loader = DatasetLoader();
    final color = AppTokens.disciplineColours[loader.attributes[attr.attributeIndex].discipline.name] ?? AppTokens.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${attr.attributeName}  ${attr.targetValue}',
              style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => context.read<BuilderStateV3>().removeGoalAttribute(attr.attributeIndex),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTokens.surface,
                border: Border.all(color: AppTokens.primary.withValues(alpha: 0.5), width: 1),
                borderRadius: BorderRadius.circular(AppTokens.radius),
              ),
              child: Icon(Icons.close, size: 14, color: AppTokens.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _inferDiscipline(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('finishing') || lower.contains('close') || lower.contains('layup') || lower.contains('dunk')) return 'finishing';
    if (lower.contains('shoot') || lower.contains('mid') || lower.contains('three') || lower.contains('free')) return 'shooting';
    if (lower.contains('play') || lower.contains('pass') || lower.contains('ball') || lower.contains('handle')) return 'playmaking';
    if (lower.contains('def') || lower.contains('steal') || lower.contains('block') || lower.contains('perimeter') || lower.contains('interior')) return 'defense';
    if (lower.contains('rebound') || lower.contains('offensivereb') || lower.contains('defensivereb')) return 'rebounding';
    if (lower.contains('speed') || lower.contains('strength') || lower.contains('stamina') || lower.contains('vertical') || lower.contains('agility') || lower.contains('accelerat')) return 'physicals';
    return 'finishing';
  }

  // ── Add dialog with search ────────────────────────────────
  void _showAddDialog() {
    final inputFocused = ValueNotifier<bool>(false);
    CenterDialog.show(
      context: context,
      child: _GoalAddDialogContent(state: context.read<BuilderStateV3>(), loader: DatasetLoader(), inputFocused: inputFocused),
      onClose: () {
        // Dead click: if a text field has focus, just unfocus (save on blur), don't close dialog
        if (inputFocused.value) {
          FocusManager.instance.primaryFocus?.unfocus();
          return;
        }
        Navigator.of(context).pop();
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Add dialog content – tab-based with search
// ══════════════════════════════════════════════════════════════
class _GoalAddDialogContent extends StatefulWidget {
  final BuilderStateV3 state;
  final DatasetLoader loader;
  final ValueNotifier<bool> inputFocused;
  const _GoalAddDialogContent({required this.state, required this.loader, required this.inputFocused});
  @override
  State<_GoalAddDialogContent> createState() => _GoalAddDialogContentState();
}

class _GoalAddDialogContentState extends State<_GoalAddDialogContent> {
  BuilderStateV3 get state => widget.state;
  DatasetLoader get loader => widget.loader;
  int _tabIndex = 0; // 0=Badges, 1=Moves, 2=Attributes
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _valueCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _valueFocus = FocusNode();
  String? _selectedId;
  BadgeTier? _selectedTier;
  String? _errorMessage;
  String _searchQuery = '';
  final Set<String> _expandedGroups = {}; // discipline name or animGroup key

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() { setState(() { _searchQuery = _searchCtrl.text; }); });
    _searchFocus.addListener(_updateInputFocused);
    _valueFocus.addListener(_updateInputFocused);
  }

  void _updateInputFocused() {
    widget.inputFocused.value = _searchFocus.hasFocus || _valueFocus.hasFocus;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _valueCtrl.dispose();
    _searchFocus.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tab bar (fixed) ──
            _buildTabBar(),
            const SizedBox(height: 8),
            // ── Search field (fixed) ──
            _buildSearchField(),
            // ── Tab-specific input (fixed) ──
            if (_tabIndex == 0) ...[
              const SizedBox(height: 4),
              _buildTierDropdown(),
            ],
            if (_tabIndex == 2) ...[
              const SizedBox(height: 4),
              _buildValueInput(),
            ],
            const SizedBox(height: 8),
            // ── Results list (scrollable only this part) ──
            Flexible(
              child: SingleChildScrollView(
                child: _buildResultsList(),
              ),
            ),
            // ── Error + Buttons (fixed) ──
            if (_errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(_errorMessage!, style: AppTokens.caption.copyWith(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () { Navigator.pop(context); },
                  child: Text('Cancel', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 14, color: AppTokens.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.primary,
                    foregroundColor: AppTokens.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius)),
                  ),
                  child: Text('Add', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ──
  Widget _buildTabBar() {
    final tabs = ['Badges', 'Moves', 'Attributes'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final selected = _tabIndex == i;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _tabIndex = i;
                _selectedId = null;
                _selectedTier = null;
                _searchCtrl.clear();
                _errorMessage = null;
                _expandedGroups.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTokens.primary : AppTokens.surface,
                border: Border.all(color: selected ? AppTokens.primary : AppTokens.keyOff.withValues(alpha: 0.3), width: 1),
                borderRadius: BorderRadius.circular(AppTokens.radius),
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  fontFamily: AppTokens.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTokens.onPrimary : AppTokens.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Search field ──
  Widget _buildSearchField() {
    final hint = _tabIndex == 0 ? 'Search badges...' : _tabIndex == 1 ? 'Search moves...' : 'Search attributes...';
    return TextField(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      style: AppTokens.body.copyWith(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTokens.caption,
        prefixIcon: Icon(Icons.search, size: 18, color: AppTokens.textSecondary),
        filled: true,
        fillColor: AppTokens.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius), borderSide: BorderSide(color: AppTokens.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius), borderSide: BorderSide(color: AppTokens.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius), borderSide: BorderSide(color: AppTokens.primary)),
      ),
    );
  }

  // ── Tier dropdown (custom, matches input width) ──
  Widget _buildTierDropdown() {
    final tiers = BadgeTier.values;
    final labels = ['Bronze', 'Silver', 'Gold', 'Hall of Fame', 'Legend'];
    return GestureDetector(
      onTap: () => _showTierPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTokens.surfaceAlt,
          border: Border.all(color: AppTokens.inputBorder),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedTier?.label ?? 'Select badge tier',
                style: TextStyle(
                  fontFamily: AppTokens.fontFamily,
                  fontSize: 13,
                  color: _selectedTier != null ? AppTokens.textPrimary : AppTokens.textSecondary,
                ),
              ),
            ),
            Icon(Icons.expand_more, size: 18, color: AppTokens.primary),
          ],
        ),
      ),
    );
  }

  void _showTierPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          backgroundColor: AppTokens.surfaceAlt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius)),
          title: Text('Select Badge Tier', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: AppTokens.textPrimary)),
          children: BadgeTier.values.map((tier) {
            final selected = _selectedTier == tier;
            return SimpleDialogOption(
              onPressed: () { setState(() { _selectedTier = tier; _errorMessage = null; }); Navigator.pop(ctx); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    if (selected) Icon(Icons.check, size: 16, color: AppTokens.primary),
                    if (selected) const SizedBox(width: 8),
                    Text(tier.label, style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppTokens.primary : AppTokens.textPrimary)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Value input (Attributes only) ──
  Widget _buildValueInput() {
    return TextField(
      controller: _valueCtrl,
      focusNode: _valueFocus,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppTokens.body.copyWith(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Target value (X in X/Y)',
        hintStyle: AppTokens.caption,
        filled: true,
        fillColor: AppTokens.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius), borderSide: BorderSide(color: AppTokens.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius), borderSide: BorderSide(color: AppTokens.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius), borderSide: BorderSide(color: AppTokens.primary)),
      ),
    );
  }

  // ── Results list ──
  Widget _buildResultsList() {
    final query = _searchQuery.toLowerCase();

    if (_tabIndex == 0) {
      return _buildBadgesList(query);
    } else if (_tabIndex == 1) {
      return _buildMovesList(query);
    } else {
      return _buildAttrsList(query);
    }
  }

  // ── Badges list – collapsible by discipline ──
  Widget _buildBadgesList(String query) {
    final allBadges = loader.badgeDefinitions.where((b) => b.allowed).toList();
    final filtered = query.isEmpty ? allBadges : allBadges.where((b) => b.displayName.toLowerCase().contains(query)).toList();
    if (filtered.isEmpty) return Center(child: Text('No results', style: AppTokens.caption));
    final grouped = <Discipline, List<BadgeDef>>{};
    for (final b in filtered) { grouped.putIfAbsent(b.discipline, () => []).add(b); }
    final items = <Widget>[];
    for (final disc in Discipline.values) {
      final badges = grouped[disc];
      if (badges == null || badges.isEmpty) continue;
      final key = disc.name;
      final expanded = _expandedGroups.contains(key);
      final color = AppTokens.disciplineColours[key] ?? AppTokens.textSecondary;
      // Header (tappable to expand/collapse)
      items.add(GestureDetector(
        onTap: () => setState(() { expanded ? _expandedGroups.remove(key) : _expandedGroups.add(key); }),
        child: Padding(
          padding: const EdgeInsets.only(left: 4, top: 0, bottom: 2),
          child: Row(children: [
            Icon(expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 14, color: color),
            const SizedBox(width: 2),
            Text('${disc.displayName} (${badges.length})', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ));
      if (!expanded) continue;
      for (final b in badges) {
        final id = b.badgeId.toString();
        final selected = _selectedId == id;
        final alreadyAdded = state.hasGoalBadge(b.badgeId);
        items.add(GestureDetector(
          onTap: alreadyAdded ? null : () => setState(() { _selectedId = id; _errorMessage = null; }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            color: selected ? AppTokens.primary.withValues(alpha: 0.15) : Colors.transparent,
            child: Row(children: [
              Container(width: 3, height: 14, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(b.displayName, style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: alreadyAdded ? AppTokens.keyOff : AppTokens.textPrimary))),
              if (alreadyAdded) Text('Added', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 10, color: AppTokens.keyOff)),
            ]),
          ),
        ));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: items);
  }

  // ── Moves list – collapsible by AnimGroup ──
  Widget _buildMovesList(String query) {
    final items = <Widget>[];
    for (final tab in loader.animTabs) {
      for (final group in tab.groups) {
        final anims = query.isEmpty
            ? group.anims
            : group.anims.where((a) => a.getDisplayName().toLowerCase().contains(query)).toList();
        if (anims.isEmpty) continue;
        final key = '${tab.tabId}__${group.animType}__${group.getDisplayName()}';
        final expanded = _expandedGroups.contains(key);
        // Group header
        items.add(GestureDetector(
          onTap: () => setState(() { expanded ? _expandedGroups.remove(key) : _expandedGroups.add(key); }),
          child: Padding(
            padding: const EdgeInsets.only(left: 4, top: 0, bottom: 2),
            child: Row(children: [
              Icon(expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 14, color: AppTokens.textSecondary),
              const SizedBox(width: 2),
              Expanded(child: Text('${group.getDisplayName()} (${anims.length})', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: AppTokens.textSecondary))),
            ]),
          ),
        ));
        if (!expanded) continue;
        for (final a in anims) {
          final selected = _selectedId == a.animId;
          final alreadyAdded = state.hasGoalMove(a.animId);
          items.add(GestureDetector(
            onTap: alreadyAdded ? null : () => setState(() { _selectedId = a.animId; _errorMessage = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              color: selected ? AppTokens.primary.withValues(alpha: 0.15) : Colors.transparent,
              child: Row(children: [
                Expanded(child: Text(a.getDisplayName(), style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: alreadyAdded ? AppTokens.keyOff : AppTokens.textPrimary))),
                if (alreadyAdded) Text('Added', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 10, color: AppTokens.keyOff)),
              ]),
            ),
          ));
        }
      }
    }
    if (items.isEmpty) return Center(child: Text('No results', style: AppTokens.caption));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: items);
  }

  // ── Attributes list ──
  Widget _buildAttrsList(String query) {
    final allAttrs = loader.attributes;
    final filtered = query.isEmpty ? allAttrs : allAttrs.where((a) => a.displayName.toLowerCase().contains(query)).toList();
    if (filtered.isEmpty) return Center(child: Text('No results', style: AppTokens.caption));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filtered.map((a) {
        final id = a.index.toString();
        final selected = _selectedId == id;
        final alreadyAdded = state.hasGoalAttribute(a.index);
        final discipline = a.discipline.name;
        final color = AppTokens.disciplineColours[discipline] ?? AppTokens.textSecondary;
        return GestureDetector(
          onTap: alreadyAdded ? null : () => setState(() { _selectedId = id; _errorMessage = null; }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            color: selected ? AppTokens.primary.withValues(alpha: 0.15) : Colors.transparent,
            child: Row(children: [
              Container(width: 3, height: 14, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(a.displayName, style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: alreadyAdded ? AppTokens.keyOff : AppTokens.textPrimary))),
              if (alreadyAdded) Text('Added', style: TextStyle(fontFamily: AppTokens.fontFamily, fontSize: 10, color: AppTokens.keyOff)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Add action ──
  void _onAdd() {
    if (_selectedId == null) {
      setState(() { _errorMessage = 'Please select an item'; });
      return;
    }

    if (_tabIndex == 0) {
      // Badge
      if (_selectedTier == null) {
        setState(() { _errorMessage = 'Please select a badge tier'; });
        return;
      }
      final badgeId = int.parse(_selectedId!);
      if (state.hasGoalBadge(badgeId)) {
        setState(() { _errorMessage = 'Badge already added to goals'; });
        return;
      }
      final tierValue = _selectedTier!.code;
      final error = state.validateGoalBadge(badgeId, tierValue);
      if (error != null) { setState(() { _errorMessage = error; }); return; }
      final badge = loader.badgeDefinitions.firstWhere((b) => b.badgeId == badgeId, orElse: () => throw Exception('Badge not found'));
      
      // Get attribute requirements for this badge tier
      // Legend tier has no requirements in the dataset; fall back to hall_of_fame
      BadgeTier reqTier = _selectedTier!;
      if (reqTier == BadgeTier.legend) reqTier = BadgeTier.hallOfFame;
      var tierReqs = loader.tierRequirements.where((r) => r.badgeId == badgeId && r.tier == reqTier).toList();
      // If still empty, try the highest available tier
      if (tierReqs.isEmpty) {
        for (final t in [BadgeTier.hallOfFame, BadgeTier.gold, BadgeTier.silver, BadgeTier.bronze]) {
          tierReqs = loader.tierRequirements.where((r) => r.badgeId == badgeId && r.tier == t).toList();
          if (tierReqs.isNotEmpty) break;
        }
      }
      final attrReqs = <GoalAttributeRequirement>[];
      for (final req in tierReqs) {
        for (final r in req.requirements) {
          final displayName = loader.attributes[r.attributeIndex].displayName;
          attrReqs.add(GoalAttributeRequirement(
            attributeIndex: r.attributeIndex,
            attributeName: displayName,
            minimum: r.minimum,
          ));
        }
      }
      
      state.addGoalBadge(GoalBadge(
        badgeId: badgeId,
        badgeName: badge.displayName,
        tier: _selectedTier!.label,
        targetValue: tierValue,
        attributeRequirements: attrReqs,
      ));
    } else if (_tabIndex == 1) {
      // Move
      if (state.hasGoalMove(_selectedId!)) {
        setState(() { _errorMessage = 'Move already added to goals'; });
        return;
      }
      String moveName = _selectedId!;
      String category = 'animation';
      for (final tab in loader.animTabs) {
        for (final group in tab.groups) {
          for (final anim in group.anims) {
            if (anim.animId == _selectedId!) {
              moveName = anim.getDisplayName();
              category = group.animType;
            }
          }
        }
      }
      // Get attribute requirements from animation attribReqs
      // Map Attrib Type (e.g. "ShotMidrange") to attribute name (e.g. "mid_range")
      const attribTypeToName = {
        'ShotMidrange': 'mid_range',
        'ShotThree': 'three_point',
        'DrivingDunk': 'driving_dunk',
        'DrivingLayup': 'driving_layup',
        'StandingDunk': 'standing_dunk',
        'PostControl': 'post_control',
        'BallControl': 'ball_handle',
        'PassAccuracy': 'pass_accuracy',
        'SpeedWithBall': 'speed_with_ball',
        'Speed': 'speed',
        'Agility': 'agility',
        'Vertical': 'vertical',
        'CloseShot': 'close_shot',
        'FreeThrow': 'free_throw',
        'InteriorDefense': 'interior_defense',
        'PerimeterDefense': 'perimeter_defense',
        'Steal': 'steal',
        'Block': 'block',
        'OffensiveRebound': 'offensive_rebound',
        'DefensiveRebound': 'defensive_rebound',
        'Strength': 'strength',
      };
      final moveAttrReqs = <GoalAttributeRequirement>[];
      for (final tab in loader.animTabs) {
        for (final group in tab.groups) {
          for (final anim in group.anims) {
            if (anim.animId == _selectedId!) {
              for (final req in anim.attribReqs) {
                final mappedName = attribTypeToName[req.attrib] ?? req.attrib;
                final attrIndex = loader.attributes.indexWhere((a) => a.name == mappedName);
                if (attrIndex >= 0) {
                  moveAttrReqs.add(GoalAttributeRequirement(
                    attributeIndex: attrIndex,
                    attributeName: loader.attributes[attrIndex].displayName,
                    minimum: req.value,
                  ));
                }
              }
            }
          }
        }
      }

      state.addGoalMove(GoalMove(
        moveId: _selectedId!,
        moveName: moveName,
        category: category,
        targetValue: 1,
        attributeRequirements: moveAttrReqs,
      ));
    } else {
      // Attribute
      final targetValue = int.tryParse(_valueCtrl.text);
      if (targetValue == null) {
        setState(() { _errorMessage = 'Please enter a valid number'; });
        return;
      }
      final attrIndex = int.parse(_selectedId!);
      if (state.hasGoalAttribute(attrIndex)) {
        setState(() { _errorMessage = 'Attribute already added to goals'; });
        return;
      }
      final error = state.validateGoalAttribute(attrIndex, targetValue);
      if (error != null) { setState(() { _errorMessage = error; }); return; }
      state.addGoalAttribute(GoalAttribute(attributeIndex: attrIndex, attributeName: loader.attributes[attrIndex].displayName, targetValue: targetValue));
    }

    Navigator.pop(context);
  }
}
