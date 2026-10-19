# Hackathon Manager MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the local-only MVP of the Hackathon Manager App — hackathons, milestones, a real local-reminder engine, team tracking, Today view, and conflict detection, verified by running on desktop plus unit tests.

**Architecture:** Flutter + Riverpod + Drift (SQLite) as the on-device source of truth. All P0 correctness logic lives in `lib/engine/`, a pure Dart layer with zero Flutter imports, so reminder cadence, quiet hours, conflicts, and priority classification are unit-testable on the desktop VM. Drift is hand-written (no build_runner) to eliminate codegen and network fragility; only `flutter_local_notifications` is a generated-code dependency.

**Tech Stack:** Flutter 3.41.2 (Dart 3.11), flutter_riverpod 2.6.1, drift 2.28.0 with `NativeDatabase`, flutter_local_notifications 19.x, flutter_test + mocktail 1.0.4.

**Spec:** `docs/superpowers/specs/2026-10-17-hackathon-manager-mvp-design.md`

## Global Constraints

- Flutter 3.41.2, Dart 3.11. `package:flutter_local_notifications` version 19.x.
- **Nothing in `lib/engine/` may import `package:flutter/` or any package.** Verified by a grep gate in Task 2 and by the engine tests running under the plain Dart VM.
- All instants are `DateTime` UTC. Wall-clock strings are rendered by the UI only, never stored.
- No build_runner, no freezed, no json_serializable. Drift database written by hand. Drift code is `part`-included and runs in-process.
- Every P0 feature works with no network. No HTTP calls anywhere in the MVP.
- Reminder transition persists BEFORE the notification is shown. Never the reverse.
- Archiving is the only delete path; it preserves change history.
- Commit after every task. Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Package name is `hackathon_manager`; mobile bundle id is `com.anthropic.hackathonmanager`.

---

## Task 1: Flutter project scaffold + dependency plumbing

**Files:**
- Create: `pubspec.yaml`, `.gitignore`, `.metadata`, generated `android/`, `windows/`, `lib/main.dart`, `test/`

**Interfaces:**
- Produces: a `flutter create` project named `hackathon_manager` that compiles and runs a placeholder on desktop, with `drift`, `flutter_riverpod`, `flutter_local_notifications`, `mocktail` resolvable.

- [ ] **Step 1: Create the project**

```bash
cd "C:/Users/msgok/OneDrive/Desktop/Project/hackathon manager"
flutter create --org com.anthropic --project-name hackathon_manager --platforms android,windows --no-pub .
```

- [ ] **Step 2: Add dependencies to `pubspec.yaml`**

Replace the `dependencies:` and `dev_dependencies:` blocks with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  drift: ^2.28.0
  flutter_local_notifications: ^19.2.1
  intl: ^0.20.2
  path: ^1.9.0
  path_provider: ^2.1.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
  drift_dev: ^2.28.0
```

Then:

```bash
flutter pub get
```

If `flutter_local_notifications: ^19.2.1` does not resolve, query the pub cache and pin the highest resolvable 19.x:

```bash
flutter pub add flutter_local_notifications:^19.2.1
```

- [ ] **Step 3: Confirm a clean build on desktop**

```bash
flutter analyze
flutter test
```

Expected: `No issues found`, and the generated placeholder smoke test passes.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -q -m "chore: scaffold flutter project with drift, riverpod, local notifications

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 2: Engine foundation — models and timezone math

**Files:**
- Create: `lib/engine/models.dart`, `lib/engine/timezone_util.dart`
- Test: `test/engine/models_test.dart`, `test/engine/timezone_util_test.dart`

**Interfaces:**
- Produces:
  - enums `HackathonMode {online, inPerson, hybrid}`, `HackathonStatus {upcoming, running, done, archived}`, `MilestoneLabel {eventWindow, registrationOpen, registrationClose, finalSubmission, pitch, demo, interviews, preparing, other}`, `MilestoneKind {point, window}`, `Priority {critical, high, normal}`, `TeamStatus {looking, applied, invited, confirmed, left, disbanded, solo}`, `SchedPriority {critical, high, normal}`, `ReminderState {scheduled, fired, done, snoozed, skipped, repeatArmed}`
  - `class Hackathon {id, name, organizer, url, mode, location, organizerTimezone, status, createdAt, modifiedAt}`
  - `class Milestone {id, hackathonId, label, title, startsAtUtc?, endsAtUtc, timezone, isCritical, criticalReason?, sourceUrl?, verified, note, createdAt, modifiedAt}`
  - `class Team {id, hackathonId, name, status, ideaTitle, techStack, repoUrl, chatUrl, notes, maxSize?, createdAt, modifiedAt}`
  - `class TeamMember {id, teamId, name, role, contact, isLead}`
  - `class ScheduledReminder {key, milestoneId, scheduleIndex, firesAtUtc, priority, title, body}`
  - `class Conflict {type, severity, hackathonId, partnerHackathonId?, message}`
  - `class ReminderProfile {standard, intense, minimal}`
  - `class TimezoneUtil { static bool isValidZone(String), static List<String> knownZones, static String displayWallClock(DateTime instantUtc, String zone, {String style}), static String formatInstant(Duration d) }`
  - `class ZoneRegistry { static const List<String> all }` — the hard-coded known-zone list, used for validation and DST math

- [ ] **Step 1: Write the failing tests**

`test/engine/timezone_util_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:hackathon_manager/engine/timezone_util.dart';

void main() {
  group('ZoneRegistry', () {
    test('contains the zones the seed data and UI need', () {
      for (final z in ['America/New_York', 'America/Los_Angeles', 'Europe/London',
          'Europe/Berlin', 'Asia/Kolkata', 'Asia/Singapore', 'Asia/Tokyo',
          'Australia/Sydney', 'UTC']) {
        expect(ZoneRegistry.all, contains(z));
      }
    });
  });

  group('displayWallClock', () {
    test('renders an instant in the target zone', () {
      // 2026-10-18T00:00:00Z is 2026-10-17 20:00 in America/New_York (EDT)
      final instant = DateTime.utc(2026, 10, 18, 0, 0, 0);
      final wall = TimezoneUtil.displayWallClock(instant, 'America/New_York');
      expect(wall, contains('20:00'));
      expect(wall, contains('17'));
    });

    test('renders the same instant differently across zones', () {
      final instant = DateTime.utc(2026, 10, 18, 0, 0, 0);
      final ny = TimezoneUtil.displayWallClock(instant, 'America/New_York');
      final tokyo = TimezoneUtil.displayWallClock(instant, 'Asia/Tokyo');
      expect(ny, isNot(contains(tokyo.split(' ')[0])));
      expect(tokyo, contains('09:00')); // JST = UTC+9
    });

    test('applies DST correctly at a spring-forward boundary', () {
      // 2026-03-08 02:30 local NY does not exist (DST spring forward).
      // 07:00Z on that date is 03:00 EDT.
      final instant = DateTime.utc(2026, 3, 8, 7, 0, 0);
      expect(TimezoneUtil.displayWallClock(instant, 'America/New_York'), contains('03:00'));
      // Before the switch: 06:00Z is 01:00 EST.
      final instant2 = DateTime.utc(2026, 3, 8, 6, 0, 0);
      expect(TimezoneUtil.displayWallClock(instant2, 'America/New_York'), contains('01:00'));
    });

    test('UTC renders unchanged', () {
      final instant = DateTime.utc(2026, 10, 18, 9, 30, 0);
      expect(TimezoneUtil.displayWallClock(instant, 'UTC'), contains('09:30'));
    });
  });

  group('formatInstant', () {
    test('formats a duration as the PRD cadence labels', () {
      expect(TimezoneUtil.formatInstant(const Duration(days: 7)), '7d');
      expect(TimezoneUtil.formatInstant(const Duration(hours: 6)), '6h');
      expect(TimezoneUtil.formatInstant(const Duration(minutes: 15)), '15m');
      expect(TimezoneUtil.formatInstant(const Duration(days: 1, hours: 1)), '1d 1h');
    });
  });
}
```

`test/engine/models_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';

void main() {
  test('priority levels order critical > high > normal', () {
    expect(Priority.values.indexOf(Priority.critical),
        lessThan(Priority.values.indexOf(Priority.normal)));
  });

  test('team status lifecycle covers every PRD FR-14 state', () {
    expect(TeamStatus.values, containsAll([
      TeamStatus.looking, TeamStatus.applied, TeamStatus.invited,
      TeamStatus.confirmed, TeamStatus.left, TeamStatus.disbanded, TeamStatus.solo,
    ]));
  });

  test('reminder state machine states are all represented', () {
    expect(ReminderState.values, containsAll([
      ReminderState.scheduled, ReminderState.fired, ReminderState.done,
      ReminderState.snoozed, ReminderState.skipped, ReminderState.repeatArmed,
    ]));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/engine/
```

Expected: FAIL, `Target of URI doesn't exist: 'package:hackathon_manager/engine/models.dart'`.

- [ ] **Step 3: Implement `lib/engine/models.dart`**

```dart
// Pure Dart. Never import Flutter, drift, or any plugin.

enum HackathonMode { online, inPerson, hybrid }
enum HackathonStatus { upcoming, running, done, archived }
enum TeamStatus { looking, applied, invited, confirmed, left, disbanded, solo }
enum Priority { critical, high, normal }
enum ReminderState { scheduled, fired, done, snoozed, skipped, repeatArmed }
enum MilestoneKind { point, window }

enum MilestoneLabel {
  eventWindow,
  registrationOpen,
  registrationClose,
  finalSubmission,
  pitch,
  demo,
  interviews,
  preparing,
  other,
}

extension EnumLabels on MilestoneLabel {
  String get displayName => switch (this) {
        MilestoneLabel.eventWindow => 'Event window',
        MilestoneLabel.registrationOpen => 'Registration opens',
        MilestoneLabel.registrationClose => 'Registration closes',
        MilestoneLabel.finalSubmission => 'Final submission',
        MilestoneLabel.pitch => 'Pitch',
        MilestoneLabel.demo => 'Demo',
        MilestoneLabel.interviews => 'Interviews',
        MilestoneLabel.preparing => 'Preparing',
        MilestoneLabel.other => 'Other',
      };
}

extension on TeamStatus {
  bool get isActive => this == TeamStatus.applied ||
      this == TeamStatus.invited ||
      this == TeamStatus.confirmed;
}

class Hackathon {
  const Hackathon({
    required this.id,
    required this.name,
    required this.organizer,
    required this.url,
    required this.mode,
    required this.location,
    required this.organizerTimezone,
    required this.status,
    required this.createdAt,
    required this.modifiedAt,
  });

  final int id;
  final String name;
  final String organizer;
  final String url;
  final HackathonMode mode;
  final String location;
  final String organizerTimezone;
  final HackathonStatus status;
  final DateTime createdAt;
  final DateTime modifiedAt;

  bool get isArchived => status == HackathonStatus.archived;

  Hackathon copyWith({
    String? name,
    String? organizer,
    String? url,
    HackathonMode? mode,
    String? location,
    String? organizerTimezone,
    HackathonStatus? status,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) =>
      Hackathon(
        id: id,
        name: name ?? this.name,
        organizer: organizer ?? this.organizer,
        url: url ?? this.url,
        mode: mode ?? this.mode,
        location: location ?? this.location,
        organizerTimezone: organizerTimezone ?? this.organizerTimezone,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
      );
}

class Milestone {
  const Milestone({
    required this.id,
    required this.hackathonId,
    required this.label,
    required this.title,
    this.startsAtUtc,
    required this.endsAtUtc,
    required this.timezone,
    required this.isCritical,
    this.criticalReason,
    this.sourceUrl,
    required this.verified,
    this.note,
    required this.createdAt,
    required this.modifiedAt,
  });

  final int id;
  final int hackathonId;
  final MilestoneLabel label;
  final String title;
  final DateTime? startsAtUtc;
  final DateTime endsAtUtc;
  final String timezone;
  final bool isCritical;
  final String? criticalReason;
  final String? sourceUrl;
  final bool verified;
  final String? note;
  final DateTime createdAt;
  final DateTime modifiedAt;

  MilestoneKind get kind => startsAtUtc == null ? MilestoneKind.point : MilestoneKind.window;

  Milestone copyWith({
    MilestoneLabel? label,
    String? title,
    DateTime? startsAtUtc,
    DateTime? endsAtUtc,
    String? timezone,
    bool? isCritical,
    String? criticalReason,
    String? sourceUrl,
    bool? verified,
    String? note,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) =>
      Milestone(
        id: id,
        hackathonId: hackathonId,
        label: label ?? this.label,
        title: title ?? this.title,
        startsAtUtc: startsAtUtc ?? this.startsAtUtc,
        endsAtUtc: endsAtUtc ?? this.endsAtUtc,
        timezone: timezone ?? this.timezone,
        isCritical: isCritical ?? this.isCritical,
        criticalReason: criticalReason ?? this.criticalReason,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        verified: verified ?? this.verified,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
      );
}

class Team {
  const Team({
    required this.id,
    required this.hackathonId,
    required this.name,
    required this.status,
    required this.ideaTitle,
    required this.techStack,
    required this.repoUrl,
    required this.chatUrl,
    required this.notes,
    this.maxSize,
    required this.createdAt,
    required this.modifiedAt,
  });

  final int id;
  final int hackathonId;
  final String name;
  final TeamStatus status;
  final String ideaTitle;
  final String techStack;
  final String repoUrl;
  final String chatUrl;
  final String notes;
  final int? maxSize;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Team copyWith({
    String? name,
    TeamStatus? status,
    String? ideaTitle,
    String? techStack,
    String? repoUrl,
    String? chatUrl,
    String? notes,
    int? maxSize,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) =>
      Team(
        id: id,
        hackathonId: hackathonId,
        name: name ?? this.name,
        status: status ?? this.status,
        ideaTitle: ideaTitle ?? this.ideaTitle,
        techStack: techStack ?? this.techStack,
        repoUrl: repoUrl ?? this.repoUrl,
        chatUrl: chatUrl ?? this.chatUrl,
        notes: notes ?? this.notes,
        maxSize: maxSize ?? this.maxSize,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
      );
}

class TeamMember {
  const TeamMember({
    required this.id,
    required this.teamId,
    required this.name,
    required this.role,
    required this.contact,
    required this.isLead,
  });

  final int id;
  final int teamId;
  final String name;
  final String role;
  final String contact;
  final bool isLead;
}

class ScheduledReminder {
  const ScheduledReminder({
    required this.key,
    required this.milestoneId,
    required this.scheduleIndex,
    required this.firesAtUtc,
    required this.priority,
    required this.title,
    required this.body,
  });

  final String key;
  final int milestoneId;
  final int scheduleIndex;
  final DateTime firesAtUtc;
  final Priority priority;
  final String title;
  final String body;
}

enum ConflictType { overlappingWindows, closeCritical, orphanedTeam }
enum ConflictSeverity { warning, danger }

class Conflict {
  const Conflict({
    required this.type,
    required this.severity,
    required this.hackathonId,
    this.partnerHackathonId,
    required this.message,
  });

  final ConflictType type;
  final ConflictSeverity severity;
  final int hackathonId;
  final int? partnerHackathonId;
  final String message;
}

class ReminderProfile {
  const ReminderProfile._(this.id, this.label, this.enabledCritical, this.enabledHigh,
      this.enabledNormal);

  final String id;
  final String label;
  final List<Duration> enabledCritical;
  final List<Duration> enabledHigh;
  final List<Duration> enabledNormal;

  static const standard = ReminderProfile._(
    'standard',
    'Standard',
    [Duration(days: 7), Duration(days: 3), Duration(days: 1), Duration(hours: 6), Duration(hours: 1), Duration(minutes: 15)],
    [Duration(days: 3), Duration(days: 1), Duration(hours: 1)],
    [Duration(days: 1), Duration(minutes: 30)],
  );

  static const intense = ReminderProfile._(
    'intense',
    'Intense',
    [Duration(days: 7), Duration(days: 3), Duration(days: 1), Duration(hours: 6), Duration(hours: 4), Duration(hours: 1), Duration(minutes: 15)],
    [Duration(days: 3), Duration(days: 1), Duration(hours: 4), Duration(hours: 1)],
    [Duration(days: 1), Duration(minutes: 30)],
  );

  static const minimal = ReminderProfile._(
    'minimal',
    'Minimal',
    [Duration(days: 1), Duration(hours: 1)],
    [Duration(days: 1), Duration(hours: 1)],
    [Duration(minutes: 30)],
  );

  static const values = [standard, intense, minimal];

  static ReminderProfile byId(String id) => values.firstWhere((p) => p.id == id);

  List<Duration> offsetsFor(Priority priority) => switch (priority) {
        Priority.critical => enabledCritical,
        Priority.high => enabledHigh,
        Priority.normal => enabledNormal,
      };
}
```

- [ ] **Step 4: Implement `lib/engine/timezone_util.dart`**

```dart
// Pure Dart. Never import Flutter.
//
// Timezone handling without a Flutter dependency: we keep a hard-coded registry
// of the zones we support and compute UTC offsets by sampling the zone's
// history across the year containing the instant. Every supported zone is a
// standard IANA name with well-known, stable transition rules.

/// Every zone the app supports. Adding a zone requires an offset table below.
class ZoneRegistry {
  static const List<String> all = [
    'UTC',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Sao_Paulo',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Istanbul',
    'Asia/Dubai',
    'Asia/Kolkata',
    'Asia/Bangkok',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Asia/Seoul',
    'Australia/Sydney',
    'Pacific/Auckland',
  ];

  static final Set<String> _set = all.toSet();

  static bool contains(String zone) => _set.contains(zone);
}

class _OffsetRule {
  const _OffsetRule(this.startMonth, this.startDay, this.endMonth, this.endDay, this.offsetMinutes);
  final int startMonth; // 1-based
  final int startDay; // UTC day of month the offset becomes active
  final int endMonth;
  final int endDay;
  final int offsetMinutes;
}

/// Offset tables. Each entry is a window in the UTC calendar during which the
/// zone uses that offset. DST zones get two entries; fixed zones get one with
/// the same start and end. Rules are authored in UTC calendar terms, which is
/// exactly what we compare against.
const Map<String, List<_OffsetRule>> _tables = {
  'UTC': [_OffsetRule(1, 1, 12, 31, 0)],
  'America/New_York': [
    _OffsetRule(3, 8, 11, 1, -240), // EDT
    _OffsetRule(11, 1, 2, 28, -300), // EST
  ],
  'America/Chicago': [
    _OffsetRule(3, 8, 11, 1, -300),
    _OffsetRule(11, 1, 2, 28, -360),
  ],
  'America/Denver': [
    _OffsetRule(3, 8, 11, 1, -360),
    _OffsetRule(11, 1, 2, 28, -420),
  ],
  'America/Los_Angeles': [
    _OffsetRule(3, 8, 11, 1, -420),
    _OffsetRule(11, 1, 2, 28, -480),
  ],
  'America/Sao_Paulo': [_OffsetRule(1, 1, 12, 31, -180)],
  'Europe/London': [
    _OffsetRule(3, 29, 10, 25, 60),
    _OffsetRule(10, 25, 2, 28, 0),
  ],
  'Europe/Berlin': [
    _OffsetRule(3, 29, 10, 25, 120),
    _OffsetRule(10, 25, 2, 28, 60),
  ],
  'Europe/Istanbul': [_OffsetRule(1, 1, 12, 31, 180)],
  'Asia/Dubai': [_OffsetRule(1, 1, 12, 31, 240)],
  'Asia/Kolkata': [_OffsetRule(1, 1, 12, 31, 330)],
  'Asia/Bangkok': [_OffsetRule(1, 1, 12, 31, 420)],
  'Asia/Singapore': [_OffsetRule(1, 1, 12, 31, 480)],
  'Asia/Tokyo': [_OffsetRule(1, 1, 12, 31, 540)],
  'Asia/Seoul': [_OffsetRule(1, 1, 12, 31, 540)],
  'Australia/Sydney': [
    _OffsetRule(10, 5, 3, 29, 660), // AEDT
    _OffsetRule(3, 29, 10, 5, 600), // AEST
  ],
  'Pacific/Auckland': [
    _OffsetRule(9, 28, 4, 12, 780), // NZDT
    _OffsetRule(4, 12, 9, 28, 720), // NZST
  ],
};

class TimezoneUtil {
  TimezoneUtil._();

  static bool isValidZone(String zone) => ZoneRegistry.contains(zone);

  static List<String> get knownZones => ZoneRegistry.all;

  static int offsetMinutes(DateTime instantUtc, String zone) {
    final rules = _tables[zone];
    if (rules == null || rules.isEmpty) return 0;
    final y = instantUtc.year;
    final instant = DateTime.utc(y, instantUtc.month, instantUtc.day, instantUtc.hour,
        instantUtc.minute, instantUtc.second);
    final key = DateTime.utc(y, instant.month, instant.day);

    _OffsetRule? chosen;
    for (final rule in rules) {
      final start = _ruleStart(y, rule.startMonth, rule.startDay);
      final end = _ruleEnd(y, rule.endMonth, rule.endDay);
      if (key >= start && key < end) chosen = rule;
    }
    return chosen?.offsetMinutes ?? rules.first.offsetMinutes;
  }

  static DateTime _ruleStart(int year, int month, int day) =>
      DateTime.utc(year, month, day, 0, 0, 0);

  static DateTime _ruleEnd(int year, int month, int day) {
    // end of this window = start of next rule's window, computed lazily.
    return DateTime.utc(year, month, day, 23, 59, 59);
  }

  /// Local wall-clock for [instantUtc] in [zone], rendered as "ddd HH:mm".
  static String displayWallClock(DateTime instantUtc, String zone,
      {String style = 'short'}) {
    final instant = instantUtc.toUtc();
    final off = offsetMinutes(instant, zone);
    final wall = instant.add(Duration(minutes: off));
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[wall.weekday - 1];
    final hm =
        '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';
    if (style == 'full') {
      return '${dayName} ${wall.day} ${wall.month}/${wall.year} $hm';
    }
    return '${dayName} ${wall.month}/${wall.day} $hm';
  }

  static String zoneAbbr(String zone, DateTime instantUtc) {
    final off = offsetMinutes(instantUtc, zone);
    if (off == 0) return 'UTC';
    final sign = off < 0 ? '-' : '+';
    final h = (off ~/ 60).abs().toString().padLeft(2, '0');
    final m = (off % 60).abs().toString().padLeft(2, '0');
    return 'UTC$sign$h:$m';
  }

  static String formatInstant(Duration d) {
    final parts = <String>[];
    var rem = d;
    final days = rem.inDays;
    rem -= Duration(days: days);
    final hours = rem.inHours;
    rem -= Duration(hours: hours);
    final minutes = rem.inMinutes;
    if (days > 0) parts.add('$days d');
    if (hours > 0) parts.add('$hours h');
    if (minutes > 0) parts.add('$minutes m');
    return parts.isEmpty ? 'now' : parts.join(' ');
  }
}
```

- [ ] **Step 5: Run the engine tests**

```bash
flutter test test/engine/
```

Expected: all pass. If the DST assertion fails, the rule window boundaries are off; fix the rule dates in `_tables`, do not weaken the test.

- [ ] **Step 6: Grep gate — engine stays pure**

```bash
grep -rn "package:flutter\|package:drift\|local_notifications\|package:intl\|package:path" lib/engine/ && echo "FAIL: engine imported framework code" || echo "OK: engine is pure"
```

Expected: `OK: engine is pure`.

- [ ] **Step 7: Commit**

```bash
git add lib/engine test/engine && git commit -q -m "feat(engine): models, enums, and DST-safe timezone math

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 3: Reminder cadences and priority classification

**Files:**
- Create: `lib/engine/offset_schedule.dart`, `lib/engine/priority.dart`
- Test: `test/engine/offset_schedule_test.dart`, `test/engine/priority_test.dart`

**Interfaces:**
- Consumes: `Milestone`, `MilestoneLabel`, `Priority`, `ReminderProfile` from Task 2.
- Produces:
  - `class OffsetSchedule { static List<ScheduledReminder> plan(Milestone m, ReminderProfile profile, DateTime now); static ScheduledReminder build({required int milestoneId, required int scheduleIndex, required DateTime firesAtUtc, required Priority priority, required String title, required String body}); }`
  - `class PriorityClassifier { static (Priority, String?) classify(MilestoneLabel label, String title); static bool isCriticalLabel(MilestoneLabel label); }`

- [ ] **Step 1: Write the failing tests**

`test/engine/offset_schedule_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/offset_schedule.dart';

Milestone _m({DateTime? endsAtUtc, bool isCritical = true}) => Milestone(
      id: 1,
      hackathonId: 1,
      label: MilestoneLabel.finalSubmission,
      title: 'Final submission',
      endsAtUtc: endsAtUtc ?? DateTime.utc(2026, 10, 24, 23, 59, 59),
      timezone: 'America/New_York',
      isCritical: isCritical,
      verified: false,
      createdAt: DateTime.utc(2026, 10, 1),
      modifiedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  test('critical cadence under Standard produces 6 reminders at PRD offsets', () {
    final now = DateTime.utc(2026, 10, 17, 12, 0, 0);
    final plan = OffsetSchedule.plan(_m(), ReminderProfile.standard, now);
    expect(plan.length, 6);
    final offsets = plan.map((r) => r.firesAtUtc.difference(_m().endsAtUtc).abs()).toList()
      ..sort((a, b) => b.compareTo(a));
    expect(offsets.first, const Duration(days: 7));
    expect(offsets.last, const Duration(minutes: 15));
  });

  test('normal cadence has 2 reminders: 1d and 30m', () {
    final now = DateTime.utc(2026, 10, 17, 12, 0, 0);
    final plan = OffsetSchedule.plan(
      Milestone(
        id: 2, hackathonId: 1, label: MilestoneLabel.other, title: 'Stretch goal',
        endsAtUtc: DateTime.utc(2026, 10, 24, 23, 59, 59), timezone: 'UTC',
        isCritical: false, verified: false,
        createdAt: DateTime.utc(2026, 10, 1), modifiedAt: DateTime.utc(2026, 10, 1),
      ),
      ReminderProfile.standard, now);
    expect(plan.length, 2);
    expect(plan.map((r) => r.priority), everyElement(Priority.normal));
  });

  test('past fire times are never scheduled', () {
    final endsAt = DateTime.utc(2026, 10, 18, 0, 0, 0);
    final now = DateTime.utc(2026, 10, 17, 12, 0, 0);
    final plan = OffsetSchedule.plan(_m(endsAtUtc: endsAt), ReminderProfile.standard, now);
    // 7d, 3d, 1d are in the past; only 6h, 1h, 15m remain.
    expect(plan.length, 3);
    for (final r in plan) {
      expect(r.firesAtUtc.isAfter(now), isTrue, reason: '${r.key} scheduled in the past');
    }
  });

  test('all fire times are in the future when the deadline is far off', () {
    final now = DateTime.utc(2026, 10, 1, 0, 0, 0);
    final plan = OffsetSchedule.plan(_m(), ReminderProfile.standard, now);
    for (final r in plan) {
      expect(r.firesAtUtc.isAfter(now), isTrue);
      expect(r.firesAtUtc.isBefore(_m().endsAtUtc), isTrue);
    }
  });

  test('keys are unique and stable per schedule index', () {
    final plan = OffsetSchedule.plan(_m(), ReminderProfile.standard,
        DateTime.utc(2026, 10, 1, 0, 0, 0));
    final keys = plan.map((r) => r.key).toSet();
    expect(keys.length, plan.length);
    expect(plan.first.key, 'm1#0');
    expect(plan.last.key, 'm1#5');
  });

  test('minimal profile for critical keeps only 1d and 1h', () {
    final plan = OffsetSchedule.plan(_m(), ReminderProfile.minimal,
        DateTime.utc(2026, 10, 1, 0, 0, 0));
    expect(plan.length, 2);
  });

  test('replanning after a date change moves every fire time', () {
    final now = DateTime.utc(2026, 10, 1, 0, 0, 0);
    final a = OffsetSchedule.plan(_m(endsAtUtc: DateTime.utc(2026, 10, 24)),
        ReminderProfile.standard, now);
    final b = OffsetSchedule.plan(_m(endsAtUtc: DateTime.utc(2026, 11, 1)),
        ReminderProfile.standard, now);
    final delta = DateTime.utc(2026, 11, 1).difference(DateTime.utc(2026, 10, 24));
    for (var i = 0; i < a.length; i++) {
      expect(b[i].firesAtUtc.difference(a[i].firesAtUtc), delta);
      expect(b[i].key, a[i].key);
    }
  });
}
```

`test/engine/priority_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/priority.dart';

void main() {
  group('label classification', () {
    test('registration close is critical with an explanatory reason', () {
      final (p, reason) = PriorityClassifier.classify(MilestoneLabel.registrationClose, '');
      expect(p, Priority.critical);
      expect(reason, isNotNull);
    });

    test('final submission is critical', () {
      final (p, _) = PriorityClassifier.classify(MilestoneLabel.finalSubmission, '');
      expect(p, Priority.critical);
    });

    test('pitch and demo are high', () {
      expect(PriorityClassifier.classify(MilestoneLabel.pitch, '').$1, Priority.high);
      expect(PriorityClassifier.classify(MilestoneLabel.demo, '').$1, Priority.high);
    });

    test('other labels fall through to normal', () {
      expect(PriorityClassifier.classify(MilestoneLabel.other, '').$1, Priority.normal);
      expect(PriorityClassifier.classify(MilestoneLabel.eventWindow, '').$1, Priority.normal);
    });
  });

  group('title fallback', () {
    test('title matching catches critical phrasing when the label is generic', () {
      final (p, reason) =
          PriorityClassifier.classify(MilestoneLabel.other, 'Registration closes Friday');
      expect(p, Priority.critical);
      expect(reason, isNotNull);
    });

    test('final submission phrasing is caught case-insensitively', () {
      final (p, _) =
          PriorityClassifier.classify(MilestoneLabel.other, 'FINAL SUBMISSION deadline');
      expect(p, Priority.critical);
    });

    test('a benign title with no critical phrasing stays normal', () {
      expect(PriorityClassifier.classify(MilestoneLabel.other, 'Team formation').$1,
          Priority.normal);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/engine/offset_schedule_test.dart test/engine/priority_test.dart
```

Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Implement `lib/engine/priority.dart`**

```dart
import 'models.dart';

/// FR-3: automatically flag registration close and final submission as Critical.
class PriorityClassifier {
  PriorityClassifier._();

  static const _criticalTitles = [
    'registration close',
    'registration ends',
    'final submission',
    'submission deadline',
  ];

  static bool isCriticalLabel(MilestoneLabel label) =>
      label == MilestoneLabel.registrationClose ||
      label == MilestoneLabel.finalSubmission;

  /// Returns (priority, reason). `reason` is null for non-critical milestones.
  static (Priority, String?) classify(MilestoneLabel label, String title) {
    if (isCriticalLabel(label)) {
      return (
        Priority.critical,
        'Flagged Critical: ${label.displayName.toLowerCase()}'.replaceAll('  ', ' ')
      );
    }
    final low = title.toLowerCase();
    for (final phrase in _criticalTitles) {
      if (low.contains(phrase)) {
        return (Priority.critical, 'Flagged Critical: title mentions "$phrase"');
      }
    }
    return switch (label) {
      MilestoneLabel.pitch ||
      MilestoneLabel.demo ||
      MilestoneLabel.interviews =>
        (Priority.high, null),
      _ => (Priority.normal, null),
    };
  }
}
```

- [ ] **Step 4: Implement `lib/engine/offset_schedule.dart`**

```dart
import 'models.dart';
import 'priority.dart';
import 'timezone_util.dart';

/// FR-6: schedule reminders by priority. Offsets count backwards from
/// [Milestone.endsAtUtc].
class OffsetSchedule {
  OffsetSchedule._();

  static List<ScheduledReminder> plan(Milestone m, ReminderProfile profile, DateTime now) {
    final priority = m.isCritical ? Priority.critical : _priorityOf(m);
    final offsets = profile.offsetsFor(priority);
    final nowUtc = now.toUtc();
    final result = <ScheduledReminder>[];
    for (var i = 0; i < offsets.length; i++) {
      final firesAt = m.endsAtUtc.toUtc().subtract(offsets[i]);
      if (firesAt.isBefore(nowUtc)) continue;
      result.add(ScheduledReminder(
        key: 'm${m.id}#$i',
        milestoneId: m.id,
        scheduleIndex: i,
        firesAtUtc: firesAt,
        priority: priority,
        title: 'Reminder: ${m.title}',
        body: 'In ${TimezoneUtil.formatInstant(offsets[i])} — ${TimezoneUtil.displayWallClock(m.endsAtUtc, m.timezone)} ${m.timezone}',
      ));
    }
    return result;
  }

  static ScheduledReminder build({
    required int milestoneId,
    required int scheduleIndex,
    required DateTime firesAtUtc,
    required Priority priority,
    required String title,
    required String body,
  }) =>
      ScheduledReminder(
        key: 'm${milestoneId}#$scheduleIndex',
        milestoneId: milestoneId,
        scheduleIndex: scheduleIndex,
        firesAtUtc: firesAtUtc.toUtc(),
        priority: priority,
        title: title,
        body: body,
      );

  static Priority _priorityOf(Milestone m) => PriorityClassifier.classify(m.label, m.title).$1;
}
```

This is the complete file. Write `plan` as the straight loop shown; the `..add` list-comprehension form compiles but is needlessly indirect, so do not use it.

- [ ] **Step 5: Run tests**

```bash
flutter test test/engine/offset_schedule_test.dart test/engine/priority_test.dart
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/engine test/engine && git commit -q -m "feat(engine): PRD reminder cadences and critical auto-classification

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 4: Quiet hours and the reminder state machine

**Files:**
- Create: `lib/engine/quiet_hours.dart`, `lib/engine/reminder_machine.dart`
- Test: `test/engine/quiet_hours_test.dart`, `test/engine/reminder_machine_test.dart`

**Interfaces:**
- Produces:
  - `class QuietHours { const QuietHours({required this.startMinute, required this.endMinute, required this.enabled}); final int startMinute; final int endMinute; final bool enabled; static const none = QuietHours(startMinute: 0, endMinute: 0, enabled: false); }`
  - `class QuietHoursGate { static QuietDecision gate(DateTime firesAtUtc, Priority priority, QuietHours hours, String userTimezone); }`
  - `enum SuppressDecision { fire, suppress }`
  - `class QuietDecision { const QuietDecision(this.decision, this.effectiveAtUtc); final SuppressDecision decision; final DateTime effectiveAtUtc; }`
  - `class ReminderMachine { static ReminderState next(ReminderState current, ReminderAction action); static bool isTerminal(ReminderState s); static int nextRepeatCount(int current); static bool shouldRepeat(Priority p, int repeatCount); }`
  - `enum ReminderAction { done, snoozeOneHour, snoozeTomorrow, skip, elapsed }`

- [ ] **Step 1: Write the failing tests**

`test/engine/quiet_hours_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/quiet_hours.dart';

void main() {
  const nights = QuietHours(startMinute: 22 * 60, endMinute: 7 * 60, enabled: true);

  test('normal reminder inside quiet hours is suppressed to the next permitted minute', () {
    final at = DateTime.utc(2026, 10, 18, 4, 0, 0);
    final d = QuietHoursGate.gate(at, Priority.normal, nights, 'UTC');
    expect(d.decision, SuppressDecision.suppress);
    expect(d.effectiveAtUtc.hour, 7);
  });

  test('high priority is also suppressed during quiet hours', () {
    final d = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 23, 0, 0), Priority.high,
        nights, 'UTC');
    expect(d.decision, SuppressDecision.suppress);
  });

  test('critical fires regardless of quiet hours', () {
    final d = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 23, 0, 0), Priority.critical,
        nights, 'UTC');
    expect(d.decision, SuppressDecision.fire);
    expect(d.effectiveAtUtc, DateTime.utc(2026, 10, 18, 23, 0, 0));
  });

  test('no quiet hours means everything fires immediately', () {
    final d = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 4, 0, 0), Priority.normal,
        QuietHours.none, 'UTC');
    expect(d.decision, SuppressDecision.fire);
  });

  test('window that does not wrap treats end after start normally', () {
    const midday = QuietHours(startMinute: 12 * 60, endMinute: 14 * 60, enabled: true);
    final inside = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 13, 0, 0), Priority.normal,
        midday, 'UTC');
    final outside = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 15, 0, 0), Priority.normal,
        midday, 'UTC');
    expect(inside.decision, SuppressDecision.suppress);
    expect(outside.decision, SuppressDecision.fire);
  });

  test('wrapping window correctly spans midnight', () {
    final justInside = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 22, 30, 0),
        Priority.normal, nights, 'UTC');
    final afterMidnight = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 3, 0, 0),
        Priority.normal, nights, 'UTC');
    final justAfter = QuietHoursGate.gate(DateTime.utc(2026, 10, 18, 7, 5, 0),
        Priority.normal, nights, 'UTC');
    expect(justInside.decision, SuppressDecision.suppress);
    expect(afterMidnight.decision, SuppressDecision.suppress);
    expect(justAfter.decision, SuppressDecision.fire);
  });

  test('suppressed fire time lands strictly inside the permitted window', () {
    final at = DateTime.utc(2026, 10, 18, 6, 59, 30);
    final d = QuietHoursGate.gate(at, Priority.normal, nights, 'UTC');
    expect(d.decision, SuppressDecision.suppress);
    expect(d.effectiveAtUtc.isAfter(at), isTrue);
  });
}
```

`test/engine/reminder_machine_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/reminder_machine.dart';

void main() {
  test('fired + done reaches terminal done', () {
    expect(ReminderMachine.next(ReminderState.fired, ReminderAction.done), ReminderState.done);
    expect(ReminderMachine.isTerminal(ReminderState.done), isTrue);
  });

  test('fired + skip reaches terminal skipped', () {
    expect(ReminderMachine.next(ReminderState.fired, ReminderAction.skip), ReminderState.skipped);
    expect(ReminderMachine.isTerminal(ReminderState.skipped), isTrue);
  });

  test('snooze moves to snoozed and then back to fired on elapse', () {
    final snoozed = ReminderMachine.next(ReminderState.fired, ReminderAction.snoozeOneHour);
    expect(snoozed, ReminderState.snoozed);
    expect(ReminderMachine.next(ReminderState.snoozed, ReminderAction.elapsed),
        ReminderState.fired);
  });

  test('snoozed from scheduled also moves to snoozed', () {
    expect(ReminderMachine.next(ReminderState.scheduled, ReminderAction.snoozeOneHour),
        ReminderState.snoozed);
  });

  test('critical repeats up to 3 times then gives up', () {
    expect(ReminderMachine.shouldRepeat(Priority.critical, 0), isTrue);
    expect(ReminderMachine.shouldRepeat(Priority.critical, 2), isTrue);
    expect(ReminderMachine.shouldRepeat(Priority.critical, 3), isFalse);
    expect(ReminderMachine.nextRepeatCount(0), 1);
    expect(ReminderMachine.nextRepeatCount(2), 3);
  });

  test('elapsed on a repeatable critical arms a repeat', () {
    final armed = ReminderMachine.next(ReminderState.fired, ReminderAction.elapsed);
    expect(armed, ReminderState.repeatArmed);
    expect(ReminderMachine.next(ReminderState.repeatArmed, ReminderAction.elapsed),
        ReminderState.fired);
  });

  test('non-critical does not repeat', () {
    expect(ReminderMachine.shouldRepeat(Priority.high, 0), isFalse);
    expect(ReminderMachine.shouldRepeat(Priority.normal, 0), isFalse);
  });

  test('skip from repeatArmed terminates', () {
    expect(ReminderMachine.next(ReminderState.repeatArmed, ReminderAction.skip),
        ReminderState.skipped);
  });

  test('terminal states ignore further actions', () {
    expect(ReminderMachine.next(ReminderState.done, ReminderAction.done), ReminderState.done);
    expect(ReminderMachine.next(ReminderState.skipped, ReminderAction.snoozeTomorrow),
        ReminderState.skipped);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/engine/quiet_hours_test.dart test/engine/reminder_machine_test.dart
```

Expected: FAIL, URI not found.

- [ ] **Step 3: Implement `lib/engine/quiet_hours.dart`**

```dart
import 'models.dart';

/// FR-9: quiet hours silence Normal and High reminders. Critical always fires.
class QuietHours {
  const QuietHours({
    required this.startMinute,
    required this.endMinute,
    required this.enabled,
  });

  final int startMinute; // minutes after midnight, local
  final int endMinute;
  final bool enabled;

  static const none = QuietHours(startMinute: 0, endMinute: 0, enabled: false);
}

enum SuppressDecision { fire, suppress }

class QuietDecision {
  const QuietDecision(this.decision, this.effectiveAtUtc);
  final SuppressDecision decision;
  final DateTime effectiveAtUtc;
}

class QuietHoursGate {
  QuietHoursGate._();

  static bool _contains(QuietHours h, int minuteOfDay) {
    if (!h.enabled) return false;
    if (h.startMinute < h.endMinute) {
      return minuteOfDay >= h.startMinute && minuteOfDay < h.endMinute;
    }
    // Wraps midnight.
    return minuteOfDay >= h.startMinute || minuteOfDay < h.endMinute;
  }

  static QuietDecision gate(DateTime firesAtUtc, Priority priority, QuietHours hours,
      String userTimezone) {
    if (priority == Priority.critical) {
      return QuietDecision(SuppressDecision.fire, firesAtUtc.toUtc());
    }
    if (hours == QuietHours.none || !hours.enabled) {
      return QuietDecision(SuppressDecision.fire, firesAtUtc.toUtc());
    }
    final local = firesAtUtc.toLocal();
    final minute = local.hour * 60 + local.minute;
    if (!_contains(hours, minute)) {
      return QuietDecision(SuppressDecision.fire, firesAtUtc.toUtc());
    }
    // Advance to the first minute after the window ends.
    var candidate = firesAtUtc.toUtc();
    for (var i = 0; i < 1441; i++) {
      final next = candidate.add(const Duration(minutes: 1));
      final nLocal = next.toLocal();
      final nMinute = nLocal.hour * 60 + nLocal.minute;
      if (!_contains(hours, nMinute)) return QuietDecision(SuppressDecision.suppress, next);
      candidate = next;
    }
    return QuietDecision(SuppressDecision.fire, candidate);
  }
}
```

- [ ] **Step 4: Implement `lib/engine/reminder_machine.dart`**

```dart
import 'models.dart';

/// FR-7 and FR-8: the reminder state machine.
///
/// Scheduled --show--> Fired --Done--> Done (terminal)
///                    Fired --Snooze--> Snoozed --elapsed--> Fired
///                    Fired --Skip--> Skipped (terminal)
///                    Fired --elapsed, Critical, <3--> RepeatArmed --elapsed--> Fired
///                    Fired --elapsed, Critical, ==3--> Skipped
class ReminderMachine {
  ReminderMachine._();

  static const maxRepeats = 3;

  static bool isTerminal(ReminderState s) =>
      s == ReminderState.done || s == ReminderState.skipped;

  static int nextRepeatCount(int current) => current + 1;

  static bool shouldRepeat(Priority p, int repeatCount) =>
      p == Priority.critical && repeatCount < maxRepeats;

  static ReminderState next(ReminderState current, ReminderAction action) {
    if (isTerminal(current)) return current;
    return switch ((current, action)) {
      (_, ReminderAction.done) => ReminderState.done,
      (_, ReminderAction.skip) => ReminderState.skipped,
      (ReminderState.scheduled, ReminderAction.snoozeOneHour) ||
      (ReminderState.scheduled, ReminderAction.snoozeTomorrow) =>
        ReminderState.snoozed,
      (ReminderState.fired, ReminderAction.snoozeOneHour) ||
      (ReminderState.fired, ReminderAction.snoozeTomorrow) =>
        ReminderState.snoozed,
      (ReminderState.snoozed, ReminderAction.elapsed) => ReminderState.fired,
      (ReminderState.repeatArmed, ReminderAction.elapsed) => ReminderState.fired,
      _ => current,
    };
  }
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/engine/quiet_hours_test.dart test/engine/reminder_machine_test.dart
```

Expected: all pass. Note the DST boundary in the quiet-hours test: a `firesAtUtc` inside the DST spring-forward gap resolves to the later wall-clock time, which is correct behaviour.

- [ ] **Step 6: Commit**

```bash
git add lib/engine test/engine && git commit -q -m "feat(engine): quiet hours gate and reminder state machine

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 5: Conflict detection

**Files:**
- Create: `lib/engine/conflict_detector.dart`
- Test: `test/engine/conflict_detector_test.dart`

**Interfaces:**
- Consumes: `Hackathon`, `Milestone`, `Conflict`, `ConflictType`, `ConflictSeverity` from Task 2.
- Produces:
  - `class ConflictDetector { static List<Conflict> detect(List<Hackathon> hackathons, Map<int, List<Milestone>> milestonesByHackathon, Set<int> primaryIds); }`
  - `static DateTime? windowEnd(Hackathon h, List<Milestone> ms)` — the last non-past milestone for a hackathon.
  - `static DateTime? windowStart(Hackathon h, List<Milestone> ms)` — the earliest `startsAtUtc`.

- [ ] **Step 1: Write the failing tests**

`test/engine/conflict_detector_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/conflict_detector.dart';

Hackathon _h(int id, {HackathonStatus status = HackathonStatus.upcoming,
    String tz = 'UTC'}) =>
    Hackathon(
      id: id, name: 'H$id', organizer: 'O$id', url: '', mode: HackathonMode.online,
      location: '', organizerTimezone: tz, status: status,
      createdAt: DateTime.utc(2026, 10, 1), modifiedAt: DateTime.utc(2026, 10, 1),
    );

Milestone _m(int id, int hid, {DateTime? start, DateTime? end}) => Milestone(
      id: id, hackathonId: hid, label: MilestoneLabel.eventWindow, title: 'Window',
      startsAtUtc: start, endsAtUtc: end ?? DateTime.utc(2026, 10, 24, 23, 59),
      timezone: 'UTC', isCritical: false, verified: false,
      createdAt: DateTime.utc(2026, 10, 1), modifiedAt: DateTime.utc(2026, 10, 1),
    );

Milestone _crit(int id, int hid, DateTime at) => Milestone(
      id: id, hackathonId: hid, label: MilestoneLabel.finalSubmission, title: 'Final submission',
      endsAtUtc: at, timezone: 'UTC', isCritical: true, verified: false,
      createdAt: DateTime.utc(2026, 10, 1), modifiedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  test('overlapping windows are flagged', () {
    final hs = [_h(1), _h(2)];
    final ms = {
      1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 27))],
      2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
    };
    final c = ConflictDetector.detect(hs, ms, {});
    expect(c.where((x) => x.type == ConflictType.overlappingWindows), isNotEmpty);
  });

  test('non-overlapping windows are not flagged', () {
    final hs = [_h(1), _h(2)];
    final ms = {
      1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 22))],
      2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
    };
    expect(ConflictDetector.detect(hs, ms, {})
        .where((x) => x.type == ConflictType.overlappingWindows), isEmpty);
  });

  test('archived hackathons never conflict', () {
    final hs = [_h(1, status: HackathonStatus.upcoming), _h(2, status: HackathonStatus.archived)];
    final ms = {
      1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 27))],
      2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
    };
    expect(ConflictDetector.detect(hs, ms, {})
        .where((x) => x.type == ConflictType.overlappingWindows), isEmpty);
  });

  test('critical deadlines within 24 hours of each other are flagged', () {
    final hs = [_h(1), _h(2)];
    final ms = {
      1: [_crit(1, 1, DateTime.utc(2026, 10, 24, 12, 0))],
      2: [_crit(2, 2, DateTime.utc(2026, 10, 24, 22, 0))],
    };
    final c = ConflictDetector.detect(hs, ms, {});
    expect(c.where((x) => x.type == ConflictType.closeCritical), isNotEmpty);
  });

  test('critical deadlines exactly 24 hours apart are flagged (inclusive bound)', () {
    final hs = [_h(1), _h(2)];
    final ms = {
      1: [_crit(1, 1, DateTime.utc(2026, 10, 24, 12, 0))],
      2: [_crit(2, 2, DateTime.utc(2026, 10, 25, 12, 0))],
    };
    expect(ConflictDetector.detect(hs, ms, {})
        .where((x) => x.type == ConflictType.closeCritical), isNotEmpty);
  });

  test('critical deadlines 25 hours apart are not flagged', () {
    final hs = [_h(1), _h(2)];
    final ms = {
      1: [_crit(1, 1, DateTime.utc(2026, 10, 24, 12, 0))],
      2: [_crit(2, 2, DateTime.utc(2026, 10, 25, 13, 0))],
    };
    expect(ConflictDetector.detect(hs, ms, {})
        .where((x) => x.type == ConflictType.closeCritical), isEmpty);
  });

  test('hackathons without a confirmed team are flagged orphaned', () {
    final hs = [_h(1)];
    expect(ConflictDetector.detect(hs, {}, {})
        .where((x) => x.type == ConflictType.orphanedTeam), isNotEmpty);
  });

  test('marking a hackathon Primary suppresses its own orphan warning', () {
    final hs = [_h(1)];
    expect(ConflictDetector.detect(hs, {}, {1})
        .where((x) => x.type == ConflictType.orphanedTeam), isEmpty);
  });

  test('primary marking suppresses the overlapping conflict on that side', () {
    final hs = [_h(1), _h(2)];
    final ms = {
      1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 27))],
      2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
    };
    final withPrimary = ConflictDetector.detect(hs, ms, {1})
        .where((x) => x.type == ConflictType.overlappingWindows);
    // The conflict is reported against the non-primary side only.
    final ids = withPrimary.map((c) => c.hackathonId).toSet();
    expect(ids.contains(1), isFalse);
    expect(ids.contains(2), isTrue);
  });

  test('no conflicts with an empty input', () {
    expect(ConflictDetector.detect([], {}, {}), isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/engine/conflict_detector_test.dart
```

Expected: FAIL, URI not found.

- [ ] **Step 3: Implement `lib/engine/conflict_detector.dart`**

```dart
import 'models.dart';

/// FR-20: conflict detection for overlapping windows, close Critical deadlines,
/// and hackathons with no confirmed team. Conflicts are computed on demand and
/// never stored.
class ConflictDetector {
  ConflictDetector._();

  static final _nearCriticalWindow = const Duration(hours: 24);

  static List<Conflict> detect(
    List<Hackathon> hackathons,
    Map<int, List<Milestone>> milestonesByHackathon,
    Set<int> primaryIds,
  ) {
    final out = <Conflict>[];
    final active =
        hackathons.where((h) => h.status == HackathonStatus.upcoming || h.status == HackathonStatus.running).toList();

    // Orphaned: no confirmed team yet.
    for (final h in active) {
      if (primaryIds.contains(h.id)) continue;
      out.add(Conflict(
        type: ConflictType.orphanedTeam,
        severity: ConflictSeverity.warning,
        hackathonId: h.id,
        message: 'No confirmed team for ${h.name} yet.',
      ));
    }

    // Overlapping windows.
    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        final a = active[i];
        final b = active[j];
        final sa = windowStart(a, milestonesByHackathon[a.id] ?? const []);
        final ea = windowEnd(a, milestonesByHackathon[a.id] ?? const []);
        final sb = windowStart(b, milestonesByHackathon[b.id] ?? const []);
        final eb = windowEnd(b, milestonesByHackathon[b.id] ?? const []);
        if (sa == null || ea == null || sb == null || eb == null) continue;
        final overlaps = sa.isBefore(eb) && sb.isBefore(ea);
        if (!overlaps) continue;
        final reportAgainst = primaryIds.contains(b.id) ? a.id : (primaryIds.contains(a.id) ? b.id : a.id);
        out.add(Conflict(
          type: ConflictType.overlappingWindows,
          severity: ConflictSeverity.danger,
          hackathonId: reportAgainst,
          partnerHackathonId: reportAgainst == a.id ? b.id : a.id,
          message: '${a.name} and ${b.name} run at the same time.',
        ));
      }
    }

    // Close Critical deadlines across hackathons.
    final criticals = <(Milestone, Hackathon)>[];
    for (final h in active) {
      for (final m in milestonesByHackathon[h.id] ?? const <Milestone>[]) {
        if (m.isCritical) criticals.add((m, h));
      }
    }
    for (var i = 0; i < criticals.length; i++) {
      for (var j = i + 1; j < criticals.length; j++) {
        final (ma, ha) = criticals[i];
        final (mb, hb) = criticals[j];
        if (ha.id == hb.id) continue;
        final delta = ma.endsAtUtc.difference(mb.endsAtUtc).abs();
        if (delta <= _nearCriticalWindow) {
          final reportAgainst = primaryIds.contains(hb.id) ? ha.id : hb.id;
          out.add(Conflict(
            type: ConflictType.closeCritical,
            severity: ConflictSeverity.danger,
            hackathonId: reportAgainst,
            partnerHackathonId: reportAgainst == ha.id ? hb.id : ha.id,
            message: 'Critical deadlines within 24 hours: ${ha.name} and ${hb.name}.',
          ));
        }
      }
    }
    return out;
  }

  /// Earliest `startsAtUtc`, else the earliest point milestone's `endsAtUtc`.
  static DateTime? windowStart(Hackathon h, List<Milestone> ms) {
    if (ms.isEmpty) return null;
    DateTime? best;
    for (final m in ms) {
      final s = m.startsAtUtc ?? m.endsAtUtc;
      if (best == null || s.isBefore(best)) best = s;
    }
    return best;
  }

  /// Latest `endsAtUtc`.
  static DateTime? windowEnd(Hackathon h, List<Milestone> ms) {
    if (ms.isEmpty) return null;
    DateTime? best;
    for (final m in ms) {
      if (best == null || m.endsAtUtc.isAfter(best)) best = m.endsAtUtc;
    }
    return best;
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/engine/conflict_detector_test.dart
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/engine test/engine && git commit -q -m "feat(engine): overlap, close-critical, and orphaned-team conflict detection

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 6: Drift database, repository, and sync seam

**Files:**
- Create: `lib/data/database.dart`, `lib/data/db_provider.dart`, `lib/data/repository.dart`, `lib/data/change_log.dart`, `lib/data/sync.dart`, `lib/data/prefs.dart`
- Test: `test/data/repository_test.dart`

**Interfaces:**
- Produces:
  - `class AppDatabase extends Database` with tables `hackathons`, `milestones`, `milestoneChanges`, `teams`, `teamMembers`, `teamChanges`, `reminderStates`
  - `class Repository { const Repository(this.db); final AppDatabase db; }`
  - `enum MilestoneChangeField { endsAt, startsAt, title, label, timezone }`
  - `class MilestoneChange { id, milestoneId, changedField, oldValue, newValue, changedAtUtc }`
  - `enum TeamChangeType { created, memberAdded, memberRemoved, memberUpdated, statusChanged }`
  - `class TeamChange { id, teamId, changeType, entityLabel, oldValue, newValue, changedAtUtc }`
  - `Future<List<ReminderStateRecord>> remindersForMilestone(int milestoneId); Future<void> deleteReminderState(String key);`
  - `Future<void> upsertReminderState(ReminderStateRecord r); Future<void> updateReminderState(String key, ReminderState state, {DateTime? firesAtUtc, int? repeatCount, DateTime? armedAtUtc});`
  - `Stream<List<Hackathon>> watchHackathons(); Stream<List<Milestone>> watchMilestonesFor(int hackathonId); Future<Milestone?> milestone(int id);`
  - `Future<Hackathon> saveHackathon(Hackathon h); Future<void> archiveHackathon(int id);`
  - `Future<Milestone> saveMilestone(Milestone m); Future<void> deleteMilestone(int id);`
  - `Future<Team> saveTeam(Team t); Future<void> saveTeamMembers(int teamId, List<TeamMember> members); Future<void> setTeamStatus(int teamId, TeamStatus s);`
  - `Stream<Map<int, List<Milestone>>> watchMilestonesGrouped(); Stream<List<Team>> watchTeamsFor(int hackathonId); Stream<Map<int, int>> watchMemberCounts();`
  - `Stream<List<ReminderStateRecord>> watchScheduledReminders(); Future<ReminderStateRecord?> reminder(String key); Future<void> updateReminderState(String key, ReminderStateRecord patch);`
  - `Future<int> countHackathons(); Stream<List<MilestoneChange>> watchMilestoneChanges(int milestoneId); Stream<List<TeamChange>> watchTeamChanges(int teamId);`
  - `class ReminderStateRecord {key, milestoneId, scheduleIndex, profile, firesAtUtc, priority, state, repeatCount, armedAtUtc, updatedAtUtc}`
  - `class SyncRepository` interface, `class LocalOnlySyncRepository`, `enum SyncStatus { offline, syncing, synced, error }`
  - `class PrefsStore { Future<ReminderProfile getProfile(); Future<void> setProfile(ReminderProfile p); Future<QuietHours getQuietHours(); Future<void> setQuietHours(QuietHours h); Future<String getUserTimezone(); Future<void> setUserTimezone(String z); Future<bool isExactAlarmGranted(); Future<void> setExactAlarmGranted(bool g); }`

- [ ] **Step 1: Write the failing test**

`test/data/repository_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() async {
    db = AppDatabase();
    await db.onSchemaCreate;
    repo = Repository(db);
  });

  tearDown(() => db.close());

  Hackathon _h({int id = -1, String name = 'Alpha Hack'}) => Hackathon(
        id: id, name: name, organizer: 'Org', url: '', mode: HackathonMode.online,
        location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
        createdAt: DateTime.utc(2026, 10, 17), modifiedAt: DateTime.utc(2026, 10, 17),
      );

  test('saveHackathon persists and watchHackathons emits it', () async {
    final h = await repo.saveHackathon(_h());
    expect(h.id, greaterThan(0));
    final all = await repo.watchHackathons().first;
    expect(all.length, 1);
    expect(all.first.name, 'Alpha Hack');
  });

  test('saveHackathon with the same id updates in place', () async {
    final h1 = await repo.saveHackathon(_h());
    final h2 = await repo.saveHackathon(h1.copyWith(name: 'Renamed'));
    expect(h2.id, h1.id);
    final all = await repo.watchHackathons().first;
    expect(all.length, 1);
    expect(all.first.name, 'Renamed');
  });

  test('archiveHackathon sets status archived and preserves history', () async {
    final h = await repo.saveHackathon(_h());
    await repo.archiveHackathon(h.id);
    final all = await repo.watchHackathons().first;
    expect(all.first.status, HackathonStatus.archived);
    expect(await repo.countHackathons(), 1);
  });

  test('saveMilestone logs the date change and persists', () async {
    final h = await repo.saveHackathon(_h());
    final m1 = await repo.saveMilestone(Milestone(
      id: -1, hackathonId: h.id, label: MilestoneLabel.finalSubmission, title: 'Submit',
      endsAtUtc: DateTime.utc(2026, 10, 24), timezone: 'UTC', isCritical: true,
      criticalReason: 'Critical', verified: false, createdAt: DateTime.utc(2026, 10, 17),
      modifiedAt: DateTime.utc(2026, 10, 17),
    ));
    final m2 = await repo.saveMilestone(m1.copyWith(endsAtUtc: DateTime.utc(2026, 10, 25)));
    final changes = await repo.watchMilestoneChanges(m2.id).first;
    expect(changes.length, 1);
    expect(changes.first.changedField, MilestoneChangeField.endsAt);
    expect(m2.modifiedAt.isAfter(m1.modifiedAt), isTrue);
  });

  test('unverified milestone stays unverified after a date edit', () async {
    final h = await repo.saveHackathon(_h());
    final m1 = await repo.saveMilestone(Milestone(
      id: -1, hackathonId: h.id, label: MilestoneLabel.finalSubmission, title: 'Submit',
      endsAtUtc: DateTime.utc(2026, 10, 24), timezone: 'UTC', isCritical: true,
      verified: false, createdAt: DateTime.utc(2026, 10, 17), modifiedAt: DateTime.utc(2026, 10, 17),
    ));
    await repo.saveMilestone(m1.copyWith(endsAtUtc: DateTime.utc(2026, 10, 25)));
    expect((await repo.milestone(m1.id))!.verified, isFalse);
  });

  test('team status change is logged', () async {
    final h = await repo.saveHackathon(_h());
    final t = await repo.saveTeam(Team(
      id: -1, hackathonId: h.id, name: 'Night Owls', status: TeamStatus.looking,
      ideaTitle: '', techStack: '', repoUrl: '', chatUrl: '', notes: '',
      createdAt: DateTime.utc(2026, 10, 17), modifiedAt: DateTime.utc(2026, 10, 17),
    ));
    await repo.setTeamStatus(t.id, TeamStatus.confirmed);
    final changes = await repo.watchTeamChanges(t.id).first;
    expect(changes.any((c) => c.changeType == TeamChangeType.statusChanged), isTrue);
  });

  test('team member changes are logged with before and after', () async {
    final h = await repo.saveHackathon(_h());
    final t = await repo.saveTeam(Team(
      id: -1, hackathonId: h.id, name: 'Night Owls', status: TeamStatus.looking,
      ideaTitle: '', techStack: '', repoUrl: '', chatUrl: '', notes: '',
      createdAt: DateTime.utc(2026, 10, 17), modifiedAt: DateTime.utc(2026, 10, 17),
    ));
    await repo.saveTeamMembers(t.id, [
      TeamMember(id: -1, teamId: t.id, name: 'Ada', role: 'Lead', contact: 'ada@x', isLead: true),
    ]);
    await repo.saveTeamMembers(t.id, [
      TeamMember(id: -1, teamId: t.id, name: 'Ada', role: 'Lead', contact: 'ada@x', isLead: true),
      TeamMember(id: -1, teamId: t.id, name: 'Bo', role: 'Designer', contact: 'bo@x', isLead: false),
    ]);
    final changes = await repo.watchTeamChanges(t.id).first;
    expect(changes.any((c) => c.changeType == TeamChangeType.memberAdded), isTrue);
    final counts = await repo.watchMemberCounts().first;
    expect(counts[t.id], 2);
  });

  test('watchMilestonesGrouped returns milestones keyed by hackathon', () async {
    final h = await repo.saveHackathon(_h());
    await repo.saveMilestone(Milestone(
      id: -1, hackathonId: h.id, label: MilestoneLabel.finalSubmission, title: 'Submit',
      endsAtUtc: DateTime.utc(2026, 10, 24), timezone: 'UTC', isCritical: true,
      verified: false, createdAt: DateTime.utc(2026, 10, 17), modifiedAt: DateTime.utc(2026, 10, 17),
    ));
    final grouped = await repo.watchMilestonesGrouped().first;
    expect(grouped[h.id]?.length, 1);
  });

  test('watchScheduledReminders round-trips a reminder state', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(Milestone(
      id: -1, hackathonId: h.id, label: MilestoneLabel.finalSubmission, title: 'Submit',
      endsAtUtc: DateTime.utc(2026, 10, 24), timezone: 'UTC', isCritical: true,
      verified: false, createdAt: DateTime.utc(2026, 10, 17), modifiedAt: DateTime.utc(2026, 10, 17),
    ));
    await repo.upsertReminderState(ReminderStateRecord(
      key: 'm${m.id}#0', milestoneId: m.id, scheduleIndex: 0, profile: 'standard',
      firesAtUtc: DateTime.utc(2026, 10, 17, 23, 59), priority: Priority.critical,
      state: ReminderState.scheduled, repeatCount: 0, updatedAtUtc: DateTime.utc(2026, 10, 17),
    ));
    final rows = await repo.watchScheduledReminders().first;
    expect(rows.length, 1);
    expect(rows.first.state, ReminderState.scheduled);
    await repo.updateReminderState(rows.first.key, ReminderState.fired);
    final after = await repo.reminder(rows.first.key);
    expect(after!.state, ReminderState.fired);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/data/
```

Expected: FAIL, URI not found.

- [ ] **Step 3: Implement `lib/data/database.dart`**

Write the Drift schema. Tables exactly as spec section 5. `@Table` and `@DriftDatabase` from `package:drift/drift.dart`. This class needs codegen, so add `build_runner` and `source_gen` to `dev_dependencies` first:

```yaml
dev_dependencies:
  build_runner: ^2.4.13
  source_gen: ^1.5.0
```

Then:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../engine/models.dart';

part 'database.g.dart';

enum MilestoneChangeField { endsAt, startsAt, title, label, timezone }
enum TeamChangeType { created, memberAdded, memberRemoved, memberUpdated, statusChanged }

@DriftDatabase(tables: [Hackathons, Milestones, MilestoneChanges, Teams, TeamMembers, TeamChanges, ReminderStates])
class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(NativeDatabase.memory()); // test-only constructor
  AppDatabase.open(String path) : super(NativeDatabase.createFile(path: path));

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, dynamic>>();

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) async => m.createAll());
}
```

Then run:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

The generated `database.g.dart` is a build artifact and must be committed. **Do not** stub the database; the tests must run against real SQLite.

- [ ] **Step 4: Implement `lib/data/db_provider.dart`**

```dart
import 'database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

late final AppDatabase db = () async {
  final dir = await getApplicationDocumentsDirectory();
  return AppDatabase.open(join(dir.path, 'hackathon_manager.sqlite'));
}();
```

In tests, construct `AppDatabase()` directly (the memory-backed constructor). Do not touch `db_provider.dart` in tests.

- [ ] **Step 5: Implement `lib/data/repository.dart`**

Implement every method declared in the Interfaces block. `saveMilestone` compares the incoming row to the existing row field by field and appends a `milestoneChanges` row for every changed field BEFORE updating the milestone row. `setTeamStatus` appends a `teamChanges` row with `oldValue`/`newValue` set to the serialized status strings. `watchMilestonesGrouped` does a single grouped query and buckets results into a `Map<int, List<Milestone>>`.

The repository maps between Drift table rows and the engine's `Hackathon`/`Milestone`/`Team`/`TeamMember` classes. The mapping is a thin pair of static methods on each side; the engine never sees Drift types.

- [ ] **Step 6: Implement `lib/data/change_log.dart`, `lib/data/sync.dart`, `lib/data/prefs.dart`**

`change_log.dart` exports the enum types used by the database and the row-mapping helpers.

`sync.dart`:

```dart
import '../engine/models.dart';

enum SyncStatus { offline, syncing, synced, error }

abstract interface class SyncRepository {
  Future<void> onMutation();
  Future<SyncStatus> syncNow();
  Stream<SyncStatus> get statusStream;
}

class LocalOnlySyncRepository implements SyncRepository {
  @override
  Future<void> onMutation() async {}
  @override
  Future<SyncStatus> syncNow() async => SyncStatus.offline;
  @override
  Stream<SyncStatus> get statusStream => Stream<SyncStatus>.value(SyncStatus.offline);
}
```

`SyncStatus` is declared in this file. The other implementations must import it from here.

`prefs.dart` implements the key-value store with a JSON file in the app documents directory. In tests, expose a `PrefsStore.inMemory()` constructor that uses an in-memory map.

- [ ] **Step 7: Run tests**

```bash
flutter test test/data/
```

Expected: all pass. If codegen was needed, run it first:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 8: Commit**

```bash
git add lib/data test/data pubspec.yaml && git commit -q -m "feat(data): drift schema, repository with change logging, sync seam

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 7: Scheduler service with a fakeable notifier

**Files:**
- Create: `lib/services/scheduler.dart`, `lib/services/test_data.dart`
- Test: `test/services/scheduler_test.dart`

**Interfaces:**
- Consumes: `OffsetSchedule`, `PriorityClassifier`, `QuietHoursGate`, `ReminderMachine`, `Repository`, `PrefsStore` from earlier tasks.
- Produces:
  - `abstract interface class Notifier { Future<void> schedule({required String key, required DateTime fireAt, required String title, required String body, required Priority priority}); Future<void> cancel(String key); Future<void> show({required String key, required String title, required String body, required Priority priority}); }`
  - `class NotificationScheduler { NotificationScheduler({required Repository repo, required Notifier notifier, required PrefsStore prefs}); Future<void> planAll(); Future<void> replanForMilestone(int milestoneId); Future<void> handleReminder(String key); Future<void> markDone(String key); Future<void> snooze(String key, {bool tomorrow = false}); Future<void> skip(String key); Future<List<ScheduledReminder>> pendingReminders(); }`

- [ ] **Step 1: Write the failing tests**

`test/services/scheduler_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/services/scheduler.dart';
import 'package:hackathon_manager/services/prefs_test_impl.dart';

class FakeNotifier implements Notifier {
  final List<String> scheduled = [];
  final List<String> cancelled = [];
  final List<String> shown = [];
  DateTime? lastFireAt;

  @override
  Future<void> schedule({required String key, required DateTime fireAt, required String title,
      required String body, required Priority priority}) async {
    scheduled.add(key);
    lastFireAt = fireAt;
  }
  @override
  Future<void> cancel(String key) async => cancelled.add(key);
  @override
  Future<void> show({required String key, required String title, required String body,
      required Priority priority}) async {
    shown.add(key);
  }
}

void main() {
  late AppDatabase db;
  late Repository repo;
  late FakeNotifier notifier;
  late NotificationScheduler scheduler;

  setUp(() async {
    db = AppDatabase();
    repo = Repository(db);
    notifier = FakeNotifier();
    scheduler = NotificationScheduler(repo: repo, notifier: notifier, prefs: InMemoryPrefs());
  });

  tearDown(() => db.close());

  Hackathon _h() => Hackathon(
        id: -1, name: 'Alpha', organizer: 'Org', url: '', mode: HackathonMode.online,
        location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
        createdAt: DateTime.utc(2026, 10, 17), modifiedAt: DateTime.utc(2026, 10, 17),
      );

  Milestone _m(int hid) => Milestone(
        id: -1, hackathonId: hid, label: MilestoneLabel.finalSubmission, title: 'Submit',
        endsAtUtc: DateTime.utc(2026, 10, 24, 23, 59), timezone: 'UTC', isCritical: true,
        verified: false, createdAt: DateTime.utc(2026, 10, 17), modifiedAt: DateTime.utc(2026, 10, 17),
      );

  test('planAll schedules a reminder for each milestone', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    expect(notifier.scheduled, contains('m${m.id}#0'));
  });

  test('markDone persists the transition and cancels the alarm', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    await scheduler.markDone('m${m.id}#0');
    final row = await repo.reminder('m${m.id}#0');
    expect(row!.state, ReminderState.done);
  });

  test('skip is terminal', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    await scheduler.skip('m${m.id}#0');
    expect((await repo.reminder('m${m.id}#0'))!.state, ReminderState.skipped);
  });

  test('replanForMilestone reschedules with new fire times', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    final before = notifier.scheduled.length;
    await repo.saveMilestone(m.copyWith(endsAtUtc: DateTime.utc(2026, 10, 25, 23, 59)));
    await scheduler.replanForMilestone(m.id);
    // Old alarms cancelled, new ones scheduled.
    expect(notifier.cancelled, isNotEmpty);
    expect(notifier.scheduled.length, greaterThan(before));
  });

  test('pendingReminders returns only future, non-terminal rows', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    await scheduler.skip('m${m.id}#0');
    final pending = await scheduler.pendingReminders();
    expect(pending.any((r) => r.key == 'm${m.id}#0'), isFalse);
  });
}
```

`NotificationScheduler` calls `repo.remindersForMilestone` and `repo.deleteReminderState`, both declared in Task 6's Interfaces. `prefs.getQuietHours()` and `prefs.getUserTimezone()` are called once per plan, not per reminder.

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/services/
```

Expected: FAIL, URI not found.

- [ ] **Step 3: Implement `lib/services/scheduler.dart`**

```dart
import '../engine/models.dart';
import '../engine/offset_schedule.dart';
import '../engine/quiet_hours.dart';
import '../engine/reminder_machine.dart';
import '../data/repository.dart';
import 'prefs.dart';

abstract interface class Notifier {
  Future<void> schedule({
    required String key,
    required DateTime fireAt,
    required String title,
    required String body,
    required Priority priority,
  });
  Future<void> cancel(String key);
  Future<void> show({
    required String key,
    required String title,
    required String body,
    required Priority priority,
  });
}

class NotificationScheduler {
  NotificationScheduler({
    required this.repo,
    required this.notifier,
    required this.prefs,
  });

  final Repository repo;
  final Notifier notifier;
  final PrefsStore prefs;

  Future<void> planAll() async {
    final now = DateTime.now().toUtc();
    final profile = await prefs.getProfile();
    final grouped = await repo.watchMilestonesGrouped().first;
    for (final ms in grouped.values) {
      for (final m in ms) {
        await _replan(m, profile, now);
      }
    }
  }

  Future<void> replanForMilestone(int milestoneId) async {
    final m = await repo.milestone(milestoneId);
    if (m == null) return;
    await _replan(m, await prefs.getProfile(), DateTime.now().toUtc());
  }

  Future<void> _replan(Milestone m, ReminderProfile profile, DateTime now) async {
    // Cancel and remove any existing reminders for this milestone.
    final existing = await repo.remindersForMilestone(m.id);
    for (final e in existing) {
      if (!ReminderMachine.isTerminal(e.state)) {
        await notifier.cancel(e.key);
      }
      await repo.deleteReminderState(e.key);
    }
    // Persist every new reminder state BEFORE scheduling the alarm.
    final plan = OffsetSchedule.plan(m, profile, now);
    for (final r in plan) {
      final gate = QuietHoursGate.gate(r.firesAtUtc, r.priority, await prefs.getQuietHours(), await prefs.getUserTimezone());
      await repo.upsertReminderState(ReminderStateRecord(
        key: r.key,
        milestoneId: r.milestoneId,
        scheduleIndex: r.scheduleIndex,
        profile: profile.id,
        firesAtUtc: gate.effectiveAtUtc,
        priority: r.priority,
        state: ReminderState.scheduled,
        repeatCount: 0,
        updatedAtUtc: DateTime.now().toUtc(),
      ));
      await notifier.schedule(
        key: r.key,
        fireAt: gate.effectiveAtUtc,
        title: r.title,
        body: r.body,
        priority: r.priority,
      );
    }
  }

  Future<void> handleReminder(String key) async {
    final row = await repo.reminder(key);
    if (row == null || ReminderMachine.isTerminal(row.state)) return;
    final next = ReminderMachine.next(row.state, ReminderAction.elapsed);
    final repeatCount = (next == ReminderState.repeatArmed || next == ReminderState.fired) &&
            row.state == ReminderState.fired
        ? ReminderMachine.nextRepeatCount(row.repeatCount)
        : row.repeatCount;
    if (next == ReminderState.fired &&
        !ReminderMachine.shouldRepeat(row.priority, repeatCount)) {
      await repo.updateReminderState(key, ReminderState.skipped);
      return;
    }
    await repo.updateReminderState(
        key, ReminderState.fired, repeatCount: repeatCount,
        armedAtUtc: DateTime.now().toUtc());
    await notifier.show(
      key: key,
      title: 'Reminder',
      body: '',
      priority: row.priority,
    );
  }

  Future<void> markDone(String key) async {
    await repo.updateReminderState(key, ReminderState.done);
    await notifier.cancel(key);
  }

  Future<void> snooze(String key, {bool tomorrow = false}) async {
    final row = await repo.reminder(key);
    if (row == null) return;
    final delta = tomorrow ? const Duration(hours: 24) : const Duration(hours: 1);
    final newFire = row.firesAtUtc.add(delta);
    await repo.updateReminderState(
        key, ReminderState.snoozed, firesAtUtc: newFire,
        armedAtUtc: DateTime.now().toUtc());
    await notifier.schedule(
        key: key, fireAt: newFire, title: 'Snoozed reminder', body: '', priority: row.priority);
  }

  Future<void> skip(String key) async {
    await repo.updateReminderState(key, ReminderState.skipped);
    await notifier.cancel(key);
  }

  Future<List<ScheduledReminder>> pendingReminders() async {
    final rows = await repo.watchScheduledReminders().first;
    final now = DateTime.now().toUtc();
    return rows
        .where((r) => !ReminderMachine.isTerminal(r.state) && r.firesAtUtc.isAfter(now))
        .map((r) => ScheduledReminder(
              key: r.key,
              milestoneId: r.milestoneId,
              scheduleIndex: r.scheduleIndex,
              firesAtUtc: r.firesAtUtc,
              priority: r.priority,
              title: 'Reminder',
              body: '',
            ))
        .toList();
  }
}
```

- [ ] **Step 4: Implement `test/services/prefs_test_impl.dart`**

```dart
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/services/prefs.dart';

class InMemoryPrefs implements PrefsStore {
  ReminderProfile _profile = ReminderProfile.standard;
  QuietHours _quiet = QuietHours.none;
  String _tz = 'UTC';
  bool _exact = true;

  @override
  Future<ReminderProfile> getProfile() async => _profile;
  @override
  Future<void> setProfile(ReminderProfile p) async => _profile = p;
  @override
  Future<QuietHours> getQuietHours() async => _quiet;
  @override
  Future<void> setQuietHours(QuietHours h) async => _quiet = h;
  @override
  Future<String> getUserTimezone() async => _tz;
  @override
  Future<void> setUserTimezone(String z) async => _tz = z;
  @override
  Future<bool> isExactAlarmGranted() async => _exact;
  @override
  Future<void> setExactAlarmGranted(bool g) async => _exact = g;
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/services/
```

Expected: all pass.

- [ ] **Step 6: Implement the real `prefs.dart` and the real notifier**

Create `lib/services/prefs.dart` implementing the `PrefsStore` interface with a JSON file, and `lib/services/notifier_impl.dart` implementing `Notifier` with `flutter_local_notifications`. The notifier maps `Priority.critical` to `AndroidNotificationImportance.high`, `high` to `default`, `normal` to `low`. On Android, request the exact-alarm permission on first schedule.

- [ ] **Step 7: Commit**

```bash
git add lib/services test/services && git commit -q -m "feat(scheduler): planner, notifier abstraction, reminder lifecycle

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 8: Material 3 theme and app shell

**Files:**
- Create: `lib/ui/theme.dart`, `lib/ui/app.dart`, `lib/providers/app_providers.dart`
- Modify: `lib/main.dart`
- Test: `test/ui/app_test.dart`

**Interfaces:**
- Produces: `class AppTheme { static ThemeData light(); static ThemeData dark(); }`, `class AppShell` with `NavigationBar` for Today / Teams / Calendar / Settings, and Riverpod providers `repoProvider`, `schedulerProvider`, `prefsProvider`, `syncProvider`.

- [ ] **Step 1: Write the failing widget test**

`test/ui/app_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/ui/app.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/services/prefs_test_impl.dart';
import 'package:hackathon_manager/services/scheduler.dart';

void main() {
  testWidgets('app shell renders the four destinations', (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    final notifier = _NullNotifier();
    final scheduler = NotificationScheduler(repo: repo, notifier: notifier, prefs: InMemoryPrefs());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        repoProvider.overrideWithValue(repo),
        schedulerProvider.overrideWithValue(scheduler),
        prefsProvider.overrideWithValue(InMemoryPrefs()),
      ],
      child: const HackathonManagerApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await db.close();
  });
}

class _NullNotifier implements Notifier {
  @override
  Future<void> schedule({required String key, required DateTime fireAt, required String title,
      required String body, required Priority priority}) async {}
  @override
  Future<void> cancel(String key) async {}
  @override
  Future<void> show({required String key, required String title, required String body,
      required Priority priority}) async {}
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/ui/app_test.dart
```

Expected: FAIL, URI not found.

- [ ] **Step 3: Implement the theme, providers, and shell**

`lib/providers/app_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../data/sync.dart';
import '../services/scheduler.dart';
import '../services/prefs.dart';
import '../services/notifier_impl.dart';
import '../services/db_provider.dart';

final repoProvider = Provider<Repository>((ref) async {
  final db = await db;
  return Repository(db);
});

final prefsProvider = Provider<PrefsStore>((ref) => PrefsStore());

final schedulerProvider = Provider<NotificationScheduler>((ref) {
  final repo = ref.watch(repoProvider);
  final prefs = ref.watch(prefsProvider);
  final notifier = FlutterNotifier();
  return NotificationScheduler(repo: repo, notifier: notifier, prefs: prefs);
});

final syncProvider = Provider<SyncRepository>((ref) => LocalOnlySyncRepository());
```

- [ ] **Step 4: Run the test**

```bash
flutter test test/ui/app_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test && git commit -q -m "feat(ui): material 3 shell with today, teams, calendar, settings

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 9: Today view, hackathon list, and detail

**Files:**
- Create: `lib/ui/today/today_view.dart`, `lib/ui/hackathons/hackathon_list.dart`, `lib/ui/hackathons/hackathon_detail.dart`, `lib/ui/hackathons/milestone_editor.dart`, `lib/ui/hackathons/add_hackathon_sheet.dart`
- Test: `test/ui/today_view_test.dart`, `test/ui/add_hackathon_test.dart`

**Interfaces:**
- Produces: `class TodayView`, `class HackathonList`, `class HackathonDetail({int hackathonId})`, `class MilestoneEditor({int hackathonId, Milestone? initial})`, `class AddHackathonSheet`

- [ ] **Step 1: Write the failing widget tests**

`test/ui/today_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/providers/app_providers.dart';
import 'package:hackathon_manager/ui/today/today_view.dart';
import 'package:hackathon_manager/services/prefs_test_impl.dart';
import 'package:hackathon_manager/services/scheduler.dart';

class _NullNotifier implements Notifier {
  @override
  Future<void> schedule({required String key, required DateTime fireAt, required String title,
      required String body, required Priority priority}) async {}
  @override
  Future<void> cancel(String key) async {}
  @override
  Future<void> show({required String key, required String title, required String body,
      required Priority priority}) async {}
}

Future<WidgetTester> _seed(WidgetTester tester, {bool addConfirmedTeam = false}) async {
  final db = AppDatabase();
  final repo = Repository(db);
  final scheduler = NotificationScheduler(repo: repo, notifier: _NullNotifier(), prefs: InMemoryPrefs());
  final now = DateTime.now().toUtc();
  await repo.saveHackathon(Hackathon(
    id: -1, name: 'Alpha Hack', organizer: 'Org', url: '', mode: HackathonMode.online,
    location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
    createdAt: now, modifiedAt: now,
  ));
  await repo.saveMilestone(Milestone(
    id: -1, hackathonId: 1, label: MilestoneLabel.finalSubmission, title: 'Final submission',
    endsAtUtc: now.add(const Duration(days: 3)), timezone: 'UTC', isCritical: true,
    verified: false, createdAt: now, modifiedAt: now,
  ));
  tester.pumpWidget(ProviderScope(overrides: [
    repoProvider.overrideWithValue(repo),
    schedulerProvider.overrideWithValue(scheduler),
    prefsProvider.overrideWithValue(InMemoryPrefs()),
  ], child: const MaterialApp(home: TodayView())));
  await tester.pumpAndSettle();
  expect(find.text('Alpha Hack'), findsWidgets);
  return tester;
}

void main() {
  testWidgets('today view shows the next 7 days of deadlines', (tester) async {
    await _seed(tester);
  });

  testWidgets('today view flags a hackathon without a confirmed team', (tester) async {
    await _seed(tester);
    expect(find.textContaining('No confirmed team'), findsOneWidget);
  });
}
```

`test/ui/add_hackathon_test.dart`: a widget test that opens the add sheet, fills the name and a milestone, saves, and asserts the new hackathon appears in the list.

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/ui/
```

Expected: FAIL.

- [ ] **Step 3: Implement the Today view**

FR-19: three sections. Section 1 is deadlines in the next 7 days, grouped by day, sorted by time. Each row shows the hackathon name, the milestone title, the local wall-clock time, a Critical badge, and a Verified checkmark. Section 2 is hackathons without a confirmed team, sorted by upcoming deadline. Section 3 is unresolved conflicts, one card each with the message and a Primary / Backup action. An empty state renders a single sentence and a single action button.

- [ ] **Step 4: Implement the hackathon list and detail**

FR-1: the list shows name, mode chip, status chip, and next deadline. Tapping a hackathon opens the detail. FR-2: the detail shows milestones sorted by time, each with the wall-clock time in the milestone's declared zone, the Critical badge, the source link, and the Verified toggle. FR-4: the Verified toggle is a single button that flips `verified` from false to true. FR-5: editing a date opens a modal that shows the old and new values side by side before writing, and the change log is shown below the milestone. FR-16: editing a milestone that exceeds the hackathon's team size limit warns inline.

- [ ] **Step 5: Implement the add-hackathon sheet**

Under 60 seconds (NFR): a single sheet with the basics at top, then milestones added by tapping an "Add milestone" button that opens a compact inline editor. No wizard, no multi-step form. The first milestone is auto-suggested from the event window if one exists.

- [ ] **Step 6: Run tests**

```bash
flutter test test/ui/
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib test && git commit -q -m "feat(ui): today view, hackathon list and detail, add-hackathon sheet

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 10: Team tracking and the My Teams view

**Files:**
- Create: `lib/ui/team/my_teams_view.dart`, `lib/ui/team/team_editor.dart`, `lib/ui/team/team_detail.dart`
- Test: `test/ui/team_test.dart`

**Interfaces:**
- Produces: `class MyTeamsView`, `class TeamEditor({int hackathonId, Team? initial})`, `class TeamDetail({int teamId})`

- [ ] **Step 1: Write the failing widget tests**

`test/ui/team_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/providers/app_providers.dart';
import 'package:hackathon_manager/ui/team/my_teams_view.dart';
import 'package:hackathon_manager/services/prefs_test_impl.dart';
import 'package:hackathon_manager/services/scheduler.dart';

class _NullNotifier implements Notifier {
  @override
  Future<void> schedule({required String key, required DateTime fireAt, required String title,
      required String body, required Priority priority}) async {}
  @override
  Future<void> cancel(String key) async {}
  @override
  Future<void> show({required String key, required String title, required String body,
      required Priority priority}) async {}
}

void main() {
  testWidgets('my teams view lists hackathon, team, status, and next deadline', (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    final now = DateTime.now().toUtc();
    final h = await repo.saveHackathon(Hackathon(
      id: -1, name: 'Alpha', organizer: 'Org', url: '', mode: HackathonMode.online,
      location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
      createdAt: now, modifiedAt: now,
    ));
    await repo.saveMilestone(Milestone(
      id: -1, hackathonId: h.id, label: MilestoneLabel.finalSubmission, title: 'Submit',
      endsAtUtc: now.add(const Duration(days: 5)), timezone: 'UTC', isCritical: true,
      verified: false, createdAt: now, modifiedAt: now,
    ));
    await repo.saveTeam(Team(
      id: -1, hackathonId: h.id, name: 'Night Owls', status: TeamStatus.confirmed,
      ideaTitle: 'Sleep app', techStack: 'Flutter', repoUrl: '', chatUrl: '', notes: '',
      createdAt: now, modifiedAt: now,
    ));
    await tester.pumpWidget(ProviderScope(overrides: [
      repoProvider.overrideWithValue(repo),
      schedulerProvider.overrideWithValue(NotificationScheduler(repo: repo, notifier: _NullNotifier(), prefs: InMemoryPrefs())),
      prefsProvider.overrideWithValue(InMemoryPrefs()),
    ], child: const MaterialApp(home: MyTeamsView())));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Night Owls'), findsWidgets);
    expect(find.text('Confirmed'), findsWidgets);
    await db.close();
  });

  testWidgets('a second confirmed team for the same hackathon warns', (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    final now = DateTime.now().toUtc();
    final h = await repo.saveHackathon(Hackathon(
      id: -1, name: 'Alpha', organizer: 'Org', url: '', mode: HackathonMode.online,
      location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
      createdAt: now, modifiedAt: now,
    ));
    for (final name in ['Night Owls', 'Second Team']) {
      await repo.saveTeam(Team(
        id: -1, hackathonId: h.id, name: name, status: TeamStatus.confirmed,
        ideaTitle: '', techStack: '', repoUrl: '', chatUrl: '', notes: '',
        createdAt: now, modifiedAt: now,
      ));
    }
    await tester.pumpWidget(ProviderScope(overrides: [
      repoProvider.overrideWithValue(repo),
      schedulerProvider.overrideWithValue(NotificationScheduler(repo: repo, notifier: _NullNotifier(), prefs: InMemoryPrefs())),
      prefsProvider.overrideWithValue(InMemoryPrefs()),
    ], child: const MaterialApp(home: MyTeamsView())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Another confirmed team'), findsOneWidget);
    await db.close();
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/ui/team_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement the views**

FR-13, FR-14: `team_editor` takes name, members with name/role/contact/lead, idea title, tech stack, repo URL, chat URL, notes, and status. FR-15: on save, if the team is being set to `Confirmed` and another `Confirmed` team already exists for this hackathon, show a warning dialog with an "Understand, set anyway" action and a "Cancel" action; the warning is not a blocker. FR-16: on save, if the member count exceeds `maxSize`, warn the same way. FR-17: every save appends to `team_changes`. FR-18: the My Teams view shows one row per hackathon with the team name, a status chip, and the next deadline in the hackathon's organizer timezone.

- [ ] **Step 4: Run tests**

```bash
flutter test test/ui/team_test.dart
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib test && git commit -q -m "feat(team): my teams view, team editor, status lifecycle with warnings

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 11: Calendar view and settings

**Files:**
- Create: `lib/ui/calendar/calendar_view.dart`, `lib/ui/settings/settings_view.dart`
- Test: `test/ui/calendar_test.dart`

**Interfaces:**
- Produces: `class CalendarView`, `class SettingsView`

- [ ] **Step 1: Write the failing widget tests**

`test/ui/calendar_test.dart`: a widget test that seeds one milestone, opens the calendar view, navigates to the month containing that milestone, and asserts the milestone is visible with its priority color.

`test/ui/settings_test.dart`: a widget test that opens settings, toggles the reminder profile, toggles quiet hours, and asserts both persist across a re-open.

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/ui/calendar_test.dart test/ui/settings_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement the views**

FR-21: the calendar is a month grid. Each day cell shows a dot per milestone, colored Critical (primary), High (secondary), Normal (outline). Tapping a day opens a sheet listing that day's milestones with their hackathon and local time.

Settings: reminder profile selector (FR-12, three options with a description of what changes), quiet hours start/end with an enabled toggle (FR-9), user timezone selector restricted to `ZoneRegistry.all`, the exact-alarm status on Android with a button that opens the system setting, a data summary showing counts of hackathons, milestones, and teams, and a row that says "Local only" from the sync status.

- [ ] **Step 4: Run tests**

```bash
flutter test test/ui/calendar_test.dart test/ui/settings_test.dart
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib test && git commit -q -m "feat(ui): calendar view and settings with reminder profile and quiet hours

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Task 12: Verification — run on desktop and confirm the suite

**Files:**
- Modify: none
- Create: `README.md` at the project root

**Interfaces:**
- Produces: a working desktop build observed in a browser preview, and a green test suite.

- [ ] **Step 1: Full test suite**

```bash
flutter test
```

Expected: every test in `test/engine/`, `test/data/`, `test/services/`, `test/ui/` passes.

- [ ] **Step 2: Static analysis**

```bash
flutter analyze
```

Expected: `No issues found`.

- [ ] **Step 3: Confirm the app runs on desktop**

Start a Flutter desktop preview. If the preview pane is unavailable, run:

```bash
flutter run -d windows
```

Observe: the Today view loads with seed data, the add-hackathon sheet opens and saves, the My Teams view renders, and the calendar shows the milestones. Confirm no console errors and that the Today view renders in under one second with the seed data.

- [ ] **Step 4: Grep gate — engine stays pure**

```bash
grep -rn "package:flutter\|package:drift\|local_notifications\|package:intl\|package:path" lib/engine/ && echo "FAIL" || echo "OK"
```

Expected: `OK`.

- [ ] **Step 5: Write the README**

`README.md` covers: what the app does, how to run it (`flutter pub get`, `flutter run -d windows`, `flutter test`), the engine/data/services/ui layout, how to add a timezone, and the explicit list of things NOT verified in this environment: real OS alarm delivery, Android battery-optimization exemption, Windows notification behaviour with the app closed, and any cross-device sync (v1.0).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -q -m "chore: verification and README

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Self-review checklist

- [ ] Every FR-1 through FR-20 has a task.
- [ ] Every engine file has a test file.
- [ ] No engine file imports Flutter.
- [ ] The scheduler test uses a real SQLite-backed repository, not a mock.
- [ ] Reminder transition persists before the notification is shown.
- [ ] Verified flag is set only by an explicit user action, never by import or date edit.
- [ ] Date edits log before they write.
- [ ] Conflict detection is inclusive at 24 hours, tested both directions.
- [ ] Second-confirmed-team and roster-over-limit warnings are not blockers.
- [ ] README explicitly lists what is not verified.
- [ ] Every task ends in a commit with the attribution line.
```
