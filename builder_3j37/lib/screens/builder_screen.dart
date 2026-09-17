import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/services/builder_state_v3.dart';
import '../data/services/dataset_loader.dart';
import '../data/services/cap_breaker_engine.dart';
import '../theme/app_tokens.dart';
import '../widgets/attribute_group.dart';
import '../widgets/badge_panel.dart';
import '../widgets/animation_panel.dart';
import '../widgets/overall_display.dart';
import '../widgets/attribute_floating_card.dart';
import '../widgets/goal_card.dart';

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  bool _essentialLoading = true;
  bool _heavyLoading = true;
  bool _showBadges = false;
  bool _showMoves = false;
  bool _cardExpanded = true;
  bool _minimapExpanded = false;
  bool _goalExpanded = false;
  final ScrollController _scrollController = ScrollController();

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loader = DatasetLoader();
    await loader.loadEssential();
    if (mounted) setState(() => _essentialLoading = false);
    await loader.loadHeavy();
    // Load model into cap breaker engine
    if (loader.modelWeights != null && loader.modelCurves != null) {
      CapBreakerEngine().loadModelData(loader.modelWeights!, loader.modelCurves!, overallScale: loader.modelOverallScale);
      debugPrint('[BuilderScreen] Cap breaker model loaded: ${loader.modelWeights!.length} weights, ${loader.modelCurves!.length} curves');
    }
    if (mounted) setState(() => _heavyLoading = false);
  }

  void _openBadges() {
    setState(() => _showBadges = true);
  }

  void _openMoves() {
    setState(() => _showMoves = true);
  }

  void _closeBadges() {
    setState(() => _showBadges = false);
  }

  void _closeMoves() {
    setState(() => _showMoves = false);
  }

  void _onCardExpandedChanged(bool expanded) {
    final oldExpanded = _cardExpanded;
    final offset = _scrollController.offset;
    final isAtTop = offset <= 0;
    
    if (!isAtTop && oldExpanded != expanded) {
      final adjustment = expanded ? 155.0 : -155.0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(offset + adjustment);
      }
    }
    
    setState(() {
      _cardExpanded = expanded;
    });
  }

  void _onMinimapExpandedChanged(bool expanded) {
    final oldExpanded = _minimapExpanded;
    final offset = _scrollController.offset;
    final isAtTop = offset <= 0;
    
    if (!isAtTop && oldExpanded != expanded) {
      final adjustment = expanded ? 240.0 : -240.0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(offset + adjustment);
      }
    }
    
    setState(() {
      _minimapExpanded = expanded;
    });
  }

  void _onGoalExpandedChanged(bool expanded) {
    final oldExpanded = _goalExpanded;
    final offset = _scrollController.offset;
    final isAtTop = offset <= 0;
    
    if (!isAtTop && oldExpanded != expanded) {
      final adjustment = expanded ? 60.0 : -60.0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(offset + adjustment);
      }
    }
    
    setState(() {
      _goalExpanded = expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_essentialLoading) {
      return const Scaffold(
        backgroundColor: AppTokens.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTokens.primary),
              SizedBox(height: 16),
              Text('3J37 BUILDER', style: AppTokens.brandMark),
            ],
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => BuilderStateV3(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppTokens.background,
        body: Stack(
          children: [
            _buildHomeBody(),
            if (_showBadges) _buildBadgesPage(),
            if (_showMoves) _buildMovesPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeBody() {
    final baseTopInset = AppTokens.contentTopInset + 50; // 180, includes all 3 cards minimized
    final expandedExtraHeight = _cardExpanded ? 155.0 : 0.0;
    final minimapExtraHeight = _minimapExpanded ? 240.0 : 0.0;
    final goalExtraHeight = _goalExpanded ? 60.0 : 0.0;
    final topInset = baseTopInset + expandedExtraHeight + minimapExtraHeight + goalExtraHeight;

    return Consumer<BuilderStateV3>(
      builder: (context, state, _) {
        return Stack(
          children: [
            Positioned.fill(child: Container(color: AppTokens.background)),
            Positioned.fill(
              child: Listener(
                onPointerDown: (_) => _dismissKeyboard(),
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (_) {
                    _dismissKeyboard();
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pageEdge,
                      topInset,
                      AppTokens.pageEdge,
                      AppTokens.contentBottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AttributeGroups(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: AppTokens.topScrimHeight,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppTokens.topScrim),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pageEdge,
                    AppTokens.topChromeInset,
                    AppTokens.pageEdge,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            OverallDisplay(
                              onExpandedChanged: _onCardExpandedChanged,
                            ),
                            const SizedBox(height: 8),
                            GoalCard(
                              onExpandedChanged: _onGoalExpandedChanged,
                            ),
                            const SizedBox(height: 8),
                            AttributeFloatingCard(
                              lockedAttributes: state.lockedAttributes,
                              onToggleLock: state.toggleAttributeLock,
                              onExpandedChanged: _onMinimapExpandedChanged,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: AppTokens.bottomScrimHeight + MediaQuery.of(context).padding.bottom,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppTokens.bottomScrim),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pageEdge,
                    12,
                    AppTokens.pageEdge,
                    0,
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      _buildPillButton(
                        label: 'Badges',
                        onTap: _openBadges,
                      ),
                      const SizedBox(width: 8),
                      _buildPillButton(
                        label: 'Moves',
                        onTap: _openMoves,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadgesPage() {
    return Positioned.fill(
      child: Container(
        color: AppTokens.background,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.pageEdge,
                  AppTokens.contentTopInset,
                  AppTokens.pageEdge,
                  AppTokens.contentBottomInset,
                ),
                child: const BadgePanel(),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: AppTokens.topScrimHeight,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppTokens.topScrim),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pageEdge,
                    AppTokens.topChromeInset,
                    AppTokens.pageEdge,
                    0,
                  ),
                  child: Row(
                    children: [
                      _buildPillButton(
                        icon: Icons.arrow_back_rounded,
                        label: '',
                        onTap: _closeBadges,
                      ),
                      const SizedBox(width: 8),
                      Text('Badges', style: AppTokens.pageTitle),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: AppTokens.bottomScrimHeight + MediaQuery.of(context).padding.bottom,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppTokens.bottomScrim),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovesPage() {
    return Positioned.fill(
      child: Container(
        color: AppTokens.background,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.pageEdge,
                  AppTokens.contentTopInset,
                  AppTokens.pageEdge,
                  AppTokens.contentBottomInset,
                ),
                child: AnimationPanel(),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: AppTokens.topScrimHeight,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppTokens.topScrim),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pageEdge,
                    AppTokens.topChromeInset,
                    AppTokens.pageEdge,
                    0,
                  ),
                  child: Row(
                    children: [
                      _buildPillButton(
                        icon: Icons.arrow_back_rounded,
                        label: '',
                        onTap: _closeMoves,
                      ),
                      const SizedBox(width: 8),
                      Text('Moves', style: AppTokens.pageTitle),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: AppTokens.bottomScrimHeight + MediaQuery.of(context).padding.bottom,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppTokens.bottomScrim),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillButton({
    IconData? icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    final foreground = highlight ? AppTokens.onPrimary : AppTokens.textPrimary;
    final background = highlight ? AppTokens.primary : AppTokens.surface;
    final borderColor = highlight ? AppTokens.primary : AppTokens.textSecondary;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(color: borderColor, width: 1),
      ),
      elevation: 2,
      shadowColor: AppTokens.buttonShadow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label.isNotEmpty ? 16 : 14,
            vertical: label.isNotEmpty ? 10 : 9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground),
                if (label.isNotEmpty) const SizedBox(width: 6),
              ],
              if (label.isNotEmpty)
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    fontFamily: AppTokens.fontFamily,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
