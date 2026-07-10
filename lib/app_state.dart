import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum AppTab { home, stats, archive }

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

  // ---- navigation / view state ----
  AppTab tab = AppTab.home;
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
      }
    } catch (_) {
      // first run / corrupt data — start clean
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storeKey,
        jsonEncode({
          'boards': boards.map((b) => b.toJson()).toList(),
          'tasks': tasks.map((t) => t.toJson()).toList(),
        }),
      );
    } catch (_) {
      // ignore; UI shows a toast at the call site if needed
    }
  }

  void _save() {
    notifyListeners();
    _persist();
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
  }) {
    final completedAt = status == TaskStatus.done
        ? (id != null && taskById(id)?.completedAt != null
            ? taskById(id)!.completedAt
            : todayStr())
        : null;

    if (id != null) {
      final t = taskById(id)!;
      t.name = name;
      t.date = date;
      t.person = person;
      t.note = note;
      t.status = status;
      t.prio = prio;
      t.completedAt = completedAt;
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
    tasks.removeWhere((t) => t.id == id);
    _save();
  }
}
