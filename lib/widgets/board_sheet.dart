import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Bottom sheet to create or edit a board. Pass [boardId] to edit.
Future<void> showBoardSheet(BuildContext context, {String? boardId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x7316222F),
    builder: (_) => _BoardSheet(boardId: boardId),
  );
}

class _BoardSheet extends StatefulWidget {
  final String? boardId;
  const _BoardSheet({this.boardId});

  @override
  State<_BoardSheet> createState() => _BoardSheetState();
}

class _BoardSheetState extends State<_BoardSheet> {
  late TextEditingController _name;
  late Color _color;
  bool _deleteArmed = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final b = widget.boardId != null ? app.boardById(widget.boardId) : null;
    _name = TextEditingController(text: b?.name ?? '');
    _color = b != null
        ? AppColors.fromHex(b.color)
        : AppColors.boardPalette[app.boards.length % AppColors.boardPalette.length];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final app = context.read<AppState>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      Toast.show(context, 'The board needs a name');
      return;
    }
    app.saveBoard(id: widget.boardId, name: name, color: AppColors.toHex(_color));
    Navigator.of(context).pop();
    Toast.show(context, 'Saved');
  }

  void _delete() {
    if (!_deleteArmed) {
      setState(() => _deleteArmed = true);
      return;
    }
    final app = context.read<AppState>();
    app.deleteBoard(widget.boardId!);
    Navigator.of(context).pop();
    Toast.show(context, 'Board deleted');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.boardId != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: _SheetShell(
        title: isEdit ? 'Edit board' : 'New board',
        children: [
          _Field(
            label: 'Board name',
            child: TextField(
              controller: _name,
              autofocus: !isEdit,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration('e.g. Work, Home, Event planning'),
            ),
          ),
          _Field(
            label: 'Color',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppColors.boardPalette.map((c) {
                final sel = c.toARGB32() == _color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: AnimatedScale(
                    scale: sel ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? AppColors.ink : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          _SheetActions(onCancel: () => Navigator.pop(context), onSave: _save),
          if (isEdit)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: TextButton(
                  onPressed: _delete,
                  child: Text(
                    _deleteArmed
                        ? 'Sure? Tap again to delete permanently'
                        : 'Delete this board and all its tasks',
                    style: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------ shared sheet building blocks (used by task_sheet too) ------------

class _SheetShell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SheetShell({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(title, style: displayStyle(size: 21)),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
          ),
          child,
        ],
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  const _SheetActions({required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    ButtonStyle base(Color bg, Color fg) => ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(bg),
          foregroundColor: WidgetStatePropertyAll(fg),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 15)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14))),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: base(AppColors.bg, AppColors.muted),
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: base(AppColors.ink, Colors.white),
              onPressed: onSave,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    counterText: '',
    filled: true,
    fillColor: AppColors.bg,
    hintStyle: const TextStyle(color: AppColors.muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.ink),
    border: border(AppColors.line),
  );
}

/// Exposed for task_sheet to reuse the same styling primitives.
class SheetKit {
  static Widget shell(String title, List<Widget> children) =>
      _SheetShell(title: title, children: children);
  static Widget field(String label, Widget child) =>
      _Field(label: label, child: child);
  static Widget actions(VoidCallback cancel, VoidCallback save) =>
      _SheetActions(onCancel: cancel, onSave: save);
  static InputDecoration input(String hint) => _inputDecoration(hint);
}
