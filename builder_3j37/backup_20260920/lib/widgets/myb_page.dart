import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../data/models/build_save.dart';
import '../data/services/build_storage_service.dart';
import '../data/services/builder_state_v3.dart';
import '../theme/app_tokens.dart';
import 'center_dialog.dart';
import 'share_build_card.dart';
import 'swipe_back_wrapper.dart';
import '../extensions/context_extensions.dart';

class MyBPage extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onSwipeBack;
  final BuilderStateV3 builderState;
  final void Function(String buildName)? onEditBuild;

  const MyBPage({
    super.key,
    required this.onClose,
    this.onSwipeBack,
    required this.builderState,
    this.onEditBuild,
  });

  @override
  State<MyBPage> createState() => _MyBPageState();
}

class _MyBPageState extends State<MyBPage> {
  final BuildStorageService _storage = BuildStorageService.instance;
  String? _editingId;
  late TextEditingController _editController;
  late TextEditingController _importController;

  GlobalKey _shareCardKey = GlobalKey();
  bool _isCapturing = false;
  BuildSave? _shareTargetBuild;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _importController = TextEditingController();
    _storage.addListener(_onStorageChanged);
  }

  @override
  void dispose() {
    _editController.dispose();
    _importController.dispose();
    _storage.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _onStorageChanged() {
    if (mounted) setState(() {});
  }

  void _startEditing(BuildSave entry) {
    setState(() {
      _editingId = entry.id;
      _editController.text = entry.name;
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: entry.name.length,
      );
    });
  }

  void _finishEditing() {
    if (_editingId != null && _editController.text.trim().isNotEmpty) {
      _storage.renameBuild(_editingId!, _editController.text.trim());
    }
    setState(() => _editingId = null);
  }

  void _deleteBuild(BuildSave entry) {
    CenterDialog.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('delete_build'), style: AppTokens.cardTitleStyle),
            const SizedBox(height: 12),
            Text('${context.tr("delete_build")} ${entry.name}?', style: AppTokens.body, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDialogButton(label: context.tr('cancel'), color: AppTokens.textSecondary, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                _buildDialogButton(label: context.tr('delete'), color: Colors.red, onTap: () {
                  _storage.deleteBuild(entry.id);
                  Navigator.pop(context);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogButton({required String label, required Color color, required VoidCallback onTap}) {
    return Material(type: MaterialType.transparency, child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 13,
          fontWeight: FontWeight.w800, color: color,
        )),
      ),
    ));
  }

  void _loadBuild(BuildSave entry) {
    _storage.applyBuild(entry, widget.builderState);
    // Notify parent about the source build for update naming
    widget.onEditBuild?.call(entry.name);
    widget.onClose();
  }

  // ── Share Options Dialog ──────────────────────────────────

  void _showShareOptions(BuildSave entry) {
    CenterDialog.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('share'), style: AppTokens.cardTitleStyle),
            const SizedBox(height: 20),
            _buildGoldButton(
              label: context.tr('save_image'),
              onTap: () {
                Navigator.pop(context);
                _saveImage(entry);
              },
            ),
            const SizedBox(height: 10),
            _buildGoldButton(
              label: context.tr('export_code'),
              onTap: () {
                Navigator.pop(context);
                _exportCode(entry);
              },
            ),
            const SizedBox(height: 16),
            Material(type: MaterialType.transparency, child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(context.tr('cancel'), style: TextStyle(
                  fontFamily: AppTokens.fontFamily, fontSize: 13,
                  fontWeight: FontWeight.w600, color: AppTokens.keyOff,
                )),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldButton({required String label, required VoidCallback onTap}) {
    return Material(type: MaterialType.transparency, child: InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTokens.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: AppTokens.primary.withValues(alpha: 0.3), width: 1),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 14,
          fontWeight: FontWeight.w700, color: AppTokens.primary,
        )),
      ),
    ));
  }

  // ── Save Image → Gallery ──────────────────────────────────

  Future<void> _saveImage(BuildSave entry) async {
    if (_isCapturing) return;
    _shareCardKey = GlobalKey();
    setState(() {
      _isCapturing = true;
      _shareTargetBuild = entry;
    });

    _storage.applyBuild(entry, widget.builderState);
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final bytes = await ShareBuildCard.capture(_shareCardKey);
      if (bytes == null) {
        _showResultDialog(false, context.tr('failed_to_generate_image'));
        return;
      }

      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: '3J37_${entry.name.replaceAll(' ', '_')}',
      );

      final isSuccess = result != null && (result['isSuccess'] == true || result['success'] == true);
      _showResultDialog(isSuccess, isSuccess ? context.tr('saved_to_gallery') : context.tr('please_check_gallery'));
    } catch (e) {
      debugPrint('Share error: $e');
      _showResultDialog(false, e.toString());
    } finally {
      setState(() {
        _isCapturing = false;
        _shareTargetBuild = null;
      });
    }
  }

  // ── Export Code to Clipboard ──────────────────────────────

  void _exportCode(BuildSave entry) {
    final jsonStr = entry.toJsonString();
    Clipboard.setData(ClipboardData(text: jsonStr));
    _showResultDialog(true, context.tr('code_copied'));
  }

  // ── Import Build from Code ────────────────────────────────

  void _showImportDialog() {
    _importController.clear();
    CenterDialog.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('import_build'), style: AppTokens.cardTitleStyle),
            const SizedBox(height: 16),
            TextField(
              controller: _importController,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 11,
                color: AppTokens.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: context.tr('paste_code_here'),
                hintStyle: TextStyle(
                  fontFamily: AppTokens.fontFamily, fontSize: 12,
                  color: AppTokens.keyOff,
                ),
                filled: true,
                fillColor: AppTokens.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  borderSide: BorderSide(color: AppTokens.primary.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  borderSide: BorderSide(color: AppTokens.primary.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  borderSide: BorderSide(color: AppTokens.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDialogButton(label: context.tr('cancel'), color: AppTokens.textSecondary, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                _buildDialogButton(label: context.tr('import'), color: AppTokens.primary, onTap: _handleImport),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImport() async {
    final code = _importController.text.trim();
    if (code.isEmpty) return;

    Navigator.pop(context);
    final build = await _storage.importBuildFromJsonString(code);
    if (build != null) {
      if (mounted) setState(() {});
      _showResultDialog(true, '${context.tr('import_success')}: ${build.name}');
    } else {
      _showResultDialog(false, context.tr('import_failed'));
    }
  }

  void _showResultDialog(bool success, String? errorDetail) {
    CenterDialog.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (success ? AppTokens.primary : Colors.red).withValues(alpha: 0.15),
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.close_rounded,
                size: 32,
                color: success ? AppTokens.primary : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            // Title
 Text(
              errorDetail ?? (success ? context.tr('success') : context.tr('failed')),
              style: TextStyle(
                fontFamily: AppTokens.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTokens.textPrimary,
              ),
            ),
            if (errorDetail != null) ...[
              const SizedBox(height: 8),
              Text(
                errorDetail,
                style: TextStyle(
                  fontFamily: AppTokens.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Material(type: MaterialType.transparency, child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTokens.primary,
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                ),
                child: Center(
                  child: Text(context.tr('ok'), style: TextStyle(
                    fontFamily: AppTokens.fontFamily, fontSize: 14,
                    fontWeight: FontWeight.w800, color: AppTokens.onPrimary,
                  )),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ── Build UI ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final entries = _storage.builds;

    final content = Container(
      color: AppTokens.background,
      child: Stack(
        children: [
          // Offscreen share card (hidden, for capture)
          if (_shareTargetBuild != null)
            Positioned(
              left: -9999, top: -9999,
              child: ShareBuildCard(
                key: _shareCardKey,
                buildName: _shareTargetBuild?.name,
                state: widget.builderState,
                repaintKey: _shareCardKey,
                textScaleFactor: ShareBuildCard.getPlatformTextScaleFactor(),
              ),
            ),

          Positioned.fill(
            child: entries.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pageEdge,
                      AppTokens.contentTopInset,
                      AppTokens.pageEdge,
                      AppTokens.contentBottomInset,
                    ),
                    child: Column(
                      children: entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BuildRow(
                          entry: e,
                          isEditing: _editingId == e.id,
                          editController: _editController,
                          onStartEdit: () => _startEditing(e),
                          onFinishEdit: _finishEditing,
                          onTap: () => _loadBuild(e),
                          onDelete: () => _deleteBuild(e),
                          onShare: () => _showShareOptions(e),
                          isCapturing: _isCapturing && _shareTargetBuild?.id == e.id,
                        ),
                      )).toList(),
                    ),
                  ),
          ),

          // Top scrim
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: AppTokens.topScrimHeight,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppTokens.topScrim),
                ),
              ),
            ),
          ),

          // Bottom scrim
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: AppTokens.bottomScrimHeight,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppTokens.bottomScrim),
                ),
              ),
            ),
          ),

          // Top chrome
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.pageEdge,
                  AppTokens.topChromeInset,
                  AppTokens.pageEdge,
                  0,
                ),
                child: Row(children: [
                  _buildPillButton(icon: Icons.arrow_back_rounded, onTap: widget.onClose),
                  const SizedBox(width: 12),
                  Text(context.tr('my_builds'), style: AppTokens.pageTitle),
                ]),
              ),
            ),
          ),

          // Import button
          Positioned(
            bottom: 20,
            right: AppTokens.pageEdge,
            child: SafeArea(
              top: false,
              child: Material(
                color: AppTokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  side: BorderSide(color: AppTokens.textSecondary, width: 1),
                ),
                elevation: 2,
                shadowColor: AppTokens.buttonShadow,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _showImportDialog,
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.tr('import_build'), style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.textPrimary,
                          fontFamily: AppTokens.fontFamily,
                          decoration: TextDecoration.none,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Positioned.fill(
      child: widget.onSwipeBack != null
          ? SwipeBackWrapper(onSwipeBack: widget.onSwipeBack!, child: content)
          : content,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 48, color: AppTokens.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(context.tr('no_saved_builds'), style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 16,
            fontWeight: FontWeight.w800, color: AppTokens.textSecondary,
          )),
          const SizedBox(height: 8),
          Text(context.tr('save_a_build_to_see_it_here'), style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 13,
            fontWeight: FontWeight.w800, color: AppTokens.textSecondary.withValues(alpha: 0.6),
          )),
        ],
      ),
    );
  }

  Widget _buildPillButton({required IconData icon, required VoidCallback onTap}) {
    return Material(type: MaterialType.transparency, child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: AppTokens.primary.withValues(alpha: 0.3), width: 1),
        ),
        child: Icon(icon, size: 20, color: AppTokens.primary),
      ),
    ));
  }
}

// ── Build Row ───────────────────────────────────────────────
// Layout:
//   [Name + subtitle]
//   [Share] [Rename]        [Delete]

class _BuildRow extends StatelessWidget {
  final BuildSave entry;
  final bool isEditing;
  final TextEditingController editController;
  final VoidCallback onStartEdit;
  final VoidCallback onFinishEdit;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final bool isCapturing;

  const _BuildRow({
    required this.entry,
    required this.isEditing,
    required this.editController,
    required this.onStartEdit,
    required this.onFinishEdit,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
    required this.isCapturing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(type: MaterialType.transparency, child: InkWell(
      onTap: null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: AppTokens.primary.withValues(alpha: 0.2), width: 1),
        ),
        child: isEditing ? _buildNameEditor(context) : _buildContent(context),
      ),
    ));
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.name, style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 15,
          fontWeight: FontWeight.w800, color: AppTokens.textPrimary,
        ), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(entry.subtitleLine, style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 10,
          fontWeight: FontWeight.w500, color: AppTokens.primary, letterSpacing: 0.2,
        ), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildTextButton(
              label: context.tr('edit'),
              color: AppTokens.textSecondary,
              onTap: onTap,
            ),
            const SizedBox(width: 6),
            _buildTextButton(
              label: isCapturing ? '...' : context.tr('share'),
              color: AppTokens.primary,
              onTap: isCapturing ? null : onShare,
            ),
            const SizedBox(width: 6),
            _buildTextButton(
              label: context.tr('rename'),
              color: AppTokens.textSecondary,
              onTap: onStartEdit,
            ),
            const Spacer(),
            _buildTextButton(
              label: context.tr('delete'),
              color: Colors.red,
              onTap: onDelete,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(type: MaterialType.transparency, child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: AppTokens.fontFamily, fontSize: 11,
          fontWeight: FontWeight.w700, color: color,
        )),
      ),
    ));
  }

  Widget _buildNameEditor(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: editController,
          autofocus: true,
          style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 15,
            fontWeight: FontWeight.w800, color: AppTokens.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            filled: true,
            fillColor: AppTokens.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radius),
              borderSide: BorderSide(color: AppTokens.primary, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radius),
              borderSide: BorderSide(color: AppTokens.primary, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radius),
              borderSide: BorderSide(color: AppTokens.primary, width: 1.5),
            ),
          ),
          onSubmitted: (_) => onFinishEdit(),
          onTapOutside: (_) => onFinishEdit(),
        ),
      ),
      const SizedBox(width: 8),
      Material(type: MaterialType.transparency, child: InkWell(
        onTap: onFinishEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTokens.primary,
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          child: Text(context.tr('done'), style: TextStyle(
            fontFamily: AppTokens.fontFamily, fontSize: 13,
            fontWeight: FontWeight.w800, color: AppTokens.onPrimary,
          )),
        ),
      )),
    ]);
  }
}
