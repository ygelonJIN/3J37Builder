import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../extensions/context_extensions.dart';
import 'language_switch_button.dart';

class MoreExpandableButton extends StatefulWidget {
  final VoidCallback onSave;
  final VoidCallback onMyBuilds;
  final VoidCallback onMoves;
  final VoidCallback onBadges;

  const MoreExpandableButton({
    super.key,
    required this.onSave,
    required this.onMyBuilds,
    required this.onMoves,
    required this.onBadges,
  });

  @override
  State<MoreExpandableButton> createState() => MoreExpandableButtonState();
}

class MoreExpandableButtonState extends State<MoreExpandableButton>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _justToggled = false;
  late AnimationController _controller;
  late CurvedAnimation _expandAnimation;
  final GlobalKey _btnKey = GlobalKey();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTokens.animMedium,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppTokens.curveOut,
    );
    _expandAnimation.addListener(() => _overlay?.markNeedsBuild());
  }

  @override
  void dispose() {
    _removeOverlay();
    _expandAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void collapse() {
    if (_expanded && !_justToggled) {
      _expanded = false;
      _controller.reverse().whenComplete(_removeOverlay);
      setState(() {});
    }
  }

  bool get isExpanded => _expanded;

  void _toggle() {
    _justToggled = true;
    Future.delayed(const Duration(milliseconds: 400), () => _justToggled = false);
    _expanded = !_expanded;
    if (_expanded) {
      _showOverlay();
      _controller.forward();
    } else {
      _controller.reverse().whenComplete(_removeOverlay);
    }
    setState(() {});
  }

  void _onItemTap(VoidCallback cb) {
    _expanded = false;
    _controller.reverse().whenComplete(() {
      _removeOverlay();
      cb();
    });
    setState(() {});
  }

  // ── Overlay ────────────────────────────────────────────

  void _showOverlay() {
    _removeOverlay();
    _overlay = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildOverlay(BuildContext ctx) {
    final rb = _btnKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return const SizedBox.shrink();
    final sz = rb.size;
    final pos = rb.localToGlobal(Offset.zero);
    final v = _expandAnimation.value;
    if (v <= 0) return const SizedBox.shrink();

    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
          children: [
            // Tap-outside barrier
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _expanded = false;
                  _controller.reverse().whenComplete(_removeOverlay);
                  setState(() {});
                },
                behavior: HitTestBehavior.translucent,
              ),
            ),
            // Expanded items above More button (grows upward)
            Positioned(
              right: MediaQuery.of(ctx).size.width - pos.dx - sz.width,
              bottom: MediaQuery.of(ctx).size.height - pos.dy + 8,
              child: IgnorePointer(
                ignoring: v < 0.3,
                child: Opacity(
                  opacity: v,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const LanguageSwitchButton(),
                      const SizedBox(height: 8),
                      _menuItem(
                        label: ctx.tr('my_builds'),
                        onTap: () => _onItemTap(widget.onMyBuilds),
                        highlight: true,
                      ),
                      const SizedBox(height: 8),
                      _menuItem(
                        label: ctx.tr('save'),
                        onTap: () => _onItemTap(widget.onSave),
                        highlight: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Moves + Badges (grows leftward from More button)
            Positioned(
              right: MediaQuery.of(ctx).size.width - pos.dx + 8,
              bottom: MediaQuery.of(ctx).size.height - pos.dy - sz.height,
              child: IgnorePointer(
                ignoring: v < 0.3,
                child: Opacity(
                  opacity: v,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _menuItem(
                        label: ctx.tr('moves'),
                        onTap: () => _onItemTap(widget.onMoves),
                      ),
                      const SizedBox(width: 8),
                      _menuItem(
                        label: ctx.tr('badges'),
                        onTap: () => _onItemTap(widget.onBadges),
                      ),
                    ],
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

  Widget _menuItem({
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    final bg = highlight ? AppTokens.surfaceAlt : AppTokens.surface;
    final bc = highlight ? AppTokens.primary : AppTokens.textSecondary;
    final tc = highlight ? AppTokens.primary : AppTokens.textPrimary;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(color: bc, width: 1),
      ),
      elevation: 4,
      shadowColor: AppTokens.buttonShadow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: tc,
              fontFamily: AppTokens.fontFamily,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      key: _btnKey,
      color: _expanded ? AppTokens.primary : AppTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(
          color: _expanded ? AppTokens.primary : AppTokens.textSecondary,
          width: 1,
        ),
      ),
      elevation: 2,
      shadowColor: AppTokens.buttonShadow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('more'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _expanded ? AppTokens.onPrimary : AppTokens.textPrimary,
                  fontFamily: AppTokens.fontFamily,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: AppTokens.animMedium,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: _expanded ? AppTokens.onPrimary : AppTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
