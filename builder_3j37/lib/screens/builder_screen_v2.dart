import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/services/builder_state_v3.dart';
import '../data/services/dataset_loader.dart';
import '../data/services/cap_breaker_engine.dart';
import '../data/services/build_storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/attribute_group.dart';
import '../widgets/badge_panel.dart';
import '../widgets/animation_panel.dart';
import '../widgets/overall_display.dart';
import '../widgets/goal_card.dart';
import '../widgets/myb_page.dart';
import '../widgets/myb_split_button.dart';
import 'dart:convert';
import '../extensions/context_extensions.dart';
import '../widgets/swipe_back_wrapper.dart';

class BuilderScreenV2 extends StatefulWidget {
  const BuilderScreenV2({super.key});

  @override
  State<BuilderScreenV2> createState() => _BuilderScreenV2State();
}

class _BuilderScreenV2State extends State<BuilderScreenV2> {
  bool _essentialLoading = true;
  bool _heavyLoading = true;
  bool _showBadges = false;
  bool _showMoves = false;
  bool _showMyB = false;
  String? _editingBuildName;
  bool _cardExpanded = true;
  bool _goalExpanded = false;
  final ScrollController _scrollController = ScrollController();
  
  // Cap breaker engine
  final CapBreakerEngine _cbEngine = CapBreakerEngine();

  // Reference to the current builder state for saving
  BuilderStateV3? _currentState;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Load saved builds
    BuildStorageService.instance.loadBuilds();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loader = DatasetLoader();
    
    // Load essential data
    await loader.loadEssential();
    
    // Load heavy data including cap breaker gains
    await loader.loadHeavy();
    
    // Initialize cap breaker engine before showing main UI
    await _initializeCapBreakerEngine();
    
    if (mounted) setState(() { _essentialLoading = false; _heavyLoading = false; });
  }

  Future<void> _initializeCapBreakerEngine() async {
    final loader = DatasetLoader();
    if (loader.modelWeights != null && loader.modelCurves != null) {
      CapBreakerEngine().loadModelData(loader.modelWeights!, loader.modelCurves!, overallScale: loader.modelOverallScale);
      debugPrint('[BuilderScreenV2] Cap breaker model loaded: ${loader.modelWeights!.length} weights');
    } else {
      debugPrint('[BuilderScreenV2] Warning: No model data, using fallback calculation');
    }
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

  /// Open MyB without saving current build
  void _openMyB() {
    setState(() => _showMyB = true);
  }

  /// Save current build then open MyB
  void _saveAndOpenMyB() {
    if (_currentState == null) return;
    // If editing a build, use update prefix
    debugPrint('[SaveBuild] _editingBuildName: $_editingBuildName');
    final saveName = _editingBuildName != null
        ? '${context.tr("update")}/${_editingBuildName}'
        : null;
    debugPrint('[SaveBuild] saveName: $saveName');
    BuildStorageService.instance.saveBuild(_currentState!, name: saveName).then((_) {
      if (mounted) {
        setState(() => _showMyB = true);
        // Show confirmation snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('build_saved'),
              style: TextStyle(
                fontFamily: AppTokens.fontFamily,
                color: AppTokens.textPrimary,
              ),
            ),
            backgroundColor: AppTokens.surface,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radius),
              side: BorderSide(color: AppTokens.cardBorder),
            ),
          ),
        );
      }
    });
  }

  void _closeMyB() {
    setState(() => _showMyB = false);
  }

  void _onCardExpandedChanged(bool expanded) {
    final oldExpanded = _cardExpanded;
    final offset = _scrollController.offset;
    final isAtTop = offset <= 0;
    
    if (!isAtTop && oldExpanded != expanded) {
      final adjustment = expanded ? 180.0 : -180.0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(offset + adjustment);
      }
    }
    
    setState(() {
      _cardExpanded = expanded;
    });
  }

  void _onGoalExpandedChanged(bool expanded) {
    final oldExpanded = _goalExpanded;
    final offset = _scrollController.offset;
    final isAtTop = offset <= 0;
    
    // Unfocus when collapsing to prevent keyboard auto-open
    if (!expanded && oldExpanded) {
      FocusScope.of(context).unfocus();
    }
    
    if (!isAtTop && oldExpanded != expanded) {
      final adjustment = expanded ? 200.0 : -200.0;
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

    final hasSubPage = _showBadges || _showMoves || _showMyB;
    return ChangeNotifierProvider(
      create: (_) => BuilderStateV3(),
      child: PopScope(
        canPop: !hasSubPage,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_showMyB) { _closeMyB(); return; }
          if (_showMoves) { _closeMoves(); return; }
          if (_showBadges) { _closeBadges(); return; }
        },
        child: Scaffold(
          backgroundColor: AppTokens.background,
          body: Consumer<BuilderStateV3>(
          builder: (context, state, _) {
            // Keep a reference for saving
            _currentState = state;
            return Stack(
              children: [
                _buildHomeBody(state),
                if (_showBadges) _buildBadgesPage(state),
                if (_showMoves) _buildMovesPage(),
                if (_showMyB) MyBPage(
                  onClose: _closeMyB,
                  onEditBuild: (name) { debugPrint('[EditBuild] Setting _editingBuildName: $name'); setState(() => _editingBuildName = name); },
                  onSwipeBack: _closeMyB,
                  builderState: state,
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildHomeBody(BuilderStateV3 state) {
    // Base inset accounts for SafeArea + OverallDisplay + buttons.
    // GoalCard minimized adds ~44px (36px card + 8px spacing).
    const goalCardMinHeight = 44.0;
    final baseTopInset = AppTokens.contentTopInset + goalCardMinHeight;
    final expandedExtraHeight = _cardExpanded ? 180.0 : 0.0;
    final goalExtraHeight = _goalExpanded ? 200.0 : 0.0;
    final topInset = baseTopInset + expandedExtraHeight + goalExtraHeight;

    return Stack(
      children: [
        Positioned.fill(child: Container(color: AppTokens.background)),
        Positioned.fill(
          child: Listener(
            onPointerDown: (_) => FocusScope.of(context).unfocus(),
            child: NotificationListener<UserScrollNotification>(
              onNotification: (_) => false,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(top: topInset),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        AttributeGroups(),
                        const SizedBox(height: 200),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Top gradient scrim
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
        // Top chrome: overall display + buttons
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Goal card (top)
                  GoalCard(
                    onExpandedChanged: _onGoalExpandedChanged,
                  ),
                  const SizedBox(height: 8),
                  // Body data card (OverallDisplay)
                  OverallDisplay(
                    onExpandedChanged: _onCardExpandedChanged,
                  ),
                  const SizedBox(height: 8),
                  // MyB split button / Badges / Moves pill buttons
                  Row(
                    children: [
                      // MyB split button (save ✓ | MyB)
                      MyBSplitButton(
                        onSaveAndOpen: _saveAndOpenMyB,
                        onOpen: _openMyB,
                      ),
                      const SizedBox(width: 8),
                      _buildPillButton(
                        label: context.tr('badges'),
                        onTap: _openBadges,
                      ),
                      const SizedBox(width: 8),
                      _buildPillButton(
                        label: context.tr('moves'),
                        onTap: _openMoves,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Bottom gradient scrim
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
    );
  }

  Widget _buildBadgesPage(BuilderStateV3 state) {
    return Positioned.fill(
      child: SwipeBackWrapper(
        onSwipeBack: _closeBadges,
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
                  child: BadgePanel(),
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
                        Text(context.tr('badges'), style: AppTokens.pageTitle),
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
      ),
    );
  }

  Widget _buildMovesPage() {
    return Positioned.fill(
      child: SwipeBackWrapper(
        onSwipeBack: _closeMoves,
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
                        Text(context.tr('moves'), style: AppTokens.pageTitle),
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
                    fontWeight: FontWeight.w800,
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
