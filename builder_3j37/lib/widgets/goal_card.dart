import 'package:flutter/material.dart';
import '../data/models/goal_data.dart';
import '../data/models/animation_data.dart';
import '../data/services/builder_state_v3.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';

class GoalCard extends StatefulWidget {
  const GoalCard({super.key});

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  bool _expanded = false;

  void _toggleExpanded() {
    FocusScope.of(context).unfocus();
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderStateV3>();
    final goalData = state.goalData;
    final badgeCount = goalData.badgeCount;
    final moveCount = goalData.moveCount;

    return AnimatedContainer(
      duration: AppTokens.animShort,
      curve: AppTokens.curveOut,
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
          GestureDetector(
            onTap: _toggleExpanded,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  'GOAL',
                  style: AppTokens.brandMark.copyWith(fontSize: 18, letterSpacing: 2),
                ),
                const Spacer(),
                Text(
                  'Badges: $badgeCount',
                  style: TextStyle(
                    fontFamily: AppTokens.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Moves: $moveCount',
                  style: TextStyle(
                    fontFamily: AppTokens.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTokens.textSecondary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            _buildAddButton(),
            const SizedBox(height: 8),
            if (goalData.badges.isNotEmpty) ...[
              _buildBadgesSection(goalData.badges),
              const SizedBox(height: 8),
            ],
            if (goalData.moves.isNotEmpty) ...[
              _buildMovesSection(goalData.moves),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          border: Border.all(color: AppTokens.primary.withValues(alpha: 0.4), width: 1),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 16,
              color: AppTokens.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Add Goal',
              style: TextStyle(
                fontFamily: AppTokens.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTokens.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesSection(List<GoalBadge> badges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Badges',
          style: TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        ...badges.map((badge) => _buildGoalBadgeItem(badge)),
      ],
    );
  }

  Widget _buildMovesSection(List<GoalMove> moves) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Moves',
          style: TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        ...moves.map((move) => _buildGoalMoveItem(move)),
      ],
    );
  }

  Widget _buildGoalBadgeItem(GoalBadge badge) {
    final state = context.read<BuilderStateV3>();
    final discipline = badge.badgeName.contains('finishing') ? 'finishing' :
                      badge.badgeName.contains('shooting') ? 'shooting' :
                      badge.badgeName.contains('playmaking') ? 'playmaking' :
                      badge.badgeName.contains('defense') ? 'defense' :
                      badge.badgeName.contains('rebounding') ? 'rebounding' : 'physicals';
    final color = AppTokens.disciplineColours[discipline] ?? AppTokens.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    badge.badgeName,
                    style: TextStyle(
                      fontFamily: AppTokens.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTokens.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${badge.targetValue}',
                  style: TextStyle(
                    fontFamily: AppTokens.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => state.removeGoalBadge(badge.badgeId),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTokens.surface,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(
                Icons.close,
                size: 12,
                color: AppTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalMoveItem(GoalMove move) {
    final state = context.read<BuilderStateV3>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.animation,
                  size: 12,
                  color: AppTokens.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    move.moveName,
                    style: TextStyle(
                      fontFamily: AppTokens.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTokens.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${move.targetValue}',
                  style: TextStyle(
                    fontFamily: AppTokens.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => state.removeGoalMove(move.moveId),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTokens.surface,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(
                Icons.close,
                size: 12,
                color: AppTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => const GoalAddDialog(),
    );
  }
}

class GoalAddDialog extends StatefulWidget {
  const GoalAddDialog({super.key});

  @override
  State<GoalAddDialog> createState() => _GoalAddDialogState();
}

class _GoalAddDialogState extends State<GoalAddDialog> {
  final TextEditingController _controller = TextEditingController();
  String _selectedType = 'badge'; // 'badge' or 'move'
  String? _selectedBadge;
  String? _selectedMove;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<BuilderStateV3>();
    final loader = state.loader;

    return Dialog(
      backgroundColor: AppTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(color: AppTokens.primary.withValues(alpha: 0.4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Goal',
              style: AppTokens.cardTitleStyle,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = 'badge'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedType == 'badge' ? AppTokens.primary : AppTokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppTokens.radius),
                      ),
                      child: Center(
                        child: Text(
                          'Badge',
                          style: TextStyle(
                            fontFamily: AppTokens.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedType == 'badge' ? AppTokens.onPrimary : AppTokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = 'move'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedType == 'move' ? AppTokens.primary : AppTokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppTokens.radius),
                      ),
                      child: Center(
                        child: Text(
                          'Move',
                          style: TextStyle(
                            fontFamily: AppTokens.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedType == 'move' ? AppTokens.onPrimary : AppTokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedType == 'badge') ...[
              _buildBadgeSelector(loader),
            ] else ...[
              _buildMoveSelector(loader),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target Value',
                labelStyle: AppTokens.caption,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  borderSide: BorderSide(color: AppTokens.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  borderSide: BorderSide(color: AppTokens.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  borderSide: BorderSide(color: AppTokens.primary),
                ),
                errorText: _errorMessage,
                errorStyle: TextStyle(
                  fontFamily: AppTokens.fontFamily,
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
              style: AppTokens.body,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: AppTokens.fontFamily,
                      fontSize: 14,
                      color: AppTokens.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.primary,
                    foregroundColor: AppTokens.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                    ),
                  ),
                  child: Text(
                    'Add',
                    style: TextStyle(
                      fontFamily: AppTokens.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeSelector(DatasetLoader loader) {
    final badges = loader.badgeDefinitions.where((b) => b.allowed).toList();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: AppTokens.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBadge,
          hint: Text(
            'Select Badge',
            style: AppTokens.caption,
          ),
          isExpanded: true,
          dropdownColor: AppTokens.surface,
          style: AppTokens.body,
          items: badges.map((badge) {
            return DropdownMenuItem(
              value: badge.badgeId.toString(),
              child: Text(badge.displayName),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBadge = value;
              _errorMessage = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildMoveSelector(DatasetLoader loader) {
    // Get all animations from all tabs and groups
    final allAnims = <AnimEntry>[];
    for (final tab in loader.animTabs) {
      for (final group in tab.groups) {
        allAnims.addAll(group.anims);
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: AppTokens.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMove,
          hint: Text(
            'Select Move',
            style: AppTokens.caption,
          ),
          isExpanded: true,
          dropdownColor: AppTokens.surface,
          style: AppTokens.body,
          items: allAnims.map((anim) {
            return DropdownMenuItem(
              value: anim.animId,
              child: Text(anim.getDisplayName()),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedMove = value;
              _errorMessage = null;
            });
          },
        ),
      ),
    );
  }
    final targetValue = int.tryParse(_controller.text);
    
    if (targetValue == null) {
      setState(() {
        _errorMessage = 'Please enter a valid number';
      });
      return;
    }

    if (_selectedType == 'badge') {
      if (_selectedBadge == null) {
        setState(() {
          _errorMessage = 'Please select a badge';
        });
        return;
      }

      final badgeId = int.parse(_selectedBadge!);
      final badge = state.loader.badgeDefinitions.firstWhere(
        (b) => b.badgeId == badgeId,
        orElse: () => throw Exception('Badge not found'),
      );

      // Validate
      final error = state.validateGoalBadge(badgeId, targetValue);
      if (error != null) {
        setState(() {
          _errorMessage = error;
        });
        return;
      }

      // Check if already exists
      if (state.hasGoalBadge(badgeId)) {
        setState(() {
          _errorMessage = 'Badge already added to goals';
        });
        return;
      }

      // Add goal badge
      state.addGoalBadge(GoalBadge(
        badgeId: badgeId,
        badgeName: badge.displayName,
        tier: targetValue.toString(),
        targetValue: targetValue,
      ));
    } else {
      if (_selectedMove == null) {
        setState(() {
          _errorMessage = 'Please select a move';
        });
        return;
      }

      // Validate
      final error = state.validateGoalMove(_selectedMove!, targetValue);
      if (error != null) {
        setState(() {
          _errorMessage = error;
        });
        return;
      }

      // Check if already exists
      if (state.hasGoalMove(_selectedMove!)) {
        setState(() {
          _errorMessage = 'Move already added to goals';
        });
        return;
      }

      // Add goal move
      // Get the actual move name from animation data
      String moveName = _selectedMove!;
      String category = 'animation';
      for (final tab in state.loader.animTabs) {
        for (final group in tab.groups) {
          for (final anim in group.anims) {
            if (anim.animId == _selectedMove!) {
              moveName = anim.getDisplayName();
              category = group.animType;
              break;
            }
          }
        }
      }
      
      state.addGoalMove(GoalMove(
        moveId: _selectedMove!,
        moveName: moveName,
        category: category,
        targetValue: targetValue,
      ));
    }

    Navigator.pop(context);
  }
}
