# Hackathon Manager App — MVP Design

Version 1.1 · 17 Oct 2026 · Implements the "MVP (single device, local only)" release row of the
Hackathon Manager App PRD v1.0.

## 1. What this is

A personal offline-first app that keeps every hackathon, its deadlines, its reminders, and the
user's team in one place. This design covers the MVP release only: local storage, no account, no
cross-device sync.

**In scope:** FR-1 through FR-20, plus the P1 calendar view (FR-21) because it is a read-only
projection over data the MVP already owns and costs little.

**Out of scope (v1.0, designed for but not built):** FR-22 (submission checklist), FR-23 (post-event
closeout), FR-24 to FR-27 (accounts, sync, export, deletion), FR-28 to FR-30 (email escalation,
calendar sync, URL import). The sync seam is designed for these and stubbed, not faked.

## 2. Goals

- Never miss a Critical deadline.
- Answer "which team am I with for this hackathon?" in one glance.
- Everything works with no network.
- A hackathon with three milestones can be added in under 60 seconds.

## 3. Non-goals

Team chat, code hosting, hackathon discovery, organizer tooling, team matching, payments.
The non-goals list is normative: a later "just add chat" request is a scope change, not a feature.

## 4. Architecture

Flutter, Riverpod for state, Drift (SQLite) as the on-device source of truth,
`flutter_local_notifications` for alarms.

```
lib/
  main.dart
  engine/            pure Dart. NO Flutter imports. All P0 correctness lives here.
    models.dart          enums, DTOs, value types
    timezone_util.dart   zone registry + parsing, DST-safe math. Pure Dart.
    priority.dart        FR-3
    offset_schedule.dart FR-6
    reminder_planner.dart
    conflict_detector.dart   FR-20
    quiet_hours.dart   FR-9
  data/
    database.dart         drift tables + DAO
    db_provider.dart
    repository.dart       all reads and writes go through here
    change_log.dart    FR-5, FR-17
    sync.dart             SyncRepository stub for v1.0
  services/
    scheduler.dart        owns flutter_local_notifications and rescheduling
    test_data.dart        seed data for desktop verification
  ui/
    app.dart, theme.dart
    today/            FR-19
    hackathons/       FR-1
    hackathon_detail/ FR-2 to FR-5
    team/             FR-13 to FR-18
    calendar/         FR-21
    settings/
test/
  engine/             pure unit tests
  services/           scheduler against a FakeNotifier
```

### 4.1 The engine is a pure Dart layer

`lib/engine/` imports nothing from `package:flutter/` and no Drift or notification package. It
takes dates and config in and returns decisions. Consequences:

- Reminder cadence arithmetic, quiet-hour suppression, conflict windows, and Critical
  classification are unit-testable on desktop in milliseconds, with no plugin mock plumbing.
- The P0 logic is provable rather than eyeballed. Missing a submission is the app's only real
  failure mode, so that logic gets exhaustively tested and stays free of platform coupling.
- The same engine can run in a widget test to assert what a screen should show.

**Rule: nothing in `lib/engine/` may import Flutter.** Enforced by review and by the test suite
running under the plain Dart VM.

### 4.2 Timezone model

A hackathon's organizer timezone is a named IANA zone (`America/New_York`). A milestone stores the
instant as a UTC microsecond **plus** the declared zone. This lets the app show the organizer's
local wall-clock time while firing the alarm at a precise instant, and it means a date change can
be detected without silently shifting the user's alarm by an hour across a DST boundary.

`DateTime` values crossing the engine boundary are always UTC. Wall-clock strings are rendered by
the UI from the instant plus the declared zone, never stored as a string.

### 4.3 Sync seam

```dart
abstract interface class SyncRepository {
  Future<void> onMutation();        // FR-25: enqueue a sync when online
  Future<SyncStatus> syncNow();
  Stream<SyncStatus> get statusStream;
  Future<void> applyRemoteChanges(List<RemoteChange> changes);  // FR-26 merge rules
}
```

`LocalOnlySyncRepository` is a no-op returning `SyncStatus.offline`. FR-25's sync indicator renders
"Local only" from this. FR-26's latest-edit-wins merge rules are specified in section 7 so the data
model already records what merging will need: a `modifiedAt` on every writable row.

## 5. Data model

Drift tables. `id` is an integer PK; `createdAt`/`modifiedAt` are UTC microseconds.

### hackathons
`id`, `name`, `organizer`, `url`, `mode` (enum `online`|`inPerson`|`hybrid`), `location`,
`organizerTimezone` (IANA), `status` (enum `upcoming`|`running`|`done`|`archived`),
`createdAt`, `modifiedAt` — FR-1

### milestones
`id`, `hackathonId` (FK, cascade), `label`, `title`, `startsAtUtc` nullable, `endsAtUtc` nullable,
`timezone` (IANA, may differ from the hackathon's), `isCritical` (bool, set by FR-3, user can
override), `criticalReason` nullable, `sourceUrl` nullable, `verified` (bool, default false),
`note`, `createdAt`, `modifiedAt` — FR-2, FR-3, FR-4

A milestone has either a window (`startsAtUtc`…`endsAtUtc`, used for the event window that conflict
detection needs) or a point (`endsAtUtc` only). `endsAtUtc` is the moment to remind about; the FR-6
offsets count backwards from it.

### milestone_changes  — FR-5
`id`, `milestoneId` (FK), `changedField` (enum), `oldValue`, `newValue`, `changedAtUtc`.
Every date, title, or label edit appends a row before the change writes. Deletion is soft: setting
`hackathons.status = 'archived'` keeps the history.

### teams
`id`, `hackathonId` (FK), `name`, `status` (enum `looking`|`applied`|`invited`|`confirmed`|`left`|
`disbanded`|`solo`), `ideaTitle`, `techStack`, `repoUrl`, `chatUrl`, `notes`, `maxSize` nullable,
`createdAt`, `modifiedAt` — FR-13, FR-14

### team_members
`id`, `teamId` (FK, cascade), `name`, `role`, `contact`, `isLead` — FR-13

### team_changes  — FR-17
`id`, `teamId` (FK), `changeType` (enum `created`|`memberAdded`|`memberRemoved`|`memberUpdated`|
`statusChanged`), `entityLabel`, `oldValue`, `newValue`, `changedAtUtc`

### reminder_states
`id`, `key` (unique, `"m{milestoneId}#{n}"`), `milestoneId` (FK), `scheduleIndex` (int),
`profile` (string), `firesAtUtc`, `priority` (enum), `state` (enum `scheduled`|`fired`|`done`|
`snoozed`|`skipped`|`repeatArmed`), `repeatCount`, `armedAtUtc` nullable, `updatedAtUtc`

## 6. Reminder engine

### 6.1 Cadences — FR-6

| Priority | Offsets before the milestone |
|---|---|
| Critical | 7d, 3d, 1d, 6h, 1h, 15m |
| High | 3d, 1d, 1h |
| Normal | 1d, 30m |

`offset_schedule.dart` owns these tables. `ReminderProfile` (FR-12) scales them:
`Standard` uses the table, `Intense` prepends 4h to Critical and 4h to High, `Minimal` keeps only
1d and 1h. Profiles multiply the table, they do not redefine it.

### 6.2 Priority classification — FR-3

A milestone is Critical when its `label` is `registrationClose` or `finalSubmission`, or its title
matches the known organizer phrasing ("registration closes", "final submission"). The label
match wins; the user can override either way and the override is final. High is
`preparing`|`pitch`|`demo`|`interviews`; everything else is Normal. The classifier returns a
`criticalReason` so the UI can explain why something is Critical.

### 6.3 Planning

`ReminderPlanner.plan(Milestone, ReminderProfile, DateTime now)` returns the set of
`ScheduledReminder` instances with `firesAtUtc = endsAtUtc - offset`. Planning is idempotent per
`(milestoneId, scheduleIndex, profile)`: re-running after a date change removes and re-adds only the
reminders whose computed time moved. Past fire times are dropped, never scheduled into the past.

### 6.4 Reminder state machine

```
Scheduled --show--> Fired --Done--> Done (terminal)
                   Fired --Snooze 1h / tomorrow--> Snoozed --show--> Fired
                   Fired --Skip--> Skipped (terminal)
                   Fired --ignored 30m--> RepeatArmed (repeatCount < 3) --show--> Fired
                   Fired --ignored 30m, repeatCount == 3--> Skipped
```

Only **Critical** reminders repeat (FR-8). State transitions persist before the notification is
shown, so a crash mid-notification cannot double-fire or resurrect an acknowledged reminder.

### 6.5 Quiet hours — FR-9

Quiet hours are user-set local-hour bounds. During them, `Normal` and `High` reminders are
suppressed and re-queued for the first permitted minute; `Critical` fires regardless. Suppression is
decided by `quiet_hours.dart` at show time, not by skipping the alarm, so the alarm record is
always the source of truth.

### 6.6 Reliability — FR-10, NFR

Reminders fire offline and survive app restart and reboot. Implementation: schedule exact-time
alarms via `flutter_local_notifications` with `allowWhileIdle` and, on Android, the exact-alarm
permission requested at first schedule with a user-facing guide if it is denied. On restart the
scheduler replans from `reminder_states` so no alarm is lost to an app update.

The scheduler's decision logic is tested against a `FakeNotifier`; only the thin adapter that calls
the plugin is untested in this environment.

## 7. Teams

FR-13, FR-14: as specified by the `teams`/`team_members` tables above.

FR-15: adding a second `Confirmed` team for the same hackathon raises a warning, not a blocker.
FR-16: the roster count is compared to `teams.maxSize` and warns on overflow.
FR-17: every membership or status change appends to `team_changes`.
FR-18: the My Teams view lists hackathon, team, team status, and next deadline — computed as the
earliest non-past milestone for that hackathon, one query.

## 8. Conflicts — FR-20

`ConflictDetector` returns a list of `Conflict` records, each tagged `type`, `severity`, and a
one-line message:

- **Overlapping windows** — two non-archived hackathons whose windows intersect.
- **Close Critical deadlines** — two Critical milestones within 24 hours of each other.
- **Orphaned** — a hackathon in `upcoming` or `running` with no `Confirmed` team.

Each hackathon carries a `Primary`/`Backup`/none role per conflict; marking one Primary suppresses
the warning for its paired hackathon. Conflicts are computed on demand, never stored, so they stay
consistent without a sync path.

## 9. Views

- **Today (FR-19)** — next 7 days of deadlines grouped by day, hackathons without a confirmed team,
  unresolved conflicts. Loads in under one second with 100 hackathons (NFR).
- **Hackathons** — list with mode, status, next deadline.
- **Hackathon detail** — milestones with timezone, Verified toggle, source link, change log.
- **My Teams (FR-18)** — per PRD.
- **Calendar (FR-21)** — month grid of milestones, color-coded by priority.
- **Settings** — reminder profile, quiet hours, timezone, data overview.

Material 3, dark-first with a deliberate accent, designed for one-handed mobile use and read in one
glance. Empty states are designed, not left blank.

## 10. Error handling and invariants

- Timezone strings are validated against the known zone list at entry; an unknown zone is rejected
  with a message, never stored, because a bad zone silently mis-fires every reminder for that event.
- A milestone without `endsAtUtc` cannot be created.
- Every milestone date edit logs before it writes (FR-5); a failed log aborts the write.
- Archiving is the only delete path; it preserves change history.
- Repository writes are transactional per user action, so a half-saved hackathon cannot exist.

## 11. Testing

- **Engine unit tests** — cadence arithmetic including DST crossings, quiet-hour boundary at
  exactly the limit, conflict window at exactly 24 hours, Critical classification and override,
  replan-after-date-change idempotency, reminder state machine including the 3-repeat cap.
- **Scheduler tests** — against `FakeNotifier`, asserting which notifications fire, when, and
  which transitions persist.
- **Widget tests** — add-hackathon flow, Today view rendering with seed data, team status
  lifecycle, conflict warning surfacing.

Not verifiable in this environment and marked as such at delivery: actual OS alarm delivery on a
physical device, Android battery-optimization exemption behaviour, and Windows notification
behaviour with the app fully closed (PRD risk #2). These need a device or emulator.

## 12. Delivery verification

`flutter run -d windows` observed in a browser preview, plus the engine and scheduler suites green.
A desktop-only build is the verification vehicle; the Android project is generated and configured
but not compiled without a device.
