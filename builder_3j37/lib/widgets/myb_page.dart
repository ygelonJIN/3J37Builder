import 'package:flutter/material.dart';
import '../data/models/build_save.dart';
import '../data/services/build_storage_service.dart';
import '../data/services/builder_state_v3.dart';
import '../theme/app_tokens.dart';
import 'center_dialog.dart';

class MyBPage extends StatefulWidget {
  final VoidCallback onClose;
  final BuilderStateV3 builderState;

  const MyBPage({
    super.key,
    required this.onClose,
    required this.builderState,
  });

  @override
  State<MyBPage> createState() => _MyBPageState();
}

class _MyBPageState extends State<MyBPage> {
  final BuildStorageService _storage = BuildStorageService.instance;
  String? _editingId;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _storage.addListener(_onStorageChanged);
  }

  @override
  void dispose() {
    _editController.dispose();
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
            Text('Delete Build', style: AppTokens.cardTitleStyle),
            const SizedBox(height: 12),
            Text(
              'Delete "${entry.name}"?',
              style: AppTokens.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDialogButton(
                  label: 'Cancel',
                  color: AppTokens.textSecondary,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                _buildDialogButton(
                  label: 'Delete',
                  color: Colors.red,
                  onTap: () {
                    _storage.deleteBuild(entry.id);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  void _loadBuild(BuildSave entry) {
    _storage.applyBuild(entry, widget.builderState);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _storage.builds;

    return Positioned.fill(
      child: Container(
        color: AppTokens.background,
        child: Stack(
          children: [
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
                        children: [
                          ...entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _BuildRow(
                              entry: entry,
                              isEditing: _editingId == entry.id,
                              editController: _editController,
                              onStartEdit: () => _startEditing(entry),
                              onFinishEdit: _finishEditing,
                              onTap: () => _loadBuild(entry),
                              onDelete: () => _deleteBuild(entry),
                            ),
                          )),
                        ],
                      ),
                    ),
            ),
            // Top gradient scrim
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
                  child: Row(
                    children: [
                      _buildPillButton(
                        icon: Icons.arrow_back_rounded,
                        label: '',
                        onTap: widget.onClose,
                      ),
                      const SizedBox(width: 8),
                      Text('MyB', style: AppTokens.pageTitle),
                      const SizedBox(width: 12),
                      Text('${entries.length} builds', style: AppTokens.caption),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom gradient scrim
            Positioned(
              bottom: 0, left: 0, right: 0,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: AppTokens.keyOff),
          const SizedBox(height: 16),
          Text(
            'No Saved Builds',
            style: TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text('Tap ✓ to save your current build', style: AppTokens.caption),
        ],
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
                Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: foreground, fontFamily: AppTokens.fontFamily)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single build row in the MyB list
class _BuildRow extends StatelessWidget {
  final BuildSave entry;
  final bool isEditing;
  final TextEditingController editController;
  final VoidCallback onStartEdit;
  final VoidCallback onFinishEdit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BuildRow({
    required this.entry,
    required this.isEditing,
    required this.editController,
    required this.onStartEdit,
    required this.onFinishEdit,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(color: AppTokens.cardBorder, width: 1),
      ),
      elevation: 1,
      shadowColor: AppTokens.buttonShadow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEditing ? null : onTap,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name row
              isEditing
                  ? _buildNameEditor()
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name,
                            style: TextStyle(
                              fontFamily: AppTokens.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Rename button (bigger)
                        GestureDetector(
                          onTap: onStartEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTokens.surface,
                              borderRadius: BorderRadius.circular(AppTokens.radius),
                              border: Border.all(color: AppTokens.textSecondary.withValues(alpha: 0.4), width: 1),
                            ),
                            child: Text(
                              'Rename',
                              style: TextStyle(
                                fontFamily: AppTokens.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTokens.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Delete button (bigger, right side)
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTokens.surface,
                              borderRadius: BorderRadius.circular(AppTokens.radius),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1),
                            ),
                            child: Text(
                              'Delete',
                              style: TextStyle(
                                fontFamily: AppTokens.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 6),
              // Body data line - matching OverallDisplay style
              Text(
                entry.subtitleLine,
                style: TextStyle(
                  fontFamily: AppTokens.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                  color: AppTokens.primary,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameEditor() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: editController,
            autofocus: true,
            style: TextStyle(
              fontFamily: AppTokens.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTokens.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              filled: true,
              fillColor: AppTokens.surface,
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
        GestureDetector(
          onTap: onFinishEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTokens.primary,
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
            child: Text(
              'Done',
              style: TextStyle(
                fontFamily: AppTokens.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTokens.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
