import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../suggestions.dart';
import '../theme.dart';
import 'common.dart';

/// Show the daily "Ideas for today" popup.
Future<void> showDailyIdeasSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x7316222F),
    builder: (_) => _IdeasSheet(initial: suggestionsForDay(todayStr())),
  );
}

class _IdeasSheet extends StatefulWidget {
  final List<Suggestion> initial;
  const _IdeasSheet({required this.initial});

  @override
  State<_IdeasSheet> createState() => _IdeasSheetState();
}

class _IdeasSheetState extends State<_IdeasSheet> {
  late List<Suggestion> _items = widget.initial;
  final Set<String> _added = {};
  String? _boardId;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _boardId = app.boards.isNotEmpty ? app.boards.first.id : null;
  }

  void _add(Suggestion s) {
    final app = context.read<AppState>();
    final bid = _boardId ?? app.ensureDefaultBoard();
    app.addSuggestedTask(bid, s.text);
    setState(() {
      _boardId = bid;
      _added.add(s.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
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
              const SheetHandle(),
              Text('Ideas for today ✨', style: displayStyle(size: 21)),
              const SizedBox(height: 4),
              const Text('Tap add to drop one into your list.',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
              const SizedBox(height: 14),

              // board selector
              if (app.boards.isNotEmpty)
                _BoardSelector(
                  boards: app.boards.map((b) => (b.id, b.name)).toList(),
                  selected: _boardId,
                  onSelect: (id) => setState(() => _boardId = id),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text("Will be added to a new 'Personal' board.",
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ),
              const SizedBox(height: 12),

              // suggestions
              ..._items.map((s) => _IdeaRow(
                    suggestion: s,
                    added: _added.contains(s.text),
                    onAdd: () => _add(s),
                  )),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _items = randomSuggestions();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('🔀  More ideas',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('Done',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardSelector extends StatelessWidget {
  final List<(String, String)> boards;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _BoardSelector(
      {required this.boards, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Add to:',
            style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (id, name) in boards)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onSelect(id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: id == selected ? AppColors.ink : AppColors.bg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(name,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: id == selected
                                    ? Colors.white
                                    : AppColors.muted)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IdeaRow extends StatelessWidget {
  final Suggestion suggestion;
  final bool added;
  final VoidCallback onAdd;
  const _IdeaRow(
      {required this.suggestion, required this.added, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(suggestion.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(suggestion.text,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: added ? null : onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: added ? const Color(0xFFEAF6EC) : AppColors.ink,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(added ? '✓ Added' : '＋ Add',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: added ? const Color(0xFF3B7A43) : Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
