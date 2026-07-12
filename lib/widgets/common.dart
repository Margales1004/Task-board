import 'dart:async';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Delete [task] and show an "Undo" snackbar that reinserts it if tapped.
void deleteTaskWithUndo(BuildContext context, AppState app, Task task) {
  app.deleteTask(task.id);
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text('Deleted "${task.name}"'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        textColor: Colors.white,
        onPressed: () => app.reinsertTask(task),
      ),
    ),
  );
}

/// A small pill toast at the bottom of the screen (mirrors `.toast` in the HTML).
class Toast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, String msg) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _timer?.cancel();
    _entry?.remove();

    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 0,
        right: 0,
        bottom: 130 + MediaQuery.of(ctx).padding.bottom,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  msg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 1800), () {
      entry.remove();
      if (_entry == entry) _entry = null;
    });
  }
}

/// The uppercase divider label ("COMING UP", "BOARDS", ...).
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1, color: AppColors.line)),
        ],
      ),
    );
  }
}

/// A pill "tag" chip used inside task rows.
class Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final FontWeight weight;
  final VoidCallback? onTap;

  const Tag(
    this.text, {
    super.key,
    this.bg = AppColors.bg,
    this.fg = AppColors.muted,
    this.weight = FontWeight.w600,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: weight, color: fg),
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}

/// A card that scales down slightly while pressed (`:active{transform:scale}`).
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// Reusable white card container with the app's soft shadow.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: kCardShadow,
      ),
      child: child,
    );
  }
}

/// Wraps a task card with swipe gestures: swipe right → "Done" (snaps back so
/// the card stays, now marked done); swipe left → "Delete" (dismisses).
class TaskDismissible extends StatelessWidget {
  final Key itemKey;
  final Widget child;
  final VoidCallback onDone;
  final VoidCallback onDelete;
  const TaskDismissible({
    super.key,
    required this.itemKey,
    required this.child,
    required this.onDone,
    required this.onDelete,
  });

  Widget _bg(Color color, IconData icon, String label, Alignment align) {
    final left = align == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: align,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (left) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          if (!left) ...[
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 22),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: itemKey,
      background:
          _bg(const Color(0xFF3B7A43), Icons.check, 'Done', Alignment.centerLeft),
      secondaryBackground:
          _bg(AppColors.danger, Icons.delete_outline, 'Delete',
              Alignment.centerRight),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          onDone();
          return false; // snap back; the card stays, now marked done
        }
        return true; // swipe left → delete
      },
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}

/// Empty-state block (emoji + heading + body text).
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? body;
  final bool dashed;
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.body,
    this.dashed = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: dashed
            ? Border.all(color: AppColors.line, width: 1.5, style: BorderStyle.solid)
            : null,
        boxShadow: dashed ? null : kCardShadow,
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.muted, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
