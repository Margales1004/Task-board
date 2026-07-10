import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String? _deleteArm;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final arch = app.archivedTasks
      ..sort((a, b) => (b.completedAt ?? '').compareTo(a.completedAt ?? ''));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 26, 2, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                arch.isEmpty
                    ? ''
                    : '${arch.length} archived task${arch.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text('Archive', style: displayStyle(size: 30)),
              const SizedBox(height: 4),
              const Text('Done and dusted — but still counted in your stats',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ),
        if (arch.isEmpty)
          const EmptyState(
            emoji: '🗄️',
            title: 'The archive is empty',
            body:
                "When tasks are completed, archive them from the board — they'll "
                'move here instead of cluttering your lists.',
          )
        else
          ...arch.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ArcRow(
                  task: t,
                  armed: _deleteArm == t.id,
                  onRestore: () {
                    app.restoreTask(t.id);
                    Toast.show(context, 'Restored to its board ↩️');
                  },
                  onDelete: () {
                    if (_deleteArm != t.id) {
                      setState(() => _deleteArm = t.id);
                      Toast.show(context, 'Tap again to delete forever');
                      return;
                    }
                    app.deleteTask(t.id);
                    setState(() => _deleteArm = null);
                    Toast.show(context, 'Deleted forever');
                  },
                ),
              )),
      ],
    );
  }
}

class _ArcRow extends StatelessWidget {
  final Task task;
  final bool armed;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  const _ArcRow({
    required this.task,
    required this.armed,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final b = app.boardById(task.boardId) ??
        Board(id: '', name: '(deleted board)', color: '#98A4B1');
    final color = AppColors.fromHex(b.color);

    final subParts = <String>[b.name];
    if (task.person != null && task.person!.isNotEmpty) subParts.add(task.person!);
    if (task.completedAt != null) subParts.add('done ${fmtDate(task.completedAt)}');

    return SoftCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AppColors.muted)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(right: 6),
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(subParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF98A4B1))),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _arcBtn(onRestore, const Icon(Icons.undo, size: 18)),
          const SizedBox(width: 8),
          _arcBtn(
            onDelete,
            Icon(armed ? Icons.error_outline : Icons.delete_outline,
                size: 18, color: AppColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _arcBtn(VoidCallback onTap, Widget child) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}
