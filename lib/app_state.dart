import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'reminders.dart';

enum AppTab { today, home, stats, archive }

/// ================= date helpers (ported from the HTML) =================
String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String todayStr() => iso(DateTime.now());

/// Human-friendly label: "Today" / "Tomorrow" / "Fri, 10 Jul".
String fmtDate(String? s) {
  if (s == null || s.isEmpty) return '';
  if (s == todayStr()) return 'Today';
  final tm = DateTime.now().add(const Duration(days: 1));
  if (s == iso(tm)) return 'Tomorrow';
  final d = DateTime.parse('${s}T00:00:00');
  return DateFormat('EEE, d MMM').format(d);
}

/// The whole app's state + persistence, exposed via [ChangeNotifier].
class AppState extends ChangeNotifier {
  static const _storeKey = 'moran-taskboards-v1';

  List<Board> boards = [];
  List<Task> tasks = [];

  // ---- settings ----
  int dailyGoal = 3; // target completions per day
  int focusMinutes = 25; // Pomodoro focus length
  int breakMinutes = 5; // Pomodoro break length

  // ---- active focus session (persisted so it survives navigation/reloads) ----
  String? focusTaskId;
  bool focusIsBreak = false;
  int? focusEndMs; // wall-clock deadline (ms) while running
  int? focusPausedRemaining; // seconds remaining while paused

  bool get hasActiveFocus =>
      focusTaskId != null && (focusEndMs != null || focusPausedRemaining != null);

  bool get focusRunning => focusEndMs != null;

  int focusRemainingSeconds() {
    if (focusEndMs != null) {
      final ms = focusEndMs! - DateTime.now().millisecondsSinceEpoch;
      return ms <= 0 ? 0 : (ms / 1000).ceil();
    }
    return focusPausedRemaining ?? 0;
  }

  void focusStart(
      {required String taskId, required bool isBreak, required DateTime deadline}) {
    focusTaskId = taskId;
    focusIsBreak = isBreak;
    focusEndMs = deadline.millisecondsSinceEpoch;
    focusPausedRemaining = null;
    _save();
  }

  void focusPause(int remainingSeconds) {
    focusPausedRemaining = remainingSeconds;
    focusEndMs = null;
    _save();
  }

  void focusClear() {
    focusTaskId = null;
    focusEndMs = null;
    focusPausedRemaining = null;
    focusIsBreak = false;
    _save();
  }

  // ---- navigation / view state ----
  AppTab tab = AppTab.today;
  String? currentBoardId;
  String currentFilter = 'all';

  bool _loaded = false;
  bool get loaded => _loaded;

  final _rng = Random();

  String uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      _rng.nextInt(1 << 20).toRadixString(36);

  // ---------------- persistence ----------------
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        boards = (decoded['boards'] as List? ?? [])
            .map((e) => Board.fromJson(e as Map<String, dynamic>))
            .toList();
        tasks = (decoded['tasks'] as List? ?? [])
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();
        final settings = decoded['settings'] as Map<String, dynamic>?;
        if (settings != null) {
          dailyGoal = (settings['dailyGoal'] as num?)?.toInt() ?? dailyGoal;
          focusMinutes =
              (settings['focusMinutes'] as num?)?.toInt() ?? focusMinutes;
          breakMinutes =
              (settings['breakMinutes'] as num?)?.toInt() ?? breakMinutes;
        }
        final focus = decoded['focus'] as Map<String, dynamic>?;
        if (focus != null) {
          focusTaskId = focus['taskId'] as String?;
          focusIsBreak = (focus['isBreak'] as bool?) ?? false;
          focusEndMs = (focus['endMs'] as num?)?.toInt();
          focusPausedRemaining = (focus['paused'] as num?)?.toInt();
          // Drop a running session whose deadline already passed while closed.
          if (focusEndMs != null &&
              focusEndMs! <= DateTime.now().millisecondsSinceEpoch) {
            focusTaskId = null;
            focusEndMs = null;
            focusPausedRemaining = null;
          }
        }
      }
    } catch (_) {
      // first run / corrupt data — start clean
    }
    _loaded = true;
    notifyListeners();
    // Ask for notification permission (native shell) and sync scheduled reminders.
    if (Reminders.available) {
      Reminders.requestPermission();
      _syncReminders();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storeKey,
        jsonEncode({
          'boards': boards.map((b) => b.toJson()).toList(),
          'tasks': tasks.map((t) => t.toJson()).toList(),
          'settings': {
            'dailyGoal': dailyGoal,
            'focusMinutes': focusMinutes,
            'breakMinutes': breakMinutes,
          },
          'focus': {
            'taskId': focusTaskId,
            'isBreak': focusIsBreak,
            'endMs': focusEndMs,
            'paused': focusPausedRemaining,
          },
        }),
      );
    } catch (_) {
      // ignore; UI shows a toast at the call site if needed
    }
  }

  void _save() {
    notifyListeners();
    _persist();
    if (Reminders.available) _syncReminders();
  }

  // ---------------- reminders ----------------
  /// Stable positive 31-bit id for a task's notification (FNV-1a).
  int _notifId(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = (h ^ c) * 0x01000193;
    }
    return h & 0x7fffffff;
  }

  /// Re-sync scheduled task-reminder notifications with the current data.
  ///
  /// Cancels each task's own reminder id (rather than cancelAll) so unrelated
  /// notifications — e.g. the focus-timer end alert — are left untouched.
  void _syncReminders() {
    final now = DateTime.now();
    for (final t in tasks) {
      Reminders.cancel(_notifId(t.id));
      if (t.archived || t.status == TaskStatus.done || t.remindAt == null) {
        continue;
      }
      final when = DateTime.tryParse(t.remindAt!);
      if (when == null || !when.isAfter(now)) continue;
      final board = boardById(t.boardId);
      Reminders.schedule(
        id: _notifId(t.id),
        title: t.name,
        body: board != null && board.name.isNotEmpty
            ? board.name
            : 'Task reminder',
        when: when,
      );
    }
  }

  // ---------------- derived collections ----------------
  List<Task> get activeTasks => tasks.where((t) => !t.archived).toList();
  List<Task> get archivedTasks => tasks.where((t) => t.archived).toList();

  bool isLate(Task t) =>
      t.date != null &&
      t.date!.isNotEmpty &&
      t.status != TaskStatus.done &&
      t.date!.compareTo(todayStr()) < 0;

  bool isToday(Task t) => t.date == todayStr();

  Board? boardById(String? id) {
    for (final b in boards) {
      if (b.id == id) return b;
    }
    return null;
  }

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<String> get knownPeople {
    final set = <String>{};
    for (final t in tasks) {
      final p = t.person;
      if (p != null && p.isNotEmpty) set.add(p);
    }
    return set.toList();
  }

  // ---------------- anti-procrastination helpers ----------------
  /// Consecutive days (ending today, or yesterday if nothing done yet today)
  /// on which at least one task was completed.
  int currentStreak() {
    final doneDays = <String>{
      for (final t in tasks)
        if (t.completedAt != null) t.completedAt!,
    };
    if (doneDays.isEmpty) return 0;
    var day = DateTime.now();
    // If nothing done today, the streak may still be alive through yesterday.
    if (!doneDays.contains(iso(day))) {
      day = day.subtract(const Duration(days: 1));
      if (!doneDays.contains(iso(day))) return 0;
    }
    var streak = 0;
    while (doneDays.contains(iso(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int completedToday() =>
      tasks.where((t) => t.completedAt == todayStr()).length;

  /// Open tasks that deserve attention today: the frog, overdue, or due today.
  List<Task> todayTasks() {
    final list = activeTasks
        .where((t) =>
            t.status != TaskStatus.done &&
            (t.frog || isLate(t) || isToday(t)))
        .toList();
    const pRank = {'high': 0, 'normal': 1, 'low': 2};
    list.sort((a, b) {
      if (a.frog != b.frog) return a.frog ? -1 : 1;
      final la = isLate(a) ? 0 : 1, lb = isLate(b) ? 0 : 1;
      if (la != lb) return la - lb;
      final pa = pRank[a.prio] ?? 1, pb = pRank[b.prio] ?? 1;
      if (pa != pb) return pa - pb;
      return (a.date ?? '').compareTo(b.date ?? '');
    });
    return list;
  }

  /// The single task to focus on next (frog wins, else most urgent today).
  Task? doNext() {
    final t = todayTasks();
    return t.isEmpty ? null : t.first;
  }

  /// Mark [id] as the frog, clearing the flag on every other task (single frog).
  void setFrog(String id, bool value) {
    for (final t in tasks) {
      t.frog = value && t.id == id;
    }
    _save();
  }

  void setDailyGoal(int n) {
    dailyGoal = n.clamp(1, 20);
    _save();
  }

  void setFocusDurations({int? focus, int? brk}) {
    if (focus != null) focusMinutes = focus.clamp(1, 180);
    if (brk != null) breakMinutes = brk.clamp(1, 60);
    _save();
  }

  void addPomodoro(String id) {
    final t = taskById(id);
    if (t == null) return;
    t.pomodoros++;
    _save();
  }

  // ---------------- navigation ----------------
  void goTab(AppTab t) {
    tab = t;
    currentBoardId = null;
    notifyListeners();
  }

  void openBoard(String id) {
    tab = AppTab.home;
    currentBoardId = id;
    currentFilter = 'all';
    notifyListeners();
  }

  void goHome() {
    currentBoardId = null;
    notifyListeners();
  }

  void setFilter(String f) {
    currentFilter = f;
    notifyListeners();
  }

  // ---------------- board CRUD ----------------
  /// Returns the id of the created/edited board.
  String saveBoard({String? id, required String name, required String color}) {
    if (id != null) {
      final b = boardById(id)!;
      b.name = name;
      b.color = color;
      _save();
      return id;
    }
    final newId = uid();
    boards.add(Board(id: newId, name: name, color: color));
    currentBoardId = newId;
    currentFilter = 'all';
    tab = AppTab.home;
    _save();
    return newId;
  }

  void deleteBoard(String id) {
    for (final t in tasks.where((t) => t.boardId == id)) {
      Reminders.cancel(_notifId(t.id));
    }
    tasks.removeWhere((t) => t.boardId == id);
    boards.removeWhere((b) => b.id == id);
    if (currentBoardId == id) currentBoardId = null;
    _save();
  }

  // ---------------- task CRUD ----------------
  void saveTask({
    String? id,
    required String boardId,
    required String name,
    String? date,
    String? person,
    String? note,
    required String status,
    required String prio,
    bool frog = false,
    String? remindAt,
  }) {
    final completedAt = status == TaskStatus.done
        ? (id != null && taskById(id)?.completedAt != null
            ? taskById(id)!.completedAt
            : todayStr())
        : null;

    // Single-frog invariant: setting this one as the frog clears the others.
    if (frog) {
      for (final t in tasks) {
        if (t.id != id) t.frog = false;
      }
    }

    if (id != null) {
      final t = taskById(id)!;
      t.name = name;
      t.date = date;
      t.person = person;
      t.note = note;
      t.status = status;
      t.prio = prio;
      t.completedAt = completedAt;
      t.frog = frog;
      t.remindAt = remindAt;
    } else {
      tasks.add(Task(
        id: uid(),
        boardId: boardId,
        name: name,
        date: date,
        person: person,
        note: note,
        status: status,
        prio: prio,
        completedAt: completedAt,
        frog: frog,
        remindAt: remindAt,
      ));
    }
    _save();
  }

  void toggleDone(String id) {
    final t = taskById(id);
    if (t == null) return;
    if (t.status == TaskStatus.done) {
      t.status = TaskStatus.todo;
      t.completedAt = null;
    } else {
      t.status = TaskStatus.done;
      t.completedAt = todayStr();
    }
    _save();
  }

  void cycleStatus(String id) {
    final t = taskById(id);
    if (t == null) return;
    t.status = t.status == TaskStatus.todo ? TaskStatus.doing : TaskStatus.todo;
    _save();
  }

  /// Archive every done task on [boardId]. Returns how many were archived.
  int archiveDone(String boardId) {
    final ts = activeTasks
        .where((x) => x.boardId == boardId && x.status == TaskStatus.done)
        .toList();
    for (final t in ts) {
      t.archived = true;
      t.completedAt ??= todayStr();
    }
    _save();
    return ts.length;
  }

  void archiveTask(String id) {
    final t = taskById(id);
    if (t == null) return;
    t.archived = true;
    if (t.status == TaskStatus.done && t.completedAt == null) {
      t.completedAt = todayStr();
    }
    _save();
  }

  void restoreTask(String id) {
    final t = taskById(id);
    if (t == null) return;
    t.archived = false;
    _save();
  }

  void deleteTask(String id) {
    Reminders.cancel(_notifId(id));
    tasks.removeWhere((t) => t.id == id);
    _save();
  }
}
