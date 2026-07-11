import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/progress_ring.dart';

/// Full-screen Pomodoro focus timer for a single task.
class FocusScreen extends StatefulWidget {
  final String taskId;
  final String taskName;
  const FocusScreen({super.key, required this.taskId, required this.taskName});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with WidgetsBindingObserver {
  static const _workSeconds = 25 * 60;
  static const _breakSeconds = 5 * 60;

  bool _isBreak = false;
  int _remaining = _workSeconds; // seconds shown on the clock
  bool _running = false;
  DateTime? _deadline; // real wall-clock end time while running
  Timer? _timer;

  int get _total => _isBreak ? _breakSeconds : _workSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _timer?.cancel();
      setState(() {
        _remaining = ms <= 0 ? 0 : (ms / 1000).ceil().clamp(0, _total);
        _running = false;
        _deadline = null;
      });
      return;
    }
    setState(() {
      _running = true;
      _deadline = DateTime.now().add(Duration(seconds: _remaining));
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _remaining = _total;
      _running = false;
      _deadline = null;
    });
  }

  void _finish() {
    _timer?.cancel();
    final wasWork = !_isBreak;
    if (wasWork) {
      context.read<AppState>().addPomodoro(widget.taskId);
    }
    setState(() {
      _running = false;
      _deadline = null;
      _remaining = _total;
    });
    if (!mounted) return;
    if (wasWork) {
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
              _ModeSwitch(isBreak: _isBreak, onChanged: _setMode),
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
  final ValueChanged<bool> onChanged;
  const _ModeSwitch({required this.isBreak, required this.onChanged});

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
      child: Row(children: [seg('Focus · 25', false), seg('Break · 5', true)]),
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
