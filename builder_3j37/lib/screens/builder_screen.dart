import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
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
import '../data/services/build_storage_service.dart';
import '../widgets/myb_page.dart';
import '../widgets/myb_split_button.dart';
import '../widgets/more_expandable_button.dart';
import '../extensions/context_extensions.dart';
import '../widgets/swipe_back_wrapper.dart';

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
  bool _showMyB = false;
  String? _editingBuildName;
  BuilderStateV3? _currentState;
  bool _cardExpanded = false;
  bool _minimapExpanded = false;
  bool _goalExpanded = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<MoreExpandableButtonState> _moreButtonKey = GlobalKey<MoreExpandableButtonState>();
  bool _isWide = false;

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
    BuildStorageService.instance.loadBuilds();
  }

  void _onScroll() {
    _moreButtonKey.currentState?.collapse();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loader = DatasetLoader();
    await loader.loadEssential();
    await loader.loadHeavy();
    // Load model into cap breaker engine before showing main UI
    if (loader.modelWeights != null && loader.modelCurves != null) {
      CapBreakerEngine().loadModelData(loader.modelWeights!, loader.modelCurves!, overallScale: loader.modelOverallScale);
      debugPrint('[BuilderScreen] Cap breaker model loaded: ${loader.modelWeights!.length} weights, ${loader.modelCurves!.length} curves');
    }
    if (mounted) setState(() { _essentialLoading = false; _heavyLoading = false; });
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

  void _openMyB() {
    setState(() => _showMyB = true);
  }

  void _saveBuild() {
    if (_currentState == null) return;
    BuildStorageService.instance.saveBuild(_currentState!);
  }

  void _saveAndOpenMyB() {
    if (_currentState == null) return;
    debugPrint('[SaveBuild] _editingBuildName: $_editingBuildName');
    final saveName = _editingBuildName != null
        ? '${context.tr("update")}/${_editingBuildName}'
        : null;
    debugPrint('[SaveBuild] saveName: $saveName');
    BuildStorageService.instance.saveBuild(_currentState!, name: saveName).then((_) {
      if (mounted) setState(() => _showMyB = true);
    });
  }

  void _closeMyB() {
    setState(() => _showMyB = false);
  }

  void _onCardExpandedChanged(bool expanded) {
    final oldExpanded = _cardExpanded;
    setState(() => _cardExpanded = expanded);
    if (_isWide) return; // wide mode: don't adjust left scroll
    final offset = _scrollController.offset;
    final isAtTop = offset <= 0;
    if (!isAtTop && oldExpanded != expanded) {
      final adjustment = expanded ? 155.0 : -155.0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(offset + adjustment);
      }
    }
  }

  void _onMinimapExpandedChanged(bool expanded) {
    final oldExpanded = _minimapExpanded;
    setState(() => _minimapExpanded = expanded);
    if (_isWide) return;
    final offset = _scrollController.offset;
    final isAtTop = offset <= 0;
    if (!isAtTop && oldExpanded != expanded) {
      final adjustment = expanded ? 260.0 : -260.0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(offset + adjustment);
      }
    }
  }

  void _onGoalExpandedChanged(bool expanded) {
    final oldExpanded = _goalExpanded;
    setState(() => _goalExpanded = expanded);
    if (_isWide) return;
    final offset = _scrollController.offset;
    final isAtTop = offset <= 0;
    if (!isAtTop && oldExpanded != expanded) {
      final adjustment = expanded ? 60.0 : -60.0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(offset + adjustment);
      }
    }
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
      ),
    );
  }

  Widget _buildHomeBody() {
    // Platform-specific top spacing (adjust these values per platform)
    final double platformTopOffset;
    if (kIsWeb) {
      platformTopOffset = 0.0; // Web
    } else if (Platform.isIOS) {
      platformTopOffset = 50.0; // iOS
    } else {
      platformTopOffset = 20.0; // Android
    }
    final baseTopInset = AppTokens.contentTopInset + platformTopOffset;
    final expandedExtraHeight = _cardExpanded ? 155.0 : 0.0;
    final minimapExtraHeight = _minimapExpanded ? 260.0 : 0.0;
    final goalExtraHeight = _goalExpanded ? 60.0 : 0.0;
    final topInset = baseTopInset + expandedExtraHeight + minimapExtraHeight + goalExtraHeight;

    return Consumer<BuilderStateV3>(
      builder: (context, state, _) {
        _currentState = state;

        // The scrollable attribute list (narrow mode uses topInset, wide mode uses0)
        Widget buildAttributeScroll(double topPadding) => Listener(
          onPointerDown: (_) {
            _dismissKeyboard();
            _moreButtonKey.currentState?.collapse();
          },
          child: NotificationListener<UserScrollNotification>(
            onNotification: (_) {
              _dismissKeyboard();
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                AppTokens.pageEdge,
                topPadding,
                AppTokens.pageEdge,
                AppTokens.contentBottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [AttributeGroups()],
              ),
            ),
          ),
        );
        final attributeScroll = buildAttributeScroll(topInset);

        // Bottom "More" button
        Widget moreButton = Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppTokens.pageEdge, 12, AppTokens.pageEdge, 20),
              child: Row(
                children: [
                  const Spacer(),
                  MoreExpandableButton(
                    key: _moreButtonKey,
                    onSave: _saveAndOpenMyB,
                    onMyBuilds: _openMyB,
                    onMoves: _openMoves,
                    onBadges: _openBadges,
                  ),
                ],
              ),
            ),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            _isWide = isWide;

            // The 3 top cards widget (created here so _isWide is set)
            final cardSpacing = isWide ? 16.0 : 8.0;
            final fontOffset = isWide ? 2.0 : 0.0;
            Widget threeCards = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OverallDisplay(onExpandedChanged: _onCardExpandedChanged, initialExpanded: isWide, fontSizeOffset: fontOffset),
                SizedBox(height: cardSpacing),
                GoalCard(onExpandedChanged: _onGoalExpandedChanged, initialExpanded: isWide, removeMaxHeight: isWide, fontSizeOffset: fontOffset),
                SizedBox(height: cardSpacing),
                AttributeFloatingCard(
                  lockedAttributes: state.lockedAttributes,
                  onToggleLock: state.toggleAttributeLock,
                  onExpandedChanged: _onMinimapExpandedChanged,
                  initialExpanded: isWide,
                  fontSizeOffset: fontOffset,
                ),
              ],
            );

            if (isWide) {
              // WIDE: left half = attributes + more button, right half = 3 cards only
              final ovr = state.overallRating;
              final loader = DatasetLoader();
              final preciseOvr = loader.getOvr(state.position, state.heightInches, state.baseRatings);

              // Minimap OVR display for wide mode (matches AttributeFloatingCard style)
              Widget minimapButton = RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$ovr',
                      style: AppTokens.brandMark.copyWith(fontSize: 23, letterSpacing: 0),
                    ),
                    TextSpan(
                      text: ' (${preciseOvr.toStringAsFixed(1)})',
                      style: TextStyle(
                        fontFamily: AppTokens.fontFamily,
                        fontSize: 14,
                        color: AppTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              );

              // Wide mode more button with minimap to its left
              Widget wideMoreButton = Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(AppTokens.pageEdge, 12, AppTokens.pageEdge, 20),
                    child: Row(
                      children: [
                        const Spacer(),
                        minimapButton,
                        const SizedBox(width: 8),
                        MoreExpandableButton(
                          key: _moreButtonKey,
                          onSave: _saveAndOpenMyB,
                          onMyBuilds: _openMyB,
                          onMoves: _openMoves,
                          onBadges: _openBadges,
                        ),
                      ],
                    ),
                  ),
                ),
              );

              return Stack(
                children: [
                  Positioned.fill(child: Container(color: AppTokens.background)),
                  // Left-right split
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT half: attributes + more button, no top scrim
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(child: buildAttributeScroll(0)),
                              // Bottom scrim only (no top scrim in wide mode)
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: IgnorePointer(
                                  child: SizedBox(
                                    height: AppTokens.bottomScrimHeight + MediaQuery.of(context).padding.bottom,
                                    child: const DecoratedBox(decoration: BoxDecoration(gradient: AppTokens.bottomScrim)),
                                  ),
                                ),
                              ),
                              // More button with minimap
                              wideMoreButton,
                            ],
                          ),
                        ),
                        // RIGHT half: scrollable 3 cards, no top scrim
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(child: Container(color: AppTokens.background)),
                              // Scrollable cards - with top spacing
                              Positioned.fill(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.fromLTRB(
                                    AppTokens.pageEdge,
                                    AppTokens.topChromeInset,
                                    AppTokens.pageEdge,
                                    AppTokens.contentBottomInset,
                                  ),
                                  child: threeCards,
                                ),
                              ),
                              // Bottom scrim only
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: IgnorePointer(
                                  child: SizedBox(
                                    height: AppTokens.bottomScrimHeight + MediaQuery.of(context).padding.bottom,
                                    child: const DecoratedBox(decoration: BoxDecoration(gradient: AppTokens.bottomScrim)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // MyB page overlay
                  if (_showMyB) MyBPage(
                    onClose: _closeMyB,
                    onEditBuild: (name) { debugPrint('[EditBuild] Setting _editingBuildName: $name'); setState(() => _editingBuildName = name); },
                    onSwipeBack: _closeMyB,
                    builderState: state,
                  ),
                ],
              );
            }

            // NARROW: original layout
            return Stack(
              children: [
                Positioned.fill(child: Container(color: AppTokens.background)),
                Positioned.fill(child: attributeScroll),
                // Top gradient scrim
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: IgnorePointer(
                    child: SizedBox(
                      height: AppTokens.topScrimHeight,
                      child: const DecoratedBox(decoration: BoxDecoration(gradient: AppTokens.topScrim)),
                    ),
                  ),
                ),
                // 3 cards at top
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(AppTokens.pageEdge, AppTokens.topChromeInset, AppTokens.pageEdge, 0),
                      child: threeCards,
                    ),
                  ),
                ),
                // Bottom gradient scrim
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: IgnorePointer(
                    child: SizedBox(
                      height: AppTokens.bottomScrimHeight + MediaQuery.of(context).padding.bottom,
                      child: const DecoratedBox(decoration: BoxDecoration(gradient: AppTokens.bottomScrim)),
                    ),
                  ),
                ),
                // MyB page overlay
                if (_showMyB) MyBPage(
                  onClose: _closeMyB,
                  onEditBuild: (name) { debugPrint('[EditBuild] Setting _editingBuildName: $name'); setState(() => _editingBuildName = name); },
                  onSwipeBack: _closeMyB,
                  builderState: state,
                ),
                // More button
                if (!_showMyB) moreButton,
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBadgesPage() {
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
            horizontal: label.isNotEmpty ? 12 : 14,
            vertical: label.isNotEmpty ? 7 : 9,
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
                    fontWeight: FontWeight.w400,
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
