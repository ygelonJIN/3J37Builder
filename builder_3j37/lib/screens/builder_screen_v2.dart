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
import '../widgets/cap_breakers_panel_v2.dart';
import 'dart:convert';

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
  bool _cardExpanded = true;
  final ScrollController _scrollController = ScrollController();
  
  // Cap breaker engine
  final CapBreakerEngine _cbEngine = CapBreakerEngine();

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
    
    // Load essential data
    await loader.loadEssential();
    if (mounted) setState(() => _essentialLoading = false);
    
    // Load heavy data including cap breaker gains
    await loader.loadHeavy();
    
    // Initialize cap breaker engine
    await _initializeCapBreakerEngine();
    
    if (mounted) setState(() => _heavyLoading = false);
  }

  Future<void> _initializeCapBreakerEngine() async {
    try {
      final data = await DefaultAssetBundle.of(context).loadString('assets/data/gains_by_rating.json');
      final jsonData = json.decode(data) as Map<String, dynamic>;
      final dataRows = (jsonData['data'] as List).cast<Map<String, dynamic>>();
      _cbEngine.initialize(dataRows);
      debugPrint('[BuilderScreenV2] Cap breaker engine initialized with ${dataRows.length} entries');
    } catch (e) {
      debugPrint('[BuilderScreenV2] Error initializing cap breaker engine: $e');
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
    final baseTopInset = AppTokens.contentTopInset;
    final expandedExtraHeight = _cardExpanded ? 180.0 : 0.0;
    final topInset = baseTopInset + expandedExtraHeight;

    return Consumer<BuilderStateV3>(
      builder: (context, state, _) {
        return Stack(
          children: [
            Positioned.fill(child: Container(color: AppTokens.background)),
            Positioned.fill(
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
                    const AttributeGroups(),
                    const SizedBox(height: 16),
                    const CapBreakersPanelV2(),
                  ],
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
                        child: OverallDisplay(
                          expanded: _cardExpanded,
                          onExpandedChanged: _onCardExpandedChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPillButton(
                        icon: Icons.shield_outlined,
                        label: 'Badges',
                        onTap: _openBadges,
                      ),
                      const SizedBox(width: 8),
                      _buildPillButton(
                        icon: Icons.sports_basketball_outlined,
                        label: 'Moves',
                        onTap: _openMoves,
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
    required IconData icon,
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
              Icon(icon, size: 16, color: foreground),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
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
            ],
          ),
        ),
      ),
    );
  }
}
