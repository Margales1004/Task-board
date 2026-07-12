import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Settings sheet for "Browser capture" — pairs this app with the Chrome
/// extension via a Firebase Realtime Database URL and a secret code.
void showSyncSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SyncSheet(),
  );
}

class _SyncSheet extends StatefulWidget {
  const _SyncSheet();

  @override
  State<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends State<_SyncSheet> {
  late TextEditingController _dbUrl;
  late String _code;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _dbUrl = TextEditingController(text: app.syncDbUrl ?? '');
    _code = app.syncCode ?? app.newSyncCode();
  }

  @override
  void dispose() {
    _dbUrl.dispose();
    super.dispose();
  }

  void _save() {
    final app = context.read<AppState>();
    app.setSync(code: _code, dbUrl: _dbUrl.text);
    Navigator.pop(context);
    Toast.show(
        context, app.syncEnabled ? 'Browser capture on ✓' : 'Saved');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
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
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                Row(
                  children: [
                    Text('Browser capture', style: displayStyle(size: 21)),
                    const SizedBox(width: 8),
                    if (app.syncEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6EC),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text('Active',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3B7A43))),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Capture tasks from your computer: select text on any page, '
                  'right-click → "Add to My Boards", and it lands in your Inbox '
                  'board here. Paste the same database URL and code into the '
                  'Chrome extension to pair them.',
                  style: TextStyle(
                      fontSize: 13.5, color: AppColors.muted, height: 1.45),
                ),
                const SectionLabel('Firebase database URL'),
                TextField(
                  controller: _dbUrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://your-project-default-rtdb.firebaseio.com',
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
                const SectionLabel('Pairing code'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _code,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: _code));
                          if (context.mounted) Toast.show(context, 'Copied ✓');
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.copy, size: 18, color: AppColors.ink),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _code =
                            context.read<AppState>().newSyncCode()),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.refresh,
                              size: 20, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Keep this code secret — anyone who has it (and the URL) can '
                  'add tasks to your Inbox.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Text('Save',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                if (app.syncEnabled) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        context.read<AppState>().setSync(code: '', dbUrl: '');
                        Navigator.pop(context);
                        Toast.show(context, 'Browser capture off');
                      },
                      child: const Text('Turn off',
                          style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
