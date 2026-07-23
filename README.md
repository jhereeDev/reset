# Reset

**Small actions. Big change.** Reset is an offline-first habit-building app for
people who want to rebuild or improve themselves through simple daily actions —
100 push-ups, 10,000 steps, one chapter, making the bed. Encouraging, personal,
and never guilt-tripping.

Built with Flutter for **Android and iOS**.

## Features

- **Onboarding** — name, improvement goals (Fitness, Health, Mind, Discipline,
  Productivity, Personal care), difficulty level (scales suggested targets),
  starter habits with adjustable amounts, and a preferred reminder time.
- **Today screen** — greeting, date, rotating motivational message, animated
  progress ring, overall daily streak, and habit cards with per-type controls:
  quick-add (+10 push-ups, +500 steps), exact-value entry, and one-tap
  completion for yes/no habits. Completions animate, give light haptic
  feedback, show an encouraging message, and can be undone. Long-press to
  reorder.
- **Habit management** — create/edit habits with icon, color, category,
  tracking type (yes/no, count, duration, steps, pages, chapters, servings,
  custom unit), target, unit, schedule (daily, specific weekdays, N times per
  week), per-habit reminder, and start date. Pause, archive (history is kept),
  delete (with confirmation), and reorder.
- **Reset Mode** — structured fresh starts: 7-Day Restart, 21-Day Discipline
  Reset, 30-Day Better Me. Preview and customize the habit set before
  starting. The active plan shows current day, days remaining, today's
  completion, overall progress, and successful days. Missing a day never
  cancels a plan.
- **Progress** — current/best overall streak, weekly completion %, weekly
  calendar and bar chart, total completed actions, and per-habit detail views
  (streaks, completion rate, last 7 days, last 30 days, historical values).
  Complete / partial / missed / upcoming days are visually distinct.
- **Profile & settings** — name, goals, general daily reminder, week start
  (Mon/Sun), light/dark/system theme, JSON data export, full data reset, and
  an About page. Debug builds include a "Load demo data" helper.
- **Backups & restore (v1.1)** — a silent daily snapshot to app storage
  (last 7 kept), a Backups sheet with restore + back-up-now, paste-JSON
  import with merge/replace modes, and an onboarding card that offers to
  restore data found from a previous install.

Everything works fully offline. No account, no backend, no analytics.

## Architecture

Feature-first layout with a shared core:

```
lib/
  main.dart              # bootstrap: prefs preload, notification init
  app/                   # root widget + app-wide providers (DB, repos, ...)
  core/
    constants/           # centralized strings, icon registry
    database/            # Drift schema (habits, entries, reset plans)
    notifications/       # NotificationService (+ no-op fallback)
    routing/             # GoRouter config, bottom-nav shell
    steps/               # StepSource abstraction (manual / future health)
    theme/               # color, spacing, radius tokens; Material 3 themes
    utilities/           # date keys, streak calculator
    widgets/             # progress ring, empty/error/loading states, dialogs
  features/
    onboarding/          # multi-step flow + starter habit templates
    habits/              # domain models, repositories (abstract + Drift), form
    today/               # Today screen, habit cards, derived providers
    reset/               # preset plans, plan stats, plan screens
    progress/            # weekly stats, per-habit statistics
    profile/             # preferences, export, demo data, about
```

Key decisions:

- **State**: Riverpod 3 (`Notifier` + `StreamProvider`s over Drift watch
  queries). Widgets contain no business logic; derived state lives in
  providers, write operations in small action classes.
- **Persistence**: Drift (SQLite). Repositories are abstract interfaces
  (`HabitRepository`, `HabitEntryRepository`, `ResetPlanRepository`) so a
  cloud-synced implementation can be swapped in later. Preferences use
  `SharedPreferences`.
- **Dates**: every entry is keyed by a local-timezone `yyyy-MM-dd` string,
  with a unique `(habit, date)` constraint — timezone/DST shifts cannot create
  duplicate days. Future dates cannot be logged.
- **Navigation**: GoRouter with a `StatefulShellRoute` for the four tabs;
  a redirect guards onboarding.

### Streak rules (documented behavior)

- A habit is complete when its daily value reaches its target. Values are
  clamped to ≥ 0; setting a day back to 0 removes the entry (undo).
- **Per-habit streak**: only *scheduled* days count; rest days are skipped and
  never break a streak. Today never breaks a streak while incomplete. For
  "N times per week" habits, every completed day extends the streak, and gap
  days are forgiven if that week met its quota (or is still in progress).
- **Overall daily streak**: a day succeeds when every habit *due* that day
  (daily/weekday schedules) is completed. Days with nothing due are neutral.
  Flexible (times-per-week) habits can never break a day — they only add wins.

## Main packages

| Package | Purpose |
| --- | --- |
| `flutter_riverpod` | state management |
| `go_router` | navigation |
| `drift` + `drift_flutter` | local SQLite persistence |
| `fl_chart` | weekly bar chart |
| `flutter_local_notifications` + `timezone` + `flutter_timezone` | local reminders |
| `intl` | date formatting |
| `shared_preferences` | user preferences |
| `uuid` | stable ids |

## Setup

```sh
flutter pub get

# Regenerate Drift database code after changing lib/core/database/:
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device / emulator:
flutter run
```

### Tests, formatting, analysis

```sh
dart format .
flutter analyze
flutter test
```

Tests cover streak calculation, schedule logic, completion/progress rules,
reset-plan day math, Drift repository operations (in-memory database), and the
main Today-screen completion flow (widget test).

## Notifications

- Per-habit daily reminders and one general daily check-in, scheduled with
  `zonedSchedule` in the device's local timezone.
- Permission is requested when a reminder is first enabled; every path is
  wrapped so the app functions normally if permission is denied or the
  platform lacks the plugin.
- Reminders are rescheduled/cancelled when habits are saved, paused,
  archived, or deleted, and when settings change.

## Current limitations

- Steps are entered manually; there is no automatic step sync yet (see below).
- Crash reporting (Sentry) is compiled in but dormant: it activates only when
  built with `--dart-define=SENTRY_DSN=...`, sends crashes only (no
  analytics/PII), and requires a privacy-policy update before enabling.
- Streaks treat a habit's *current* status/schedule as authoritative for past
  days (status changes are not backdated).
- Single locale (English) UI strings, centralized and ready for localization.
- One active reset plan at a time.

## Future: HealthKit / Health Connect

Step tracking is isolated behind the `StepSource` interface
(`lib/core/steps/step_source.dart`). The shipped implementation is
`ManualStepSource`; `HealthStepSource` is a clearly-labeled placeholder that
reports itself unavailable. The integration plan:

1. Add the `health` package (wraps HealthKit on iOS and Health Connect on
   Android).
2. Implement `HealthStepSource.stepsForDate` with read-only step queries.
3. Request health permissions only when the user opts into automatic steps.
4. Merge strategy: automatic readings pre-fill the day's steps entry; manual
   edits always win. No health data is ever fabricated.
