import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../reminders.dart';
import '../theme.dart';
import '../widgets/backup_sheet.dart';
import '../widgets/common.dart';
import '../widgets/ideas_sheet.dart';
import '../widgets/progress_ring.dart';
import '../widgets/task_sheet.dart';
import 'focus_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    final done = app.completedToday();
    final goal = app.dailyGoal;
    final streak = app.currentStreak();
    final next = app.doNext();
    final list = app.todayTasks();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
      children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 26, 2, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, d MMMM').format(now),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(greeting, style: displayStyle(size: 30)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const _SettingsSheet(),
                ),
                icon: const Icon(Icons.settings_outlined,
                    color: AppColors.muted),
              ),
            ],
          ),
        ),

        const _FocusBanner(),

        const SizedBox(height: 10),
        // goal ring + streak
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _editGoal(context, app),
                child: ProgressRing(
                  value: goal == 0 ? 0 : done / goal,
                  size: 92,
                  stroke: 10,
                  color: AppColors.boardPalette[0],
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$done/$goal', style: displayStyle(size: 22)),
                      const Text('TODAY',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(streak > 0 ? '🔥' : '✨',
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text('$streak',
                            style: displayStyle(size: 26)),
                        const SizedBox(width: 6),
                        Text(streak == 1 ? 'day streak' : 'day streak',
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      done >= goal && goal > 0
                          ? 'Daily goal reached 🎉'
                          : streak > 0
                              ? "Keep the streak alive — finish one today."
                              : 'Finish one task today to start a streak.',
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // do this next
        if (next != null) ...[
          const SectionLabel('Do this next'),
          _DoNextCard(task: next),
        ],

        // today list
        if (list.isNotEmpty) ...[
          const SectionLabel('Today'),
          ...list.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TodayRow(task: t),
              )),
        ] else if (next == null) ...[
          const SizedBox(height: 6),
          EmptyState(
            emoji: app.boards.isEmpty ? '🗂️' : '☀️',
            title: app.boards.isEmpty ? 'No boards yet' : "You're all caught up",
            body: app.boards.isEmpty
                ? 'Create a board and add tasks to see your day here.'
                : 'Nothing due today. Enjoy it — or pull something forward.',
          ),
        ],

        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => showDailyIdeasSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.line, width: 1.5),
            ),
            child: const Row(
              children: [
                Text('✨', style: TextStyle(fontSize: 20)),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Need ideas? Get suggestions for today',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _editGoal(BuildContext context, AppState app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalSheet(initial: app.dailyGoal),
    );
  }
}

class _DoNextCard extends StatelessWidget {
  final Task task;
  const _DoNextCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final board = app.boardById(task.boardId);
    final color =
        board != null ? AppColors.fromHex(board.color) : AppColors.muted;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (task.frog) const Text('🐸 ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Text(task.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, height: 1.25)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Text(board?.name ?? '',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              if (task.date != null) ...[
                const Text(' · ',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                Text(fmtDate(task.date),
                    style: TextStyle(
                        fontSize: 13,
                        color: app.isLate(task)
                            ? AppColors.danger
                            : AppColors.muted,
                        fontWeight:
                            app.isLate(task) ? FontWeight.w700 : FontWeight.w400)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        FocusScreen(taskId: task.id, taskName: task.name),
                  )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('▶  Start focus',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  final goalBefore = app.completedToday();
                  app.toggleDone(task.id);
                  if (goalBefore + 1 == app.dailyGoal) {
                    Toast.show(context, 'Daily goal reached 🎉');
                  } else {
                    Toast.show(context, 'Done ✓');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  final Task task;
  const _TodayRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final board = app.boardById(task.boardId);
    final color =
        board != null ? AppColors.fromHex(board.color) : AppColors.muted;
    final late = app.isLate(task);
    return GestureDetector(
      onTap: () =>
          showTaskSheet(context, boardId: task.boardId, taskId: task.id),
      child: SoftCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                final before = app.completedToday();
                app.toggleDone(task.id);
                if (before + 1 == app.dailyGoal) {
                  Toast.show(context, 'Daily goal reached 🎉');
                }
              },
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.line, width: 2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${task.frog ? '🐸 ' : ''}${task.name}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, height: 1.3)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Tag(board?.name ?? '', bg: AppColors.bg, fg: color),
                      if (task.date != null)
                        Tag('${late ? '⚠ ' : '📅 '}${fmtDate(task.date)}',
                            bg: late ? const Color(0xFFFBE9E9) : AppColors.bg,
                            fg: late ? AppColors.danger : AppColors.muted),
                      if (task.prio == TaskPrio.high)
                        const Tag('🔥 High',
                            bg: Color(0xFFFBE9E9), fg: AppColors.danger),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSheet extends StatefulWidget {
  final int initial;
  const _GoalSheet({required this.initial});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
              Text('Daily goal', style: displayStyle(size: 21)),
              const SizedBox(height: 6),
              const Text('How many tasks do you want to finish each day?',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepBtn(
                      icon: Icons.remove,
                      onTap: () => setState(
                          () => _value = (_value - 1).clamp(1, 20))),
                  SizedBox(
                    width: 90,
                    child: Text('$_value',
                        textAlign: TextAlign.center,
                        style: displayStyle(size: 44)),
                  ),
                  _StepBtn(
                      icon: Icons.add,
                      onTap: () => setState(
                          () => _value = (_value + 1).clamp(1, 20))),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  context.read<AppState>().setDailyGoal(_value);
                  Navigator.pop(context);
                },
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
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.ink),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
              Text('Settings', style: displayStyle(size: 21)),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily reminders',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          Text('Morning & evening nudges to keep your streak',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Switch(
                      value: app.dailyNudges,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.ink,
                      onChanged: (v) => app.setDailyNudges(v),
                    ),
                  ],
                ),
              ),
              if (!Reminders.available)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Reminders arrive in the installed app.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  // Capture a stable context before this sheet's own context
                  // is torn down by the pop below.
                  final rootCtx = Navigator.of(context, rootNavigator: true)
                      .context;
                  Navigator.pop(context);
                  showBackupSheet(rootCtx);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Backup & restore',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            Text('Save or move your tasks to a new install',
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a live "focus in progress" card whenever a session is active, so it
/// survives leaving the timer screen or a WebView reload and can be resumed.
class _FocusBanner extends StatefulWidget {
  const _FocusBanner();

  @override
  State<_FocusBanner> createState() => _FocusBannerState();
}

class _FocusBannerState extends State<_FocusBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.hasActiveFocus) return const SizedBox.shrink();
    final task = app.taskById(app.focusTaskId!);
    if (task == null) return const SizedBox.shrink();
    final rem = app.focusRemainingSeconds();
    if (app.focusRunning && rem <= 0) return const SizedBox.shrink();
    final mm = (rem ~/ 60).toString().padLeft(2, '0');
    final ss = (rem % 60).toString().padLeft(2, '0');
    final status = app.focusRunning ? '$mm:$ss left' : 'Paused · $mm:$ss';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FocusScreen(taskId: task.id, taskName: task.name),
        )),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: kCardShadow,
          ),
          child: Row(
            children: [
              const Text('⏱️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Focus: ${task.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(status,
                        style: const TextStyle(
                            color: Color(0xFFB6C0CB), fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('Resume',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
