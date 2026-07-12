import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../reminders.dart';
import '../speech.dart';
import '../theme.dart';
import 'board_sheet.dart' show SheetKit;
import 'common.dart';

/// Bottom sheet to create or edit a task. Pass [boardId] to preselect a board
/// (omit it — e.g. from the Today screen — to let the user pick one). Pass
/// [taskId] to edit an existing task.
Future<void> showTaskSheet(BuildContext context,
    {String? boardId, String? taskId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x7316222F),
    builder: (_) => _TaskSheet(boardId: boardId, taskId: taskId),
  );
}

class _TaskSheet extends StatefulWidget {
  final String? boardId;
  final String? taskId;
  const _TaskSheet({this.boardId, this.taskId});

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late TextEditingController _name;
  late TextEditingController _person;
  late TextEditingController _note;
  String? _boardId; // selected board for this task
  String? _date; // yyyy-MM-dd
  String _status = TaskStatus.todo;
  String _prio = TaskPrio.normal;
  bool _frog = false;
  DateTime? _remindAt;
  String? _repeat; // null | daily | weekly | monthly
  final List<TextEditingController> _subCtrls = [];
  final List<bool> _subDone = [];
  late TextEditingController _newSub;
  bool _deleteArmed = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final t = widget.taskId != null ? app.taskById(widget.taskId!) : null;
    _boardId = widget.boardId ??
        t?.boardId ??
        (app.boards.isNotEmpty ? app.boards.first.id : null);
    _name = TextEditingController(text: t?.name ?? '');
    _person = TextEditingController(text: t?.person ?? '');
    _note = TextEditingController(text: t?.note ?? '');
    _date = t?.date;
    _status = t?.status ?? TaskStatus.todo;
    _prio = t?.prio ?? TaskPrio.normal;
    _frog = t?.frog ?? false;
    _remindAt = t?.remindAt != null ? DateTime.tryParse(t!.remindAt!) : null;
    _repeat = t?.repeat;
    _newSub = TextEditingController();
    for (final s in t?.subtasks ?? const <SubTask>[]) {
      _subCtrls.add(TextEditingController(text: s.title));
      _subDone.add(s.done);
    }
  }

  @override
  void dispose() {
    if (_listening) Speech.stop();
    _name.dispose();
    _person.dispose();
    _note.dispose();
    _newSub.dispose();
    for (final c in _subCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSub() {
    final t = _newSub.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _subCtrls.add(TextEditingController(text: t));
      _subDone.add(false);
      _newSub.clear();
    });
  }

  void _removeSub(int i) {
    setState(() {
      _subCtrls.removeAt(i).dispose();
      _subDone.removeAt(i);
    });
  }

  List<SubTask> _collectSubtasks() {
    final out = <SubTask>[];
    for (var i = 0; i < _subCtrls.length; i++) {
      final title = _subCtrls[i].text.trim();
      if (title.isNotEmpty) out.add(SubTask(title: title, done: _subDone[i]));
    }
    return out;
  }

  Widget _boardField(AppState app) {
    if (app.boards.isEmpty) {
      return SheetKit.field(
        'Board',
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "A 'Personal' board will be created for this task.",
            style: TextStyle(fontSize: 13.5, color: AppColors.muted),
          ),
        ),
      );
    }
    return SheetKit.field(
      'Board',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: app.boards.map((b) {
          final sel = b.id == _boardId;
          final color = AppColors.fromHex(b.color);
          return GestureDetector(
            onTap: () => setState(() => _boardId = b.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? AppColors.ink : AppColors.bg,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                    color: sel ? AppColors.ink : AppColors.line, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(b.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.ink)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _checklistField() {
    return SheetKit.field(
      'Checklist (optional)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _subCtrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _subDone[i] = !_subDone[i]),
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _subDone[i] ? AppColors.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: _subDone[i] ? AppColors.ink : AppColors.line,
                            width: 2),
                      ),
                      child: _subDone[i]
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _subCtrls[i],
                      style: TextStyle(
                        fontSize: 15,
                        color: _subDone[i] ? AppColors.muted : AppColors.ink,
                        decoration: _subDone[i]
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Step',
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeSub(i),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Icon(Icons.add, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _newSub,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addSub(),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Add a step…',
                  ),
                ),
              ),
              GestureDetector(
                onTap: _addSub,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text('Add',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleVoice() {
    if (_listening) {
      Speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (!Speech.available) {
      Toast.show(context, 'Voice input works in the installed app.');
      return;
    }
    FocusScope.of(context).unfocus(); // hide the keyboard while dictating
    Speech.listen(
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _name.text = text;
          _name.selection = TextSelection.collapsed(offset: text.length);
        });
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    setState(() => _listening = true);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _date != null ? DateTime.parse('${_date}T00:00:00') : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = iso(picked));
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    // Default: the due date at 09:00, else tomorrow 09:00.
    final base = _remindAt ??
        (_date != null
            ? DateTime.parse('${_date}T09:00:00')
            : DateTime(now.year, now.month, now.day + 1, 9));
    final day = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (day == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (time == null) return;
    setState(() => _remindAt =
        DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  void _save() {
    final app = context.read<AppState>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      Toast.show(context, "What's the task?");
      return;
    }
    // Pick the chosen board, or spin up a default one if none exist yet.
    final boardId = _boardId ?? app.ensureDefaultBoard();
    app.saveTask(
      id: widget.taskId,
      boardId: boardId,
      name: name,
      date: _date,
      person: _person.text.trim().isEmpty ? null : _person.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      status: _status,
      prio: _prio,
      frog: _frog,
      remindAt: _remindAt?.toIso8601String(),
      repeat: _repeat,
      subtasks: _collectSubtasks(),
    );
    Navigator.of(context).pop();
    Toast.show(context, 'Saved');
  }

  void _archive() {
    context.read<AppState>().archiveTask(widget.taskId!);
    Navigator.of(context).pop();
    Toast.show(context, 'Moved to archive 🗄️');
  }

  void _delete() {
    if (!_deleteArmed) {
      setState(() => _deleteArmed = true);
      return;
    }
    context.read<AppState>().deleteTask(widget.taskId!);
    Navigator.of(context).pop();
    Toast.show(context, 'Deleted');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final isEdit = widget.taskId != null;
    final people = app.knownPeople;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SheetKit.shell(isEdit ? 'Edit task' : 'New task', [
        SheetKit.field(
          'What needs to get done?',
          TextField(
            controller: _name,
            autofocus: !isEdit,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: SheetKit.input('e.g. Send summary to the client').copyWith(
              suffixIcon: IconButton(
                onPressed: _toggleVoice,
                icon: Icon(_listening ? Icons.mic : Icons.mic_none,
                    color: _listening ? AppColors.danger : AppColors.muted),
                tooltip: 'Dictate',
              ),
            ),
          ),
        ),
        if (_listening)
          const Padding(
            padding: EdgeInsets.only(bottom: 14, top: 2),
            child: Text('Listening… speak your task',
                style: TextStyle(fontSize: 12.5, color: AppColors.danger)),
          ),
        _boardField(app),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SheetKit.field(
                'Due date',
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: SheetKit.input(''),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _date == null ? 'No date' : fmtDate(_date),
                          style: TextStyle(
                            color: _date == null
                                ? AppColors.muted
                                : AppColors.ink,
                            fontSize: 16,
                          ),
                        ),
                        if (_date != null)
                          GestureDetector(
                            onTap: () => setState(() => _date = null),
                            child: const Icon(Icons.close,
                                size: 18, color: AppColors.muted),
                          )
                        else
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SheetKit.field(
                'Assigned to',
                RawAutocomplete<String>(
                  textEditingController: _person,
                  focusNode: FocusNode(),
                  optionsBuilder: (v) {
                    if (v.text.isEmpty) return people;
                    return people.where((p) =>
                        p.toLowerCase().contains(v.text.toLowerCase()));
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmit) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLength: 30,
                    decoration: SheetKit.input('Name'),
                  ),
                  optionsViewBuilder: (context, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxHeight: 180, maxWidth: 220),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: options
                              .map((o) => ListTile(
                                    dense: true,
                                    title: Text(o),
                                    onTap: () => onSelected(o),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SheetKit.field(
          'Priority',
          _Segmented(
            options: const [
              ('low', 'Low', false),
              ('normal', 'Normal', false),
              ('high', 'High 🔥', true),
            ],
            value: _prio,
            onChanged: (v) => setState(() => _prio = v),
          ),
        ),
        SheetKit.field(
          'Status',
          _Segmented(
            options: const [
              ('todo', 'To do', false),
              ('doing', 'In progress', false),
              ('done', 'Done', false),
            ],
            value: _status,
            onChanged: (v) => setState(() => _status = v),
          ),
        ),
        // Repeat
        SheetKit.field(
          'Repeat',
          _Segmented(
            options: const [
              ('none', 'Once', false),
              ('daily', 'Daily', false),
              ('weekly', 'Weekly', false),
              ('monthly', 'Monthly', false),
            ],
            value: _repeat ?? 'none',
            onChanged: (v) =>
                setState(() => _repeat = v == 'none' ? null : v),
          ),
        ),
        if (_repeat != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 14, top: 2),
            child: Text(
              'When you complete it, the next one is created automatically.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        // Checklist / subtasks
        _checklistField(),
        // Reminder
        SheetKit.field(
          'Reminder',
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickReminder,
            child: InputDecorator(
              decoration: SheetKit.input(''),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _remindAt == null
                        ? 'No reminder'
                        : DateFormat('EEE, d MMM · HH:mm').format(_remindAt!),
                    style: TextStyle(
                      color: _remindAt == null ? AppColors.muted : AppColors.ink,
                      fontSize: 16,
                    ),
                  ),
                  if (_remindAt != null)
                    GestureDetector(
                      onTap: () => setState(() => _remindAt = null),
                      child: const Icon(Icons.close,
                          size: 18, color: AppColors.muted),
                    )
                  else
                    const Icon(Icons.notifications_none,
                        size: 18, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ),
        if (_remindAt != null && !Reminders.available)
          const Padding(
            padding: EdgeInsets.only(bottom: 14, top: 2),
            child: Text(
              'Reminders pop up in the installed app.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        // Eat the frog
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => setState(() => _frog = !_frog),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _frog ? AppColors.ink : AppColors.line, width: 1.5),
              ),
              child: Row(
                children: [
                  const Text('🐸', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Most important — do this first',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                  ),
                  Switch(
                    value: _frog,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.ink,
                    onChanged: (v) => setState(() => _frog = v),
                  ),
                ],
              ),
            ),
          ),
        ),
        SheetKit.field(
          'Note (optional)',
          TextField(
            controller: _note,
            maxLength: 400,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                SheetKit.input('Details, a link, a reminder to yourself...'),
          ),
        ),
        const SizedBox(height: 6),
        SheetKit.actions(() => Navigator.pop(context), _save),
        if (isEdit)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _archive,
                  child: const Text('🗄️ Move to archive',
                      style: TextStyle(
                          color: AppColors.muted, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 18),
                TextButton(
                  onPressed: _delete,
                  child: Text(_deleteArmed ? 'Sure? Tap again to delete' : 'Delete',
                      style: const TextStyle(
                          color: AppColors.danger, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ]),
    );
  }
}

/// Segmented button row (`.seg`). Third tuple element = "is the high/danger style".
class _Segmented extends StatelessWidget {
  final List<(String, String, bool)> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _Segmented(
      {required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _button(options[i])),
        ],
      ],
    );
  }

  Widget _button((String, String, bool) o) {
    final sel = o.$1 == value;
    final danger = o.$3;
    Color bg, fg, border;
    if (sel && danger) {
      bg = const Color(0xFFFBE9E9);
      fg = AppColors.danger;
      border = AppColors.danger;
    } else if (sel) {
      bg = AppColors.ink;
      fg = Colors.white;
      border = AppColors.ink;
    } else {
      bg = AppColors.bg;
      fg = AppColors.muted;
      border = AppColors.line;
    }
    return GestureDetector(
      onTap: () => onChanged(o.$1),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(o.$2,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}
