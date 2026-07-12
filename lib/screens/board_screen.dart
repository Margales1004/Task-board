import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/board_sheet.dart';
import '../widgets/task_sheet.dart';

const _filters = <(String, String)>[
  ('all', 'All'),
  ('todo', 'To do'),
  ('doing', 'In progress'),
  ('done', 'Done'),
  ('late', 'Overdue'),
  ('high', 'High 🔥'),
];

class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.boardById(app.currentBoardId);
    if (b == null) {
      // board vanished (e.g. deleted) — bounce home after this frame
      WidgetsBinding.instance.addPostFrameCallback((_) => app.goHome());
      return const SizedBox.shrink();
    }
    final color = AppColors.fromHex(b.color);
    final ts = app.activeTasks.where((x) => x.boardId == b.id).toList();
    final open = ts.where((x) => x.status != TaskStatus.done).length;
    final doneCount = ts.where((x) => x.status == TaskStatus.done).length;

    // ---- visible filters ----
    final chips = <Widget>[];
    for (final (k, label) in _filters) {
      var l = label;
      if (k == 'late') {
        final c = ts.where(app.isLate).length;
        if (c == 0 && app.currentFilter != 'late') continue;
        if (c > 0) l += ' $c';
      }
      if (k == 'high') {
        final c = ts
            .where((x) => x.prio == TaskPrio.high && x.status != TaskStatus.done)
            .length;
        if (c == 0 && app.currentFilter != 'high') continue;
      }
      final active = app.currentFilter == k;
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => app.setFilter(k),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.ink : AppColors.surface,
              borderRadius: BorderRadius.circular(99),
              boxShadow: active ? null : kCardShadow,
            ),
            child: Text(l,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.muted)),
          ),
        ),
      ));
    }

    // ---- filtered + sorted task list ----
    final shown = ts.where((x) {
      switch (app.currentFilter) {
        case 'all':
          return true;
        case 'late':
          return app.isLate(x);
        case 'high':
          return x.prio == TaskPrio.high;
        default:
          return x.status == app.currentFilter;
      }
    }).toList();
    _sortTasks(shown, app);

    final showArchiveBar =
        doneCount > 0 && (app.currentFilter == 'all' || app.currentFilter == 'done');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
      children: [
        // ---- topbar ----
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
          child: Row(
            children: [
              _IconBtn(icon: Icons.arrow_back, onTap: app.goHome),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: displayStyle(size: 23)),
                    if (ts.isNotEmpty)
                      Text('$open open · ${ts.length - open} done',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _IconBtn(
                  icon: Icons.edit_outlined,
                  onTap: () => showBoardSheet(context, boardId: b.id)),
            ],
          ),
        ),

        // ---- filters ----
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: chips),
          ),
        ),

        // ---- list / empty ----
        if (shown.isEmpty && ts.isEmpty)
          const EmptyState(
            emoji: '☕',
            title: 'No tasks here yet',
            body:
                'Add your first task — with a due date and who should handle it.',
          )
        else if (shown.isEmpty)
          const EmptyState(
              emoji: '🔍', title: 'Nothing matches this filter', dashed: false)
        else
          ...shown.map((t) => TaskDismissible(
                itemKey: ValueKey(t.id),
                onDone: () => app.toggleDone(t.id),
                onDelete: () => deleteTaskWithUndo(context, app, t),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskRow(task: t, boardColor: color),
                ),
              )),

        // ---- archive bar ----
        if (showArchiveBar)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final n = app.archiveDone(b.id);
                  Toast.show(context, 'Archived $n task${n > 1 ? 's' : ''} 🗄️');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: kCardShadow,
                  ),
                  child: Text(
                    '🗄️ Archive $doneCount completed task${doneCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _sortTasks(List<Task> shown, AppState app) {
    const grp = {'todo': 0, 'doing': 0, 'done': 1};
    const pRank = {'high': 0, 'normal': 1, 'low': 2};
    shown.sort((a, b) {
      // The frog (still open) is pinned to the very top.
      final fa = a.frog && a.status != TaskStatus.done ? 0 : 1;
      final fb = b.frog && b.status != TaskStatus.done ? 0 : 1;
      if (fa != fb) return fa - fb;
      final ga = grp[a.status] ?? 0, gb = grp[b.status] ?? 0;
      if (ga != gb) return ga - gb;
      final la = app.isLate(a) ? 0 : 1, lb = app.isLate(b) ? 0 : 1;
      if (la != lb) return la - lb;
      if (a.date != null && b.date != null && a.date != b.date) {
        return a.date!.compareTo(b.date!);
      }
      if (a.date != null && b.date == null) return -1;
      if (a.date == null && b.date != null) return 1;
      return (pRank[a.prio] ?? 1) - (pRank[b.prio] ?? 1);
    });
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: kCardShadow,
        ),
        child: Icon(icon, size: 20, color: AppColors.ink),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  final Color boardColor;
  const _TaskRow({required this.task, required this.boardColor});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final late = app.isLate(task);
    final today = app.isToday(task) && task.status != TaskStatus.done;
    final done = task.status == TaskStatus.done;

    return Opacity(
      opacity: done ? 0.55 : 1,
      child: GestureDetector(
        onTap: () =>
            showTaskSheet(context, boardId: task.boardId, taskId: task.id),
        onLongPress: () {
          app.snoozeToTomorrow(task.id);
          Toast.show(context, 'Pushed to tomorrow →');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: kCardShadow,
            border: Border(
              left: BorderSide(
                  color: late ? AppColors.danger : Colors.transparent, width: 4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // checkbox
              GestureDetector(
                onTap: () => app.toggleDone(task.id),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(top: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? boardColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: done ? boardColor : AppColors.line, width: 2),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        decoration:
                            done ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                    if (task.note != null && task.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(task.note!,
                            style: const TextStyle(
                                fontSize: 13.5,
                                color: AppColors.muted,
                                height: 1.4)),
                      ),
                    if (_hasMeta())
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _metaTags(context, late, today),
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2, left: 4),
                child: Icon(Icons.chevron_right,
                    size: 20, color: Color(0xFFB6C0CB)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasMeta() =>
      task.frog ||
      task.prio == TaskPrio.high ||
      task.prio == TaskPrio.low ||
      (task.date != null && task.date!.isNotEmpty) ||
      (task.person != null && task.person!.isNotEmpty) ||
      task.repeat != null ||
      task.subtasks.isNotEmpty ||
      task.status == TaskStatus.doing ||
      task.status == TaskStatus.todo;

  List<Widget> _metaTags(BuildContext context, bool late, bool today) {
    final app = context.read<AppState>();
    final tags = <Widget>[];

    if (task.frog) {
      tags.add(const Tag('🐸 Most important',
          bg: Color(0xFFEAF6EC), fg: Color(0xFF3B7A43)));
    }

    if (task.prio == TaskPrio.high) {
      tags.add(const Tag('🔥 High',
          bg: Color(0xFFFBE9E9), fg: AppColors.danger));
    } else if (task.prio == TaskPrio.low) {
      tags.add(const Tag('Low', bg: Color(0xFFF0F2F5), fg: Color(0xFF8A97A5)));
    }

    if (task.date != null && task.date!.isNotEmpty) {
      Color bg = AppColors.bg, fg = AppColors.muted;
      if (late) {
        bg = const Color(0xFFFBE9E9);
        fg = AppColors.danger;
      } else if (today) {
        bg = const Color(0xFFFFF4DC);
        fg = const Color(0xFF9A6B00);
      }
      tags.add(Tag('${late ? '⚠ ' : '📅 '}${fmtDate(task.date)}', bg: bg, fg: fg));
    }

    if (task.person != null && task.person!.isNotEmpty) {
      tags.add(Tag('👤 ${task.person}',
          bg: const Color(0xFFEEF2F7), fg: const Color(0xFF3D5266)));
    }

    if (task.repeat != null) {
      tags.add(Tag(TaskRepeat.label(task.repeat),
          bg: const Color(0xFFEDE9FB), fg: const Color(0xFF5B3FB0)));
    }

    if (task.subtasks.isNotEmpty) {
      final done = task.subtasks.where((s) => s.done).length;
      final allDone = done == task.subtasks.length;
      tags.add(Tag('☑ $done/${task.subtasks.length}',
          bg: allDone ? const Color(0xFFEAF6EC) : const Color(0xFFEEF2F7),
          fg: allDone ? const Color(0xFF3B7A43) : const Color(0xFF3D5266)));
    }

    if (task.status == TaskStatus.doing) {
      tags.add(Tag('◐ In progress',
          bg: const Color(0xFFE7F0FB),
          fg: const Color(0xFF2563A8),
          onTap: () => app.cycleStatus(task.id)));
    } else if (task.status == TaskStatus.todo) {
      tags.add(Tag('○ To do', onTap: () => app.cycleStatus(task.id)));
    }

    return tags;
  }
}
