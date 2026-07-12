import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Bottom sheet for backing up and restoring all data as copy/paste JSON.
///
/// Works entirely inside the WebView (no file download needed): the user copies
/// the backup text somewhere safe, and pastes it back to restore — e.g. before
/// the one-time reinstall that the stable signing key requires.
void showBackupSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BackupSheet(),
  );
}

class _BackupSheet extends StatefulWidget {
  const _BackupSheet();

  @override
  State<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<_BackupSheet> {
  final _restoreCtrl = TextEditingController();

  @override
  void dispose() {
    _restoreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final backup = app.exportJson();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
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
                Text('Backup & restore', style: displayStyle(size: 21)),
                const SizedBox(height: 6),
                const Text(
                  'Your tasks live only on this device. Copy this backup '
                  'somewhere safe (e.g. a note to yourself), and paste it back '
                  'to restore after reinstalling.',
                  style: TextStyle(
                      fontSize: 13.5, color: AppColors.muted, height: 1.45),
                ),

                // ---- Back up ----
                const SectionLabel('Your backup'),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line, width: 1),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      backup,
                      style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _BigButton(
                  label: 'Copy backup',
                  filled: true,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: backup));
                    if (context.mounted) {
                      Toast.show(context, 'Backup copied ✓');
                    }
                  },
                ),

                // ---- Restore ----
                const SectionLabel('Restore'),
                const Text(
                  'Paste a backup here and restore. This replaces everything '
                  'currently in the app.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _restoreCtrl,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Paste backup JSON…',
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _BigButton(
                  label: 'Restore from paste',
                  filled: false,
                  onTap: () => _confirmRestore(context, app),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRestore(BuildContext context, AppState app) async {
    final text = _restoreCtrl.text.trim();
    if (text.isEmpty) {
      Toast.show(context, 'Paste a backup first');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
            'This replaces all boards and tasks currently in the app with the '
            'pasted backup. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = await app.importJson(text);
    if (!context.mounted) return;
    if (success) {
      Navigator.pop(context);
      Toast.show(context, 'Restored ✓');
    } else {
      Toast.show(context, "That doesn't look like a valid backup");
    }
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _BigButton(
      {required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.ink : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label,
            style: TextStyle(
                color: filled ? Colors.white : AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
