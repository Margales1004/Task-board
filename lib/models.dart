/// Data models mirroring the objects stored in the HTML app's localStorage.
library;

class Board {
  String id;
  String name;
  String color; // stored as "#RRGGBB"

  Board({required this.id, required this.name, required this.color});

  factory Board.fromJson(Map<String, dynamic> j) => Board(
        id: j['id'] as String,
        name: j['name'] as String,
        color: (j['color'] as String?) ?? '#2E86AB',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
}

/// Task status values, matching the HTML strings exactly.
class TaskStatus {
  static const todo = 'todo';
  static const doing = 'doing';
  static const done = 'done';
  static const waiting = 'waiting'; // blocked on someone/something else
}

/// Task priority values, matching the HTML strings exactly.
class TaskPrio {
  static const low = 'low';
  static const normal = 'normal';
  static const high = 'high';
}

/// Recurrence values for repeating tasks (null = one-off).
class TaskRepeat {
  static const daily = 'daily';
  static const weekly = 'weekly';
  static const monthly = 'monthly';

  static const all = [daily, weekly, monthly];

  /// Short human label, e.g. "🔁 Daily".
  static String label(String? r) {
    switch (r) {
      case daily:
        return '🔁 Daily';
      case weekly:
        return '🔁 Weekly';
      case monthly:
        return '🔁 Monthly';
      default:
        return '';
    }
  }
}

/// A single checklist item inside a task.
class SubTask {
  String title;
  bool done;

  SubTask({required this.title, this.done = false});

  factory SubTask.fromJson(Map<String, dynamic> j) => SubTask(
        title: (j['title'] as String?) ?? '',
        done: (j['done'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {'title': title, 'done': done};
}

class Task {
  String id;
  String boardId;
  String name;
  String? date; // "yyyy-MM-dd"
  String? person;
  String? note;
  String status; // todo | doing | done
  String prio; // low | normal | high
  String? completedAt; // "yyyy-MM-dd"
  bool archived;
  bool frog; // "eat the frog" — the one most-important task
  String? remindAt; // ISO 8601 local datetime for a reminder notification
  int pomodoros; // completed focus sessions
  String? repeat; // null | daily | weekly | monthly
  List<SubTask> subtasks; // checklist items
  int deferCount; // how many times this task has been postponed
  String? blockReason; // last "why am I stuck?" answer (procrastination coach)

  Task({
    required this.id,
    required this.boardId,
    required this.name,
    this.date,
    this.person,
    this.note,
    this.status = TaskStatus.todo,
    this.prio = TaskPrio.normal,
    this.completedAt,
    this.archived = false,
    this.frog = false,
    this.remindAt,
    this.pomodoros = 0,
    this.repeat,
    List<SubTask>? subtasks,
    this.deferCount = 0,
    this.blockReason,
  }) : subtasks = subtasks ?? [];

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        boardId: j['boardId'] as String,
        name: j['name'] as String,
        date: j['date'] as String?,
        person: j['person'] as String?,
        note: j['note'] as String?,
        status: (j['status'] as String?) ?? TaskStatus.todo,
        prio: (j['prio'] as String?) ?? TaskPrio.normal,
        completedAt: j['completedAt'] as String?,
        archived: (j['archived'] as bool?) ?? false,
        frog: (j['frog'] as bool?) ?? false,
        remindAt: j['remindAt'] as String?,
        pomodoros: (j['pomodoros'] as num?)?.toInt() ?? 0,
        repeat: j['repeat'] as String?,
        subtasks: (j['subtasks'] as List?)
                ?.map((e) => SubTask.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        deferCount: (j['deferCount'] as num?)?.toInt() ?? 0,
        blockReason: j['blockReason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'boardId': boardId,
        'name': name,
        'date': date,
        'person': person,
        'note': note,
        'status': status,
        'prio': prio,
        'completedAt': completedAt,
        'archived': archived,
        'frog': frog,
        'remindAt': remindAt,
        'pomodoros': pomodoros,
        'repeat': repeat,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'deferCount': deferCount,
        'blockReason': blockReason,
      };
}
