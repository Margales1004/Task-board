/// Definitions for the "why am I stuck?" procrastination coach.
///
/// When a task is postponed repeatedly, instead of another reminder the app
/// asks what's blocking it and offers one concrete action per answer.
library;

/// The kind of action an answer maps to (handled in widgets/coach_sheet.dart).
enum CoachAction {
  breakIntoSteps, // open the checklist to split it up
  firstAction, // capture the smallest first step
  fiveMinutes, // start a short focus session
  moveToWaiting, // it's blocked on someone else
  badFirstDraft, // permission to do it badly, then a timer
  sprint, // a short timed sprint
  deleteIt, // let it go without guilt
}

class CoachReason {
  final String key; // stable id (stored in the reason tally)
  final String emoji;
  final String label; // the answer the user taps
  final String cta; // the action button label
  final String blurb; // one warm line describing the action
  final CoachAction action;

  const CoachReason({
    required this.key,
    required this.emoji,
    required this.label,
    required this.cta,
    required this.blurb,
    required this.action,
  });
}

const List<CoachReason> kCoachReasons = [
  CoachReason(
    key: 'too_big',
    emoji: '📦',
    label: "It's too big",
    cta: 'Break it into steps',
    blurb: "Let's split it into small pieces you can actually start.",
    action: CoachAction.breakIntoSteps,
  ),
  CoachReason(
    key: 'unclear',
    emoji: '🤔',
    label: "I'm not sure what to do",
    cta: 'Name the first step',
    blurb: "What's the smallest first action? We'll make that the start.",
    action: CoachAction.firstAction,
  ),
  CoachReason(
    key: 'no_energy',
    emoji: '🔋',
    label: 'I have no energy',
    cta: 'Just 5 minutes',
    blurb: 'Only five minutes — you can stop after. Starting is the hard part.',
    action: CoachAction.fiveMinutes,
  ),
  CoachReason(
    key: 'waiting',
    emoji: '⏳',
    label: "I'm waiting on someone",
    cta: 'Move to Waiting',
    blurb: "It'll stop nagging you and wait quietly until it's unblocked.",
    action: CoachAction.moveToWaiting,
  ),
  CoachReason(
    key: 'fear',
    emoji: '😰',
    label: "I'm afraid it won't be good",
    cta: 'Write a bad first draft',
    blurb: 'Do it badly on purpose for 10 minutes. You can fix it later.',
    action: CoachAction.badFirstDraft,
  ),
  CoachReason(
    key: 'boring',
    emoji: '🥱',
    label: "It's boring",
    cta: '10-minute sprint',
    blurb: 'Race the clock for 10 minutes, then reward yourself.',
    action: CoachAction.sprint,
  ),
  CoachReason(
    key: 'not_important',
    emoji: '🗑️',
    label: "It's not important anymore",
    cta: 'Let it go',
    blurb: 'Delete it — no guilt. Not everything deserves your time.',
    action: CoachAction.deleteIt,
  ),
];

CoachReason? coachReasonByKey(String? key) {
  for (final r in kCoachReasons) {
    if (r.key == key) return r;
  }
  return null;
}
