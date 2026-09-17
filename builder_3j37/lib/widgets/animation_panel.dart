import 'package:flutter/material.dart';
import '../data/models/animation_data.dart';
import '../data/services/builder_state_v3.dart';
import '../data/services/dataset_loader.dart';
import '../data/services/tuning_parser.dart';
import '../theme/app_tokens.dart';
import 'package:provider/provider.dart';
import 'center_dialog.dart';

class AnimationPanel extends StatefulWidget {
  const AnimationPanel({super.key});

  @override
  State<AnimationPanel> createState() => _AnimationPanelState();
}

class _AnimationPanelState extends State<AnimationPanel> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final loader = DatasetLoader();
    final tabs = loader.animTabs;
    if (tabs.isEmpty) {
      return Text('No animations loaded', style: AppTokens.caption);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab selector - 使用Wrap避免溢出
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(tabs.length, (i) {
            final isActive = i == _selectedTab;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppTokens.primary : AppTokens.surface,
                  border: Border.all(
                    color: isActive ? AppTokens.primary : AppTokens.chipBorder,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                ),
                child: Text(
                  tabs[i].getDisplayName(),
                  style: AppTokens.caption.copyWith(
                    color: isActive ? AppTokens.onPrimary : AppTokens.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        // Groups for selected tab
        ...tabs[_selectedTab].groups.map((group) => _AnimGroupWidget(group: group)),
      ],
    );
  }
}

class _AnimGroupWidget extends StatefulWidget {
  final AnimGroup group;
  const _AnimGroupWidget({required this.group});

  @override
  State<_AnimGroupWidget> createState() => _AnimGroupWidgetState();
}

class _AnimGroupWidgetState extends State<_AnimGroupWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final state = context.watch<BuilderStateV3>();
    final ratings = state.ratings;

    // Count unlocked animations
    int unlocked = 0;
    for (final anim in group.anims) {
      if (_isUnlocked(anim, ratings)) unlocked++;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTokens.surfaceAlt,
        border: Border.all(color: AppTokens.cardBorder, width: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.getDisplayName(), style: AppTokens.body.copyWith(fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('$unlocked/${group.anims.length} unlocked', style: AppTokens.caption.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppTokens.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppTokens.chipBorder),
            ...group.anims.map((anim) => _AnimEntryWidget(anim: anim)),
          ],
        ],
      ),
    );
  }

  bool _isUnlocked(AnimEntry anim, List<int> ratings) {
    for (final req in anim.attribReqs) {
      final idx = TuningParser.nativeNames.indexOf(req.attrib);
      if (idx < 0 || idx >= ratings.length) return false;
      if (ratings[idx] < req.value) return false;
    }
    return true;
  }
}

class _AnimEntryWidget extends StatelessWidget {
  final AnimEntry anim;
  const _AnimEntryWidget({required this.anim});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuilderStateV3>();
    final ratings = state.ratings;
    final isUnlocked = _isUnlocked(anim, ratings);

    return GestureDetector(
      onTap: () => _showRequirements(context, isUnlocked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTokens.chipBorder.withValues(alpha: 0.5), width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              isUnlocked ? Icons.check_circle : Icons.lock_outline,
              size: 14,
              color: isUnlocked ? AppTokens.primary : AppTokens.keyOff,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                anim.getDisplayName(),
                style: AppTokens.caption.copyWith(
                  color: isUnlocked ? AppTokens.textPrimary : AppTokens.keyOff,
                  fontSize: 12,
                ),
              ),
            ),
            if (anim.attribReqs.isNotEmpty)
              Text(
                '${anim.attribReqs.length} reqs',
                style: AppTokens.caption.copyWith(fontSize: 10, color: AppTokens.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  bool _isUnlocked(AnimEntry anim, List<int> ratings) {
    for (final req in anim.attribReqs) {
      final idx = TuningParser.nativeNames.indexOf(req.attrib);
      if (idx < 0 || idx >= ratings.length) return false;
      if (ratings[idx] < req.value) return false;
    }
    return true;
  }

  String _attrDisplayName(String nativeName) {
    const map = {
      'CloseShot': 'Close Shot',
      'MidRangeShot': 'Mid-Range',
      'ThreePointShot': '3PT Shot',
      'FreeThrow': 'Free Throw',
      'Layup': 'Driving Layup',
      'Dunk': 'Driving Dunk',
      'StandingDunk': 'Standing Dunk',
      'PostControl': 'Post Control',
      'PostHook': 'Post Hook',
      'PostFade': 'Post Fade',
      'DrawFoul': 'Draw Foul',
      'Hands': 'Hands',
      'InteriorDefense': 'Interior Def',
      'PerimeterDefense': 'Perimeter Def',
      'Steal': 'Steal',
      'Block': 'Block',
      'OffensiveRebound': 'OReb',
      'DefensiveRebound': 'DReb',
      'PassAccuracy': 'Pass Acc',
      'BallHandle': 'Ball Handle',
      'SpeedWithBall': 'Speed w/Ball',
      'Speed': 'Speed',
      'Acceleration': 'Acceleration',
      'Strength': 'Strength',
      'Vertical': 'Vertical',
      'Stamina': 'Stamina',
    };
    return map[nativeName] ?? nativeName;
  }

  void _showRequirements(BuildContext context, bool isUnlocked) {
    final state = context.read<BuilderStateV3>();
    final ratings = state.ratings;

    CenterDialog.show(
      context: context,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Icon(
                  isUnlocked ? Icons.check_circle : Icons.lock_outline,
                  size: 18,
                  color: isUnlocked ? AppTokens.primary : AppTokens.keyOff,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(anim.getDisplayName(), style: AppTokens.cardTitleStyle),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (anim.attribReqs.isEmpty) ...[
              Text('No requirements', style: AppTokens.caption),
            ] else ...[
              Text('Attribute Requirements', style: AppTokens.body),
              const SizedBox(height: 8),
              ...anim.attribReqs.map((req) {
                final idx = TuningParser.nativeNames.indexOf(req.attrib);
                final current = (idx >= 0 && idx < ratings.length) ? ratings[idx] : 0;
                final met = current >= req.value;
                final attrName = _attrDisplayName(req.attrib);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        met ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 14,
                        color: met ? AppTokens.primary : AppTokens.keyOff,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          attrName,
                          style: AppTokens.caption.copyWith(
                            color: met ? AppTokens.textPrimary : AppTokens.keyOff,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '$current / ${req.value}',
                        style: AppTokens.caption.copyWith(
                          color: met ? AppTokens.primary : AppTokens.keyOff,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
