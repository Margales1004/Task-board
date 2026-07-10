import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'board_sheet.dart' show SheetKit;
import 'common.dart';

/// Bottom sheet to create or edit a task on [boardId]. Pass [taskId] to edit.
Future<void> showTaskSheet(BuildContext context,
    {required String boardId, String? taskId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x7316222F),
    builder: (_) => _TaskSheet(boardId: boardId, taskId: taskId),
  );
}

class _TaskSheet extends StatefulWidget {
  final String boardId;
  final String? taskId;
  const _TaskSheet({required this.boardId, this.taskId});

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late TextEditingController _name;
  late TextEditingController _person;
  late TextEditingController _note;
  String? _date; // yyyy-MM-dd
  String _status = TaskStatus.todo;
  String _prio = TaskPrio.normal;
  bool _deleteArmed = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final t = widget.taskId != null ? app.taskById(widget.taskId!) : null;
    _name = TextEditingController(text: t?.name ?? '');
    _person = TextEditingController(text: t?.person ?? '');
    _note = TextEditingController(text: t?.note ?? '');
    _date = t?.date;
    _status = t?.status ?? TaskStatus.todo;
    _prio = t?.prio ?? TaskPrio.normal;
  }

  @override
  void dispose() {
    _name.dispose();
    _person.dispose();
    _note.dispose();
    super.dispose();
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

  void _save() {
    final app = context.read<AppState>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      Toast.show(context, "What's the task?");
      return;
    }
    app.saveTask(
      id: widget.taskId,
      boardId: widget.boardId,
      name: name,
      date: _date,
      person: _person.text.trim().isEmpty ? null : _person.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      status: _status,
      prio: _prio,
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
            decoration: SheetKit.input('e.g. Send summary to the client'),
          ),
        ),
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
