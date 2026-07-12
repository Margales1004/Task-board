import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievements.dart';
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
  bool dailyNudges = true; // daily reminder notifications

  // Achievements already shown (so we only toast newly-earned ones).
  List<String> seenAchievements = [];
  // Achievement titles unlocked since the last UI consume (shown as a toast).
  final List<String> pendingUnlocks = [];

  // Daily "ideas for today" popup: last day shown + a pending flag for the UI.
  String? lastSuggestionsDay;
  bool pendingDailySuggestions = false;

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
          dailyNudges = (settings['dailyNudges'] as bool?) ?? dailyNudges;
          seenAchievements =
              (settings['seenAchievements'] as List?)?.cast<String>().toList() ??
                  seenAchievements;
          lastSuggestionsDay = settings['lastSuggestionsDay'] as String?;
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
    // Baseline achievements on first run after this update so existing progress
    // isn't announced retroactively.
    if (seenAchievements.isEmpty) {
      seenAchievements = earnedAchievements(this).toList();
    }
    // First open of a new day → queue the "ideas for today" popup.
    pendingDailySuggestions = lastSuggestionsDay != todayStr();
    _loaded = true;
    notifyListeners();
    // Ask for notification permission (native shell) and sync scheduled alerts.
    if (Reminders.available) {
      Reminders.requestPermission();
      _syncReminders();
      _scheduleNudges();
    }
  }

  /// The full persisted state as a plain map (used by [_persist] and by
  /// [exportJson] for backups).
  Map<String, dynamic> _snapshot() => {
        'boards': boards.map((b) => b.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'settings': {
          'dailyGoal': dailyGoal,
          'focusMinutes': focusMinutes,
          'breakMinutes': breakMinutes,
          'dailyNudges': dailyNudges,
          'seenAchievements': seenAchievements,
          'lastSuggestionsDay': lastSuggestionsDay,
        },
        'focus': {
          'taskId': focusTaskId,
          'isBreak': focusIsBreak,
          'endMs': focusEndMs,
          'paused': focusPausedRemaining,
        },
      };

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeKey, jsonEncode(_snapshot()));
    } catch (_) {
      // ignore; UI shows a toast at the call site if needed
    }
  }

  // ---------------- backup / restore ----------------
  /// A human-copyable JSON backup of all boards, tasks and settings.
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(_snapshot());

  /// Replace all data from a backup produced by [exportJson]. Returns false if
  /// the text can't be parsed as a valid backup (data is left untouched).
  Future<bool> importJson(String raw) async {
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw.trim()) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    // A valid backup must at least carry the boards/tasks arrays.
    if (decoded['boards'] is! List || decoded['tasks'] is! List) return false;
    try {
      boards = (decoded['boards'] as List)
          .map((e) => Board.fromJson(e as Map<String, dynamic>))
          .toList();
      tasks = (decoded['tasks'] as List)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
      final settings = decoded['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        dailyGoal = (settings['dailyGoal'] as num?)?.toInt() ?? dailyGoal;
        focusMinutes =
            (settings['focusMinutes'] as num?)?.toInt() ?? focusMinutes;
        breakMinutes =
            (settings['breakMinutes'] as num?)?.toInt() ?? breakMinutes;
        dailyNudges = (settings['dailyNudges'] as bool?) ?? dailyNudges;
        seenAchievements =
            (settings['seenAchievements'] as List?)?.cast<String>().toList() ??
                seenAchievements;
        lastSuggestionsDay =
            settings['lastSuggestionsDay'] as String? ?? lastSuggestionsDay;
      }
    } catch (_) {
      return false;
    }
    _save();
    if (Reminders.available) _scheduleNudges();
    return true;
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

  // ---------------- daily nudges (habit triggers) ----------------
  static const _nudgeIdBase = 2147481000; // reserved id band
  static const _nudgeIdCount = 30;

  /// Re-arm the rolling daily/weekly nudge notifications for the next 7 days.
  void _scheduleNudges() {
    for (var i = 0; i < _nudgeIdCount; i++) {
      Reminders.cancel(_nudgeIdBase + i);
    }
    if (!dailyNudges || !Reminders.available) return;
    final now = DateTime.now();
    final next = doNext();
    var id = _nudgeIdBase;
    for (var d = 0; d < 7 && id < _nudgeIdBase + _nudgeIdCount; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final morning = DateTime(day.year, day.month, day.day, 9);
      if (morning.isAfter(now)) {
        final body = d <= 1 && next != null
            ? "Today's focus: ${next.name}"
            : 'Plan your day and pick your top tasks.';
        Reminders.schedule(
            id: id++, title: 'Good morning ☀️', body: body, when: morning);
      }
      final evening = DateTime(day.year, day.month, day.day, 20);
      if (evening.isAfter(now)) {
        Reminders.schedule(
            id: id++,
            title: 'Keep your streak 🔥',
            body: 'Finish one task before the day ends.',
            when: evening);
      }
      if (day.weekday == DateTime.sunday) {
        final sun = DateTime(day.year, day.month, day.day, 18);
        if (sun.isAfter(now)) {
          Reminders.schedule(
              id: id++,
              title: 'Your week in review 📅',
              body: 'See what you accomplished this week.',
              when: sun);
        }
      }
    }
  }

  void setDailyNudges(bool value) {
    dailyNudges = value;
    _save();
    _scheduleNudges();
  }

  // ---------------- achievements ----------------
  /// Detect newly-earned achievements and queue them for a UI toast.
  void _checkAchievements() {
    final earned = earnedAchievements(this);
    final seen = seenAchievements.toSet();
    final fresh = earned.difference(seen);
    if (fresh.isEmpty) return;
    for (final id in fresh) {
      pendingUnlocks.add(achievementById(id).title);
    }
    seenAchievements = earned.toList();
  }

  // ---------------- daily idea suggestions ----------------
  void markSuggestionsShown() {
    lastSuggestionsDay = todayStr();
    pendingDailySuggestions = false;
    _save();
  }

  /// Board to drop a suggested task into: the first board, or a new "Personal"
  /// one if there are none yet.
  String ensureDefaultBoard() {
    if (boards.isNotEmpty) return boards.first.id;
    final id = uid();
    boards.add(Board(id: id, name: 'Personal', color: '#2E86AB'));
    _save();
    return id;
  }

  void addSuggestedTask(String boardId, String name) {
    saveTask(
      boardId: boardId,
      name: name,
      status: TaskStatus.todo,
      prio: TaskPrio.normal,
    );
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
    _checkAchievements();
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
    String? repeat,
    List<SubTask>? subtasks,
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
      t.boardId = boardId;
      t.name = name;
      t.date = date;
      t.person = person;
      t.note = note;
      t.status = status;
      t.prio = prio;
      t.completedAt = completedAt;
      t.frog = frog;
      t.remindAt = remindAt;
      t.repeat = repeat;
      if (subtasks != null) t.subtasks = subtasks;
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
        repeat: repeat,
        subtasks: subtasks,
      ));
    }
    _save();
  }

  /// Advance a date one recurrence step past today, so the next occurrence is
  /// never already overdue. Bases off [from] (or today if null).
  String _nextOccurrence(String? from, String repeat) {
    final today = DateTime.now();
    var d = from != null && from.isNotEmpty
        ? DateTime.parse('${from}T00:00:00')
        : DateTime(today.year, today.month, today.day);
    final floor = DateTime(today.year, today.month, today.day);
    // Step forward until strictly after today.
    do {
      switch (repeat) {
        case TaskRepeat.weekly:
          d = d.add(const Duration(days: 7));
          break;
        case TaskRepeat.monthly:
          d = DateTime(d.year, d.month + 1, d.day);
          break;
        case TaskRepeat.daily:
        default:
          d = d.add(const Duration(days: 1));
      }
    } while (!d.isAfter(floor));
    return iso(d);
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
      // Recurring task: spawn the next occurrence so the habit rolls forward.
      // The completed instance stays done (preserving streak/stats history).
      if (t.repeat != null && !t.archived) {
        final nextDate = _nextOccurrence(t.date, t.repeat!);
        String? nextRemind;
        if (t.remindAt != null) {
          final old = DateTime.tryParse(t.remindAt!);
          if (old != null) {
            final nd = DateTime.parse('${nextDate}T00:00:00');
            nextRemind = DateTime(
                    nd.year, nd.month, nd.day, old.hour, old.minute)
                .toIso8601String();
          }
        }
        tasks.add(Task(
          id: uid(),
          boardId: t.boardId,
          name: t.name,
          date: nextDate,
          person: t.person,
          note: t.note,
          prio: t.prio,
          remindAt: nextRemind,
          repeat: t.repeat,
          subtasks: t.subtasks.map((s) => SubTask(title: s.title)).toList(),
        ));
        // The completed instance is a one-off record now.
        t.repeat = null;
      }
    }
    _checkAchievements();
    _save();
  }

  /// Toggle a single checklist item on a task.
  void toggleSubtask(String taskId, int index) {
    final t = taskById(taskId);
    if (t == null || index < 0 || index >= t.subtasks.length) return;
    t.subtasks[index].done = !t.subtasks[index].done;
    _save();
  }

  /// Move a task's due date to tomorrow (quick procrastination triage).
  void snoozeToTomorrow(String id) {
    final t = taskById(id);
    if (t == null) return;
    final tm = DateTime.now().add(const Duration(days: 1));
    t.date = iso(tm);
    if (t.status == TaskStatus.done) {
      t.status = TaskStatus.todo;
      t.completedAt = null;
    }
    _save();
  }

  /// Re-add a previously-deleted task (used to undo a swipe-to-delete).
  void reinsertTask(Task t) {
    if (taskById(t.id) != null) return;
    tasks.add(t);
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
