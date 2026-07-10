import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final act = app.activeTasks;
    final open = act.where((t) => t.status != TaskStatus.done).toList();
    final late = open.where(app.isLate).length;

    String summary;
    if (app.boards.isEmpty) {
      summary = "Let's get started";
    } else if (open.isNotEmpty) {
      summary = '${open.length} open task${open.length > 1 ? 's' : ''}';
      if (late > 0) summary += ' · $late overdue';
    } else {
      summary = 'All clear. Nice work 👏';
    }

    // "Coming up" — open, dated, within the next 7 days, up to 10.
    final weekEnd = iso(DateTime.now().add(const Duration(days: 7)));
    final upcoming = act
        .where((x) =>
            x.status != TaskStatus.done &&
            x.date != null &&
            x.date!.compareTo(weekEnd) <= 0)
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
    final upcomingTop = upcoming.take(10).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
      children: [
        // ---- header ----
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 26, 2, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text('My Boards', style: displayStyle(size: 30)),
              const SizedBox(height: 4),
              Text(summary,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ),

        // ---- coming up ----
        if (upcomingTop.isNotEmpty) ...[
          const SectionLabel('Coming up'),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: upcomingTop.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _WeekCard(task: upcomingTop[i]),
            ),
          ),
        ],

        // ---- boards ----
        const SectionLabel('Boards'),
        if (app.boards.isEmpty)
          const EmptyState(
            emoji: '🗂️',
            title: 'No boards yet',
            body:
                'A board is a space for one topic — work, home, a side project. '
                'Tap the button below to create your first one.',
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.12,
            children: app.boards.map((b) => _BoardCard(board: b)).toList(),
          ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  final Task task;
  const _WeekCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final b = app.boardById(task.boardId) ??
        Board(id: '', name: '', color: '#2E86AB');
    final color = AppColors.fromHex(b.color);
    final late = app.isLate(task);

    return Pressable(
      onTap: () => app.openBoard(task.boardId),
      child: Container(
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: kCardShadow,
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(
              '${task.prio == TaskPrio.high ? '🔥 ' : ''}${task.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.3),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${late ? '⚠ ' : ''}${fmtDate(task.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: late ? AppColors.danger : AppColors.muted,
                      fontWeight: late ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (task.person != null)
                  Flexible(
                    child: Text('· ${task.person}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final Board board;
  const _BoardCard({required this.board});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final color = AppColors.fromHex(board.color);
    final ts = app.activeTasks.where((x) => x.boardId == board.id).toList();
    final done = ts.where((x) => x.status == TaskStatus.done).length;
    final late = ts.where(app.isLate).length;
    final pct = ts.isEmpty ? 0 : (done / ts.length * 100).round();

    return Pressable(
      onTap: () => app.openBoard(board.id),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 38, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: kCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(board.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 3),
                _countLine(ts.length, done, late),
                const Spacer(),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.line,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 6),
                Text('$pct% done',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 16,
            child: Container(
              width: 46,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countLine(int total, int done, int late) {
    final base = total > 0 ? '${total - done} open of $total' : 'Empty for now';
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
        children: [
          TextSpan(text: base),
          if (late > 0)
            TextSpan(
              text: ' · $late overdue',
              style: const TextStyle(
                  color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
