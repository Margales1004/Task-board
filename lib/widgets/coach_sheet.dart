import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../coach.dart';
import '../models.dart';
import '../theme.dart';
import '../screens/focus_screen.dart';
import 'common.dart';
import 'task_sheet.dart';

/// Either postpone the task, or — if it's been postponed enough and the coach
/// is enabled — ask what's blocking it instead of snoozing again.
void snoozeOrCoach(BuildContext context, AppState app, Task task) {
  if (app.shouldCoach(task)) {
    showCoachSheet(context, task.id);
  } else {
    app.snoozeToTomorrow(task.id);
    Toast.show(context, 'Pushed to tomorrow →');
  }
}

/// The "why am I stuck?" coach: pick a reason, get one concrete action.
void showCoachSheet(BuildContext context, String taskId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CoachSheet(taskId: taskId),
  );
}

class _CoachSheet extends StatelessWidget {
  final String taskId;
  const _CoachSheet({required this.taskId});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final task = app.taskById(taskId);
    return Container(
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
              Text('What’s stopping you? 💛', style: displayStyle(size: 22)),
              const SizedBox(height: 6),
              Text(
                task == null
                    ? "Let's figure out what's in the way."
                    : '“${task.name}” keeps getting pushed. No judgment — '
                        "let's find what's really in the way.",
                style: const TextStyle(
                    fontSize: 14, color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 16),
              ...kCoachReasons.map((r) => _ReasonTile(
                    reason: r,
                    onTap: () => _handle(context, r),
                  )),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    app.snoozeToTomorrow(taskId);
                    Toast.show(context, 'Pushed to tomorrow →');
                  },
                  child: const Text('Not now — just push to tomorrow',
                      style: TextStyle(
                          color: AppColors.muted, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handle(BuildContext context, CoachReason reason) {
    final app = context.read<AppState>();
    final task = app.taskById(taskId);
    if (task == null) {
      Navigator.pop(context);
      return;
    }
    app.recordBlockReason(taskId, reason.key);
    // Capture a stable navigator/context before popping this sheet.
    final rootNav = Navigator.of(context, rootNavigator: true);
    final rootCtx = rootNav.context;
    Navigator.pop(context);

    switch (reason.action) {
      case CoachAction.breakIntoSteps:
        showTaskSheet(rootCtx, taskId: taskId);
        break;
      case CoachAction.firstAction:
        _askFirstStep(rootCtx, app);
        break;
      case CoachAction.fiveMinutes:
        rootNav.push(MaterialPageRoute(
          builder: (_) => FocusScreen(
              taskId: taskId, taskName: task.name, initialMinutes: 5),
        ));
        break;
      case CoachAction.moveToWaiting:
        app.moveToWaiting(taskId);
        Toast.show(rootCtx, 'Moved to Waiting ⏳');
        break;
      case CoachAction.badFirstDraft:
        app.addBadDraftStep(taskId);
        rootNav.push(MaterialPageRoute(
          builder: (_) => FocusScreen(
              taskId: taskId, taskName: task.name, initialMinutes: 10),
        ));
        break;
      case CoachAction.sprint:
        rootNav.push(MaterialPageRoute(
          builder: (_) => FocusScreen(
              taskId: taskId, taskName: task.name, initialMinutes: 10),
        ));
        Toast.show(rootCtx, '10-minute sprint — go! 🎯');
        break;
      case CoachAction.deleteIt:
        deleteTaskWithUndo(rootCtx, app, task);
        break;
    }
  }

  Future<void> _askFirstStep(BuildContext context, AppState app) async {
    final ctrl = TextEditingController();
    final step = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text("What's the very first step?"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Open the document',
          ),
          onSubmitted: (v) => Navigator.pop(dctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
            onPressed: () => Navigator.pop(dctx, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (step != null && step.trim().isNotEmpty) {
      app.addFirstStep(taskId, step);
      if (context.mounted) {
        Toast.show(context, 'First step set — start there ✨');
      }
    }
  }
}

class _ReasonTile extends StatelessWidget {
  final CoachReason reason;
  final VoidCallback onTap;
  const _ReasonTile({required this.reason, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(reason.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reason.label,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${reason.cta} · ${reason.blurb}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                            height: 1.35)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
