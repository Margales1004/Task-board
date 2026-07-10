# My Boards — Flutter

A personal task-board app: create boards, add tasks with due dates, assignees,
priorities and statuses, track progress, review insights, and archive finished
work. This is a Flutter port of the original single-file HTML/CSS/JS prototype
(`taskboards.html`), rebuilt as a native mobile app while keeping the same look,
flow and behaviour.

## Features

- **Boards** — colour-coded boards, each a space for one topic. Progress bar and
  overdue count per board.
- **Coming up** — a horizontal strip of tasks due within the next 7 days.
- **Tasks** — name, note, due date, assignee, priority (Low / Normal / High 🔥)
  and status (To do / In progress / Done). Tap the checkbox to complete, tap the
  status chip to cycle.
- **Filters** — All / To do / In progress / Done / Overdue / High, per board.
- **Insights** — open/completed/overdue/due-this-week counts, an overall
  progress ring, a 7-day completion chart, open tasks by board, and a per-person
  breakdown.
- **Archive** — move completed tasks out of the way (still counted in stats),
  restore, or delete permanently.
- **Local persistence** — everything is stored on-device via
  `shared_preferences`, mirroring the browser `localStorage` of the original.

## Project layout

```
lib/
  main.dart              app entry, root scaffold, bottom nav + FAB
  theme.dart             colours, fonts, shadows (ported from the HTML :root)
  models.dart            Board and Task data models
  app_state.dart         ChangeNotifier state, date helpers, persistence
  screens/
    home_screen.dart     boards grid + "coming up"
    board_screen.dart    task list, filters, archive bar
    stats_screen.dart    insights (cards, ring, charts)
    archive_screen.dart  archived tasks
  widgets/
    common.dart          toast, tags, empty states, shared bits
    board_sheet.dart     create/edit board bottom sheet
    task_sheet.dart      create/edit task bottom sheet
assets/fonts/            bundled Assistant + Secular One (offline, no CDN)
```

## Running

```bash
flutter pub get
flutter run                 # on a connected device / emulator
```

Build releases:

```bash
flutter build apk           # Android
flutter build ios           # iOS (on macOS)
flutter build web           # Web
```

## Notes

- Fonts (Assistant for body, Secular One for headings) are **bundled as assets**,
  so text renders correctly offline — no runtime font download.
- Emoji (🗂️ 📊 🔥 …) render via the platform emoji font, exactly as in the
  original.
