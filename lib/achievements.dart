import 'app_state.dart';
import 'models.dart';

/// A single milestone badge.
class Achievement {
  final String id;
  final String emoji;
  final String title;
  const Achievement(this.id, this.emoji, this.title);
}

/// Fixed catalogue, shown in Insights (earned = coloured, locked = greyed).
const List<Achievement> kAchievements = [
  Achievement('first', '🌱', 'First task done'),
  Achievement('done10', '✅', '10 completed'),
  Achievement('done50', '💪', '50 completed'),
  Achievement('done100', '🏆', '100 completed'),
  Achievement('streak3', '🔥', '3-day streak'),
  Achievement('streak7', '🔥', '7-day streak'),
  Achievement('streak30', '🏔️', '30-day streak'),
  Achievement('frog', '🐸', 'Ate the frog'),
  Achievement('focus1', '⏱️', 'First focus session'),
  Achievement('focus10', '🎯', '10 focus sessions'),
];

Achievement achievementById(String id) =>
    kAchievements.firstWhere((a) => a.id == id,
        orElse: () => const Achievement('?', '🏅', 'Achievement'));

/// The set of achievement ids the user has currently earned.
Set<String> earnedAchievements(AppState app) {
  final done = app.tasks.where((t) => t.status == TaskStatus.done).length;
  final streak = app.currentStreak();
  final ateFrog =
      app.tasks.any((t) => t.status == TaskStatus.done && t.frog);
  final focus = app.tasks.fold<int>(0, (s, t) => s + t.pomodoros);

  final e = <String>{};
  if (done >= 1) e.add('first');
  if (done >= 10) e.add('done10');
  if (done >= 50) e.add('done50');
  if (done >= 100) e.add('done100');
  if (streak >= 3) e.add('streak3');
  if (streak >= 7) e.add('streak7');
  if (streak >= 30) e.add('streak30');
  if (ateFrog) e.add('frog');
  if (focus >= 1) e.add('focus1');
  if (focus >= 10) e.add('focus10');
  return e;
}
