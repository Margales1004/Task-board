import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../chime.dart';
import '../reminders.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/progress_ring.dart';

const _focusPresets = <int>[10, 15, 20, 25, 30, 45, 50, 60];
const _breakPresets = <int>[5, 10, 15, 20];

/// Reserved notification id for the focus-timer end alert (won't collide with
/// task reminder ids, which are FNV hashes of task-id strings).
const int _kFocusNotifId = 2147483646;

/// Full-screen Pomodoro focus timer for a single task.
class FocusScreen extends StatefulWidget {
  final String taskId;
  final String taskName;
  /// Optional one-off focus length (minutes), e.g. from the procrastination
  /// coach's "just 5 minutes". Doesn't change the saved default.
  final int? initialMinutes;
  const FocusScreen(
      {super.key,
      required this.taskId,
      required this.taskName,
      this.initialMinutes});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with WidgetsBindingObserver {
  int _workMin = 25;
  int _breakMin = 5;

  bool _isBreak = false;
  int _remaining = 25 * 60; // seconds shown on the clock
  bool _running = false;
  DateTime? _deadline; // real wall-clock end time while running
  Timer? _timer;

  int get _total => (_isBreak ? _breakMin : _workMin) * 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final app = context.read<AppState>();
    _workMin = widget.initialMinutes ?? app.focusMinutes;
    _breakMin = app.breakMinutes;
    // Restore a persisted session for this task (survives reload/navigation).
    if (app.focusTaskId == widget.taskId && app.hasActiveFocus) {
      _isBreak = app.focusIsBreak;
      final rem = app.focusRemainingSeconds();
      if (app.focusRunning && rem > 0) {
        _running = true;
        _deadline = DateTime.fromMillisecondsSinceEpoch(app.focusEndMs!);
        _remaining = rem.clamp(0, _total);
        _startTimer();
        _scheduleEnd(_deadline!); // (re)arm the end alert (id replaces)
      } else if (!app.focusRunning && (app.focusPausedRemaining ?? 0) > 0) {
        _remaining = app.focusPausedRemaining!.clamp(0, _total);
      } else {
        _remaining = _total;
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.read<AppState>().focusClear());
      }
    } else {
      _remaining = _total;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  /// Schedule an OS notification at the deadline so the timer still alerts when
  /// the screen is off (no-op in a plain browser). Same id → replaces.
  void _scheduleEnd(DateTime deadline) {
    Reminders.schedule(
      id: _kFocusNotifId,
      title: _isBreak ? "Break's over" : 'Focus session complete',
      body: widget.taskName,
      when: deadline,
    );
  }

  void _cancelEnd() => Reminders.cancel(_kFocusNotifId);

  void _chooseDuration() {
    final presets = _isBreak ? _breakPresets : _focusPresets;
    final current = _isBreak ? _breakMin : _workMin;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DurationSheet(
        title: _isBreak ? 'Break length' : 'Focus length',
        presets: presets,
        current: current,
        onPick: (min) {
          final app = context.read<AppState>();
          if (_isBreak) {
            app.setFocusDurations(brk: min);
          } else {
            app.setFocusDurations(focus: min);
          }
          app.focusClear();
          _cancelEnd();
          setState(() {
            if (_isBreak) {
              _breakMin = min;
            } else {
              _workMin = min;
            }
            _timer?.cancel();
            _running = false;
            _deadline = null;
            _remaining = _total;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers are throttled/paused while the app is backgrounded or the screen
    // is off, so re-sync to the real clock the moment we come back.
    if (state == AppLifecycleState.resumed && _running) _tick();
  }

  /// Recompute the displayed time from the wall clock (not from tick counts),
  /// so elapsed time stays correct even if ticks were throttled.
  void _tick() {
    final d = _deadline;
    if (d == null) return;
    final ms = d.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) {
      _finish();
    } else {
      setState(() => _remaining = (ms / 1000).ceil().clamp(0, _total));
    }
  }

  void _setMode(bool isBreak) {
    _timer?.cancel();
    _cancelEnd();
    context.read<AppState>().focusClear();
    setState(() {
      _isBreak = isBreak;
      _remaining = _total;
      _running = false;
      _deadline = null;
    });
  }

  void _toggleRun() {
    if (_running) {
      // Pause: freeze the remaining time from the real clock.
      final ms = _deadline?.difference(DateTime.now()).inMilliseconds ?? 0;
      final rem = ms <= 0 ? 0 : (ms / 1000).ceil().clamp(0, _total);
      _timer?.cancel();
      _cancelEnd();
      context.read<AppState>().focusPause(rem);
      setState(() {
        _remaining = rem;
        _running = false;
        _deadline = null;
      });
      return;
    }
    Chime.prime(); // unlock audio within the tap gesture
    final deadline = DateTime.now().add(Duration(seconds: _remaining));
    context.read<AppState>().focusStart(
        taskId: widget.taskId, isBreak: _isBreak, deadline: deadline);
    _scheduleEnd(deadline);
    setState(() {
      _running = true;
      _deadline = deadline;
    });
    _startTimer();
  }

  void _reset() {
    _timer?.cancel();
    _cancelEnd();
    context.read<AppState>().focusClear();
    setState(() {
      _remaining = _total;
      _running = false;
      _deadline = null;
    });
  }

  void _finish() {
    _timer?.cancel();
    _cancelEnd(); // avoid a duplicate/late OS notification
    // If the timer ran out while the app was backgrounded, the periodic tick
    // was frozen and we only notice now — overshooting the deadline by a lot.
    // In that case finalize quietly (no alarm on re-entry); only ring when the
    // countdown actually hits zero while the screen is in front of the user.
    final d = _deadline;
    final overshootMs = d == null
        ? 0
        : DateTime.now().millisecondsSinceEpoch - d.millisecondsSinceEpoch;
    final silent = overshootMs > 1500;

    final wasWork = !_isBreak;
    if (wasWork) {
      context.read<AppState>().addPomodoro(widget.taskId);
    }
    if (!silent) Chime.alert(); // sound + vibration (foreground completion only)

    if (!mounted) return;
    if (silent) {
      Toast.show(context, 'Focus session finished ✓');
      _setMode(false); // clear the session, back to a fresh focus timer
    } else if (wasWork) {
      Toast.show(context, 'Focus session done 🎉 Take a short break');
      _setMode(true); // offer a break next
    } else {
      Toast.show(context, 'Break over — ready for another round?');
      _setMode(false);
    }
  }

  String get _clock {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final frac = _total == 0 ? 0.0 : 1 - (_remaining / _total);
    final accent = _isBreak ? AppColors.boardPalette[2] : AppColors.boardPalette[0];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text('Focus'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            children: [
              // Work / Break switch
              _ModeSwitch(
                isBreak: _isBreak,
                workMin: _workMin,
                breakMin: _breakMin,
                onChanged: _setMode,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _running ? null : _chooseDuration,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: kCardShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_isBreak ? _breakMin : _workMin} min',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: AppColors.ink)),
                      const SizedBox(width: 4),
                      Icon(_running ? Icons.lock_outline : Icons.expand_more,
                          size: 18, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                widget.taskName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(_isBreak ? 'Break time' : 'Stay on this one thing',
                  style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              const SizedBox(height: 28),
              ProgressRing(
                value: frac,
                size: 240,
                stroke: 16,
                color: accent,
                center: Text(_clock, style: displayStyle(size: 52)),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _FocusButton(
                      label: _running ? 'Pause' : 'Start',
                      filled: true,
                      color: accent,
                      onTap: _toggleRun,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FocusButton(label: 'Reset', onTap: _reset),
                  if (!_isBreak) ...[
                    const SizedBox(width: 12),
                    _FocusButton(label: 'Done', onTap: _finish),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  final bool isBreak;
  final int workMin;
  final int breakMin;
  final ValueChanged<bool> onChanged;
  const _ModeSwitch({
    required this.isBreak,
    required this.workMin,
    required this.breakMin,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool breakMode) {
      final sel = isBreak == breakMode;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(breakMode),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : AppColors.muted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
      ),
      child: Row(children: [
        seg('Focus · $workMin', false),
        seg('Break · $breakMin', true),
      ]),
    );
  }
}

class _DurationSheet extends StatelessWidget {
  final String title;
  final List<int> presets;
  final int current;
  final ValueChanged<int> onPick;
  const _DurationSheet({
    required this.title,
    required this.presets,
    required this.current,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
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
              Text(title, style: displayStyle(size: 21)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: presets.map((m) {
                  final sel = m == current;
                  return GestureDetector(
                    onTap: () {
                      onPick(m);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.ink : AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? AppColors.ink : AppColors.line,
                            width: 1.5),
                      ),
                      child: Text('$m min',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : AppColors.ink)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusButton extends StatelessWidget {
  final String label;
  final bool filled;
  final Color? color;
  final VoidCallback onTap;
  const _FocusButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: filled ? (color ?? AppColors.ink) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: kCardShadow,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : AppColors.ink)),
      ),
    );
  }
}
