import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../achievements.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/heatmap.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.tasks;
    final act = app.activeTasks;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text('Insights', style: displayStyle(size: 30)),
          const SizedBox(height: 4),
          const Text('How your work is moving',
              style: TextStyle(fontSize: 14, color: AppColors.muted)),
        ],
      ),
    );

    if (all.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
        children: [
          header,
          const EmptyState(
            emoji: '📊',
            title: 'No data yet',
            body:
                'Add a few tasks and this screen will come to life — progress, '
                "overdue items, weekly pace and who's doing what.",
          ),
        ],
      );
    }

    final done = all.where((x) => x.status == TaskStatus.done).toList();
    final open = act.where((x) => x.status != TaskStatus.done).toList();
    final doing = act.where((x) => x.status == TaskStatus.doing).toList();
    final late = act.where(app.isLate).toList();
    final weekEnd = iso(DateTime.now().add(const Duration(days: 7)));
    final dueWeek = open
        .where((x) =>
            x.date != null &&
            x.date!.compareTo(todayStr()) >= 0 &&
            x.date!.compareTo(weekEnd) <= 0)
        .toList();
    final pct = all.isEmpty ? 0 : (done.length / all.length * 100).round();

    // last 7 days
    final days = <({String label, int n})>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key = iso(d);
      days.add((
        label: DateFormat('EEEEE').format(d), // narrow weekday
        n: done.where((x) => x.completedAt == key).length,
      ));
    }
    final maxDay = math.max(1, days.map((d) => d.n).fold(0, math.max));
    final weekDone = days.fold(0, (s, d) => s + d.n);

    // by board
    final boardRows = app.boards
        .map((b) {
          final bAll = all.where((x) => x.boardId == b.id).toList();
          final o = act
              .where((x) => x.boardId == b.id && x.status != TaskStatus.done)
              .length;
          return (name: b.name, color: b.color, open: o, total: bAll.length);
        })
        .where((r) => r.total > 0)
        .toList()
      ..sort((a, b) => b.open - a.open);
    final maxOpen = math.max(1, boardRows.map((r) => r.open).fold(0, math.max));

    // by person
    final people = <String, ({int open, int done, int late})>{};
    for (final x in all) {
      final p = x.person;
      if (p == null || p.isEmpty) continue;
      var rec = people[p] ?? (open: 0, done: 0, late: 0);
      if (x.status == TaskStatus.done) {
        rec = (open: rec.open, done: rec.done + 1, late: rec.late);
      } else if (!x.archived) {
        rec = (
          open: rec.open + 1,
          done: rec.done,
          late: rec.late + (app.isLate(x) ? 1 : 0)
        );
      }
      people[p] = rec;
    }
    final personRows = people.entries.toList()
      ..sort((a, b) => b.value.open - a.value.open);

    String ringMsg;
    if (late.isNotEmpty) {
      ringMsg =
          '${late.length} task${late.length > 1 ? 's are' : ' is'} overdue — worth a look first.';
    } else if (doing.isNotEmpty) {
      ringMsg = '${doing.length} in progress right now. Keep the momentum.';
    } else if (open.isEmpty) {
      ringMsg = 'Everything is done. Enjoy it while it lasts 😌';
    } else {
      ringMsg = "${open.length} open, nothing overdue. You're on top of it.";
    }
    final archCount = app.archivedTasks.length;

    // best day this week (from the 7-day breakdown)
    var bestN = 0;
    var bestLabel = '—';
    for (final d in days) {
      if (d.n > bestN) {
        bestN = d.n;
        bestLabel = d.label;
      }
    }
    // per-day completion counts for the heatmap
    final dayCounts = <String, int>{};
    for (final t in done) {
      final c = t.completedAt;
      if (c != null) dayCounts[c] = (dayCounts[c] ?? 0) + 1;
    }
    final earned = earnedAchievements(app);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
      children: [
        header,
        const SizedBox(height: 8),
        // stat cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _StatCard(num: '${open.length}', label: 'Open tasks'),
            _StatCard(num: '${done.length}', label: 'Completed (all time)'),
            _StatCard(
                num: '${late.length}',
                label: 'Overdue',
                numColor: late.isNotEmpty ? AppColors.danger : null),
            _StatCard(
                num: '${dueWeek.length}',
                label: 'Due this week',
                numColor: dueWeek.isNotEmpty ? AppColors.amber : null),
            _StatCard(num: '${app.currentStreak()}', label: 'Day streak 🔥'),
            _StatCard(
                num: '${all.fold<int>(0, (s, t) => s + t.pomodoros)}',
                label: 'Focus sessions ⏱️'),
          ],
        ),
        const SizedBox(height: 12),
        // ring card
        SoftCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: CustomPaint(
                  painter: _DonutPainter(pct / 100),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$pct%', style: displayStyle(size: 24)),
                        const Text('DONE',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overall progress',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: ringMsg),
                        if (archCount > 0)
                          TextSpan(
                              text: ' ($archCount in archive)',
                              style:
                                  const TextStyle(color: Color(0xFF98A4B1))),
                      ]),
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.muted, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 7-day chart
        _Panel(
          title: 'Completed in the last 7 days · $weekDone total',
          child: SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _DayCol(day: days[i], maxDay: maxDay)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // this week
        _Panel(
          title: 'This week',
          child: Row(
            children: [
              _MiniStat(value: '$weekDone', label: 'completed'),
              _MiniStat(value: bestLabel, label: 'best day'),
              _MiniStat(value: '${app.currentStreak()}', label: 'day streak'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // activity heatmap
        _Panel(title: 'Activity', child: Heatmap(counts: dayCounts)),
        const SizedBox(height: 12),
        // achievements
        _Panel(
          title: 'Achievements · ${earned.length}/${kAchievements.length}',
          child: _AchievementsGrid(earned: earned),
        ),
        // by board
        if (boardRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            title: 'Open tasks by board',
            child: Column(
              children: [
                for (final r in boardRows)
                  _HBar(
                    name: r.name,
                    color: AppColors.fromHex(r.color),
                    frac: r.open == 0 ? 0 : math.max(0.06, r.open / maxOpen),
                    value: '${r.open} open',
                  ),
              ],
            ),
          ),
        ],
        // by person
        if (personRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            title: 'By person',
            child: Column(
              children: [
                for (int i = 0; i < personRows.length; i++)
                  _PersonRow(
                    name: personRows[i].key,
                    stat: personRows[i].value,
                    color: AppColors
                        .boardPalette[i % AppColors.boardPalette.length],
                    last: i == personRows.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String num;
  final String label;
  final Color? numColor;
  const _StatCard({required this.num, required this.label, this.numColor});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(num, style: displayStyle(size: 30, color: numColor)),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: displayStyle(size: 26)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _AchievementsGrid extends StatelessWidget {
  final Set<String> earned;
  const _AchievementsGrid({required this.earned});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kAchievements.map((a) {
        final got = earned.contains(a.id);
        return Container(
          width: 96,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: got ? const Color(0xFFEAF6EC) : AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: got ? const Color(0xFF9FCBA6) : AppColors.line,
                width: 1.5),
          ),
          child: Column(
            children: [
              Opacity(
                opacity: got ? 1 : 0.35,
                child: Text(a.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(height: 6),
              Text(a.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: got ? AppColors.ink : AppColors.muted)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DayCol extends StatelessWidget {
  final ({String label, int n}) day;
  final int maxDay;
  const _DayCol({required this.day, required this.maxDay});

  @override
  Widget build(BuildContext context) {
    final h = day.n > 0 ? math.max(10.0, day.n / maxDay * 70) : 4.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(day.n > 0 ? '${day.n}' : '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Container(
          constraints: const BoxConstraints(maxWidth: 34),
          height: h,
          decoration: BoxDecoration(
            gradient: day.n > 0
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3C7C74), Color(0xFF2E86AB)])
                : null,
            color: day.n > 0 ? null : AppColors.line,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8), bottom: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 5),
        Text(day.label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted)),
      ],
    );
  }
}

class _HBar extends StatelessWidget {
  final String name;
  final Color color;
  final double frac; // 0..1
  final String value;
  const _HBar(
      {required this.name,
      required this.color,
      required this.frac,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Container(
                height: 12,
                color: AppColors.bg,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: frac.clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(99)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String name;
  final ({int open, int done, int late}) stat;
  final Color color;
  final bool last;
  const _PersonRow(
      {required this.name,
      required this.stat,
      required this.color,
      required this.last});

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(12)),
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text('${stat.open} open · ${stat.done} done',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          if (stat.late > 0)
            Text('⚠ ${stat.late} overdue',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger))
          else
            const Text('✅', style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double frac; // 0..1
  _DonutPainter(this.frac);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.line;
    canvas.drawCircle(center, radius, track);

    if (frac > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2E86AB);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * frac, false, arc);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.frac != frac;
}
