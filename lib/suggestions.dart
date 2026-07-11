import 'dart:math';

/// A suggested task idea shown in the daily "Ideas for today" popup.
class Suggestion {
  final String emoji;
  final String text;
  const Suggestion(this.emoji, this.text);
}

// Curated idea library, grouped by area of life. The daily popup picks a fresh,
// balanced mix from these so there's always something to reach for.
const _home = <String>[
  'Tidy one drawer',
  'Water the plants',
  'Change the bedsheets',
  'Wipe the kitchen counters',
  'Take out the recycling',
  'Declutter one shelf',
  'Clean out the fridge',
  'Do a load of laundry',
  'Organize the entryway',
  'Dust the living room',
];

const _family = <String>[
  'Call your mom',
  'Call your dad',
  'Check in on a grandparent',
  'Plan a family dinner',
  'Send your parents a photo',
  'Ask a parent how they are',
];

const _friends = <String>[
  'Message a friend you miss',
  'Plan a coffee with a friend',
  'Wish someone happy birthday',
  'Reply to that friend',
  'Invite a friend for a walk',
];

const _shopping = <String>[
  'Buy groceries',
  'Restock coffee or tea',
  'Order household supplies',
  'Buy a birthday gift',
  'Refill toiletries',
  'Make a shopping list',
];

const _selfcare = <String>[
  'Take a 15-minute walk',
  'Drink a glass of water',
  'Stretch for 5 minutes',
  'Go to bed 30 min earlier',
  'Read for 10 minutes',
  'Book a checkup',
];

const _errands = <String>[
  'Pay a bill',
  'Renew a subscription',
  'Reply to an important email',
  'Back up your phone',
  'Schedule an appointment',
  'Return something borrowed',
];

const _categories = <(String, List<String>)>[
  ('🏠', _home),
  ('👪', _family),
  ('🧑‍🤝‍🧑', _friends),
  ('🛒', _shopping),
  ('💆', _selfcare),
  ('📋', _errands),
];

List<Suggestion> _pick(Random rng) {
  // One idea from each category → a balanced set of six, in random order.
  final out = <Suggestion>[
    for (final (emoji, list) in _categories)
      Suggestion(emoji, list[rng.nextInt(list.length)]),
  ]..shuffle(rng);
  return out;
}

/// Deterministic pick for a given day ('yyyy-MM-dd') — stable across reopens
/// that day, and different day to day.
List<Suggestion> suggestionsForDay(String dayIso) {
  final seed = dayIso.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
  return _pick(Random(seed));
}

/// A fresh random set (for the "more ideas" / shuffle button).
List<Suggestion> randomSuggestions() => _pick(Random());
