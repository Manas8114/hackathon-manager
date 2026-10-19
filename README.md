# ⚡ Hackathon Manager

> **A personal, offline-first mobile and desktop application that ensures you never miss a hackathon deadline, tracks your teams in one glance, and keeps critical schedules conflict-free.**

[![Flutter](https://img.shields.io/badge/Flutter-3.41.2-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Tests](https://img.shields.io/badge/Tests-155%20Passed-success?logo=checkmarx)](test/)
[![Analysis](https://img.shields.io/badge/Analysis-Clean%20(0%20issues)-brightgreen)](lib/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 📱 Pre-Compiled Releases

Get the pre-compiled Android release build directly:

- 📦 **[Download APK from GitHub Releases (v1.0.0)](https://github.com/Manas8114/hackathon-manager/releases/download/v1.0.0/hackathon-manager-v1.0.0.apk)**
- 📁 **[Download APK directly from Repository (`release/hackathon-manager-v1.0.0.apk`)](release/hackathon-manager-v1.0.0.apk)**

> **Installation Tip**: On Android, open the downloaded `.apk` file and grant *"Install unknown apps"* permission if prompted by your browser or file manager.

---

## 🎯 Key Capabilities

- **🛡️ 100% Pure Dart Reliability Engine**: Core business logic (deadlines, cadences, conflicts, quiet hours, state machines) runs completely decoupled from UI in a pure Dart layer with **zero external package dependencies** (enforced by automated grep gate) and verified by **155 automated tests**.
- **⏰ Smart Deadline Cadences**:
  - **Critical Milestones** (Registration Close, Final Submission): Alarms at `7d`, `3d`, `1d`, `6h`, `1h`, and `15m` with an auto-repeat escalation machine (up to 3x, 30m intervals).
  - **High Priority** (Demos, Pitches, Checkpoints): Alarms at `3d`, `1d`, `1h`.
  - **Normal Milestones**: Alarms at `1d`, `30m`.
- **🌙 Configurable Quiet Hours**: Suppresses non-critical alarms during designated sleep or focus windows and automatically reschedules them for the earliest permitted minute. Critical submission alarms always break through.
- **🌐 Robust IANA Timezone Engine**: Never lose an hour to Daylight Saving Time (DST). Organizers' announced local wall-clock times are converted to and stored in UTC microseconds with their IANA zone (`America/New_York`, `Asia/Kolkata`, `Europe/Berlin`, `America/Los_Angeles`, etc.).
- **⚠️ Conflict & Overlap Detector**: Instantly flags overlapping event windows, tight submission deadlines (< 24h apart), or "orphaned" hackathons missing a confirmed team.
- **👥 Team & Roster Rules**: Lifecycle tracking (`looking` ➔ `applied` ➔ `confirmed` ➔ `registered`), roster size overflow warnings, duplicate confirmed team prevention, and audit-logged membership changes.
- **📅 Today & 7-Day Window View**: High-density dashboard displaying upcoming deadlines, live countdowns, team statuses, and urgent notices in under 1 second.
- **🎨 Material 3 Design**: Fully adaptive Material 3 theme supporting responsive layouts, dark & light modes, priority color tokens, and custom navigation shells.
- **🔌 Offline-First Architecture**: 100% functional without cellular or Wi-Fi connectivity backed by SQLite / Drift.

---

## 🏗️ Architecture & Project Structure

The project strictly follows a clean 4-tier layered architecture:

```
hackathon_manager/
├── lib/
│   ├── engine/                     # Tier 1: Pure Dart layer — ZERO external packages
│   │   ├── models.dart             # Core DTOs, Enums, Value Types
│   │   ├── timezone_util.dart      # IANA Zone registry, DST transitions, wall-clock display
│   │   ├── priority.dart           # FR-3 Automatic & manual priority classifier
│   │   ├── offset_schedule.dart    # FR-6 Pre-deadline cadence tables & profiles
│   │   ├── reminder_machine.dart   # FR-8 State machine (Scheduled/Fired/Snoozed/Repeat)
│   │   ├── conflict_detector.dart  # FR-20 Window overlaps & tight submission warnings
│   │   ├── quiet_hours.dart        # FR-9 Quiet hours suppression & shift rules
│   │   ├── team_rules.dart         # FR-13 to FR-17 Roster caps & status transitions
│   │   ├── today_view.dart         # FR-19 7-day milestone aggregator
│   │   ├── checklist.dart          # Submission verification & readiness
│   │   └── changelog.dart          # Milestone & team audit trails
│   ├── data/                       # Tier 2: Storage & Reactive Persistence
│   │   ├── database.dart           # Drift SQLite schema & tables
│   │   ├── repository.dart         # Reactive repository with Stream<T> and audit logging
│   │   ├── change_log.dart         # Monotonic change log records
│   │   ├── prefs.dart              # SharedPreferences settings store
│   │   └── sync.dart               # LocalOnlySyncRepository (v1.0) & SyncStatus
│   ├── services/                   # Tier 3: Platform Services
│   │   ├── scheduler.dart          # NotificationScheduler, Notifier contract, audio profiles
│   │   └── prefs_test_impl.dart    # In-memory preferences store for testing
│   ├── providers/                  # State Management
│   │   └── app_providers.dart      # Riverpod providers wiring Repository, Scheduler & Streams
│   ├── ui/                         # Tier 4: Material 3 Presentation
│   │   ├── theme.dart              # Material 3 light/dark color schemes & typography
│   │   ├── app.dart                # MaterialApp & global providers initialization
│   │   ├── app_shell.dart          # Adaptive NavigationBar & Page shell
│   │   ├── today/                  # Today dashboard, countdowns, quick complete
│   │   ├── hackathons/             # Hackathon list, detail, milestone editor, date shift dialog
│   │   ├── team/                   # My teams view, team editor, member management
│   │   ├── calendar/               # Month grid view with priority indicators & day sheet
│   │   ├── settings/               # Profile selector, quiet hours, timezone, sync status
│   │   └── shared/                 # Reusable UI components & status chips
│   └── main.dart                   # Application entrypoint
├── test/
│   ├── engine/                     # 133 pure Dart test specs (DST, Cadence, Conflicts)
│   ├── data/                       # Repository & Drift SQLite persistence tests
│   ├── services/                   # Scheduler state machine & alarm delivery tests
│   └── ui/                         # Widget tests for Today, Hackathons, Teams, Calendar, Settings
└── docs/                           # Architecture specifications & MVP execution plans
```

---

## 🧪 Testing & Verification

The codebase includes **155 automated unit and widget tests** covering the entire stack:

```bash
# Run all tests
flutter test
```

Expected output:
```text
00:04 +155: All tests passed!
```

### Static Analysis & Engine Purity

Verify that static analysis passes with zero issues:
```bash
flutter analyze
```

Verify that the engine layer remains 100% pure Dart:
```bash
grep -rn "package:flutter\|package:drift\|local_notifications\|package:intl\|package:path" lib/engine/ && echo "FAIL" || echo "OK"
```

---

## 🚀 Running the App Locally

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) `^3.41.0`
- [Dart SDK](https://dart.dev) `^3.11.0`
- Android Studio / VS Code with Flutter extension
- Windows C++ Build Tools (if running Windows Desktop) or Google Chrome (for Web)

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Manas8114/hackathon-manager.git
   cd hackathon-manager
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on Chrome (Fastest Preview):**
   ```bash
   flutter run -d chrome
   ```

4. **Run on Windows Desktop:**
   ```bash
   flutter run -d windows
   ```
   *(Note: Building native Windows binaries requires Windows Developer Mode enabled for symlink creation).*

5. **Run on Android Emulator or Physical Device:**
   ```bash
   flutter run -d android
   ```

---

## 🌐 Adding a New Timezone

The timezone engine (`lib/engine/timezone_util.dart`) operates using an internal `ZoneRegistry` without depending on heavy native timezone libraries or external tzdb assets.

To add a new IANA timezone:
1. Open [`lib/engine/timezone_util.dart`](lib/engine/timezone_util.dart).
2. Add the IANA identifier and its offset rules into the `_zones` map:
   ```dart
   'Asia/Tokyo': const ZoneRule(
     identifier: 'Asia/Tokyo',
     displayName: 'Japan Standard Time',
     standardOffsetHours: 9,
     standardOffsetMinutes: 0,
     transitions: [], // Fixed offset, no DST
   ),
   ```
3. For zones observing Daylight Saving Time (e.g. EU / US transitions), specify transition epochs in the `transitions` list.
4. Run `flutter test test/engine/timezone_test.dart` to verify conversion accuracy.

---

## 🔍 Verification Boundaries (What Is & Isn't Verified)

### ✅ Fully Implemented and Verified in v1.0
- **100% Pure Dart Domain Engine**: All calculations for priority, cadence schedules, escalation state machine, quiet hours suppression/shifts, and conflict detection.
- **Strictly Monotonic Change Audit Log**: Every date change and team status update logs before write.
- **Side-by-Side Date Shift Modal**: Reviewing previous dates vs. new dates and recalculating dependent milestones before committing.
- **Roster Overflow & Confirmed Team Guards**: Warnings raised without blocking critical workflows.
- **Reactive Stream UI**: Riverpod streams updating in real time as SQLite tables update.

### ⚠️ Scope Exclusions for MVP (Deferred to v1.1)
- **Real OS Alarm Daemon When App is Killed**:
  - In MVP, notifications are dispatched via `NotificationScheduler` and the `Notifier` interface while the app process is active or backgrounded.
  - Waking a hard-killed app on heavily customized Android ROMs (MIUI, ColorOS) requires OEM battery-optimization whitelisting, exact alarm user permissions (`SCHEDULE_EXACT_ALARM`), and native Android foreground services.
- **Cross-Device Cloud Sync**:
  - v1.0 uses `LocalOnlySyncRepository` (status displays "Local only").
  - Multi-device sync over WebSockets/Cloud Firestore is architected via the `SyncRepository` interface and scheduled for v1.1.
- **Windows Notification Action Handlers**:
  - Snooze/Dismiss directly from Windows Action Center notifications requires desktop background toast activation registration.

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
