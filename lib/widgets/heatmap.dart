import 'package:flutter/material.dart';
import '../app_state.dart' show iso;
import '../theme.dart';

/// A GitHub-style contributions grid of daily task completions (last ~13 weeks).
class Heatmap extends StatelessWidget {
  final Map<String, int> counts; // 'yyyy-MM-dd' -> completed that day
  const Heatmap({super.key, required this.counts});

  static const _weeks = 13;
  static const _cell = 13.0;
  static const _gap = 3.0;

  Color _shade(int n) {
    if (n <= 0) return AppColors.line;
    if (n == 1) return const Color(0xFFBBD5E4);
    if (n == 2) return const Color(0xFF6FA8C6);
    return const Color(0xFF2E86AB);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayMid = DateTime(today.year, today.month, today.day);
    // Start on the Sunday of the week containing (today - (13w-1) days).
    var start = todayMid.subtract(const Duration(days: _weeks * 7 - 1));
    start = start.subtract(Duration(days: start.weekday % 7)); // Sun=0

    final columns = <Widget>[];
    var cursor = start;
    while (!cursor.isAfter(todayMid)) {
      final cells = <Widget>[];
      for (var r = 0; r < 7; r++) {
        final day = cursor.add(Duration(days: r));
        final future = day.isAfter(todayMid);
        cells.add(Container(
          width: _cell,
          height: _cell,
          margin: const EdgeInsets.only(bottom: _gap),
          decoration: BoxDecoration(
            color: future ? Colors.transparent : _shade(counts[iso(day)] ?? 0),
            borderRadius: BorderRadius.circular(3),
          ),
        ));
      }
      columns.add(Padding(
        padding: const EdgeInsets.only(right: _gap),
        child: Column(children: cells),
      ));
      cursor = cursor.add(const Duration(days: 7));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: columns),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Less',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(width: 6),
            for (final n in const [0, 1, 2, 3])
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: _cell,
                  height: _cell,
                  decoration: BoxDecoration(
                    color: _shade(n),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            const SizedBox(width: 3),
            const Text('More',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}
