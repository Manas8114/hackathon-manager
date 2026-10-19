# ⚡ Hackathon Manager

> **A personal, offline-first mobile app that ensures you never miss a hackathon deadline, tracks your teams in one glance, and keeps critical schedules conflict-free.**

[![Flutter](https://img.shields.io/badge/Flutter-3.41.2-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Release](https://img.shields.io/github/v/release/Manas8114/hackathon-manager?color=brightgreen&label=Release)](https://github.com/Manas8114/hackathon-manager/releases)
[![Build Status](https://img.shields.io/badge/Tests-133%20Passed-success?logo=checkmarx)](test/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 📱 Download Compiled App

Get the pre-compiled Android release build directly from the GitHub Releases:

📦 **[Download Hackathon Manager APK (v1.0.0)](https://github.com/Manas8114/hackathon-manager/releases/download/v1.0.0/hackathon-manager-v1.0.0.apk)**

> **Installation Tip**: On Android, open the downloaded `.apk` file and grant *"Install unknown apps"* permission if prompted by your browser or file manager.

---

## 🎯 Key Capabilities

- **🛡️ Pure Dart Reliability Engine**: Core business logic (deadlines, cadences, conflicts, quiet hours, state machines) runs completely decoupled from UI in a pure Dart VM engine with **133 exhaustive unit tests**.
- **⏰ Smart Deadline Cadences**:
  - **Critical Milestones** (Registration Close, Final Submission): Alarms at `7d`, `3d`, `1d`, `6h`, `1h`, and `15m` with an auto-repeat escalation machine (up to 3x, 30m intervals).
  - **High Priority** (Demos, Pitches, Checkpoints): Alarms at `3d`, `1d`, `1h`.
  - **Normal Milestones**: Alarms at `1d`, `30m`.
- **🌙 Configurable Quiet Hours**: Suppresses non-critical alarms during designated sleep or focus windows and automatically reschedules them for the earliest permitted minute. Critical submission alarms always break through.
- **🌐 Robust IANA Timezone Engine**: Never lose an hour to Daylight Saving Time (DST). Organizers' announced local wall-clock times are converted to and stored in UTC microseconds with their IANA zone (`America/New_York`, `Asia/Kolkata`, `Europe/Berlin`, etc.).
- **⚠️ Conflict & Overlap Detector**: Instantly flags overlapping event windows, tight submission deadlines (< 24h apart), or "orphaned" hackathons missing a confirmed team.
- **👥 Team & Roster Rules**: Lifecycle tracking (`looking` ➔ `applied` ➔ `confirmed` ➔ `registered`), roster size overflow warnings, duplicate confirmed team prevention, and audit-logged membership changes.
- **📅 Today & 7-Day Window View**: High-density dashboard displaying upcoming deadlines, team statuses, and urgent notices in under 1 second.
- **🔌 Offline-First Architecture**: 100% functional without cellular or Wi-Fi connectivity.

---

## 🏗️ Architecture & Project Structure

```
hackathon_manager/
├── lib/
│   ├── engine/                     # Pure Dart layer — zero UI/plugin coupling
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
│   └── main.dart                   # Application entrypoint & Flutter UI
├── android/                        # Android project configured with AGP 8.11 & desugaring
├── windows/                        # Windows native desktop runner
├── docs/                           # Architecture specifications & MVP execution plans
└── test/
    └── engine/                     # 133 pure Dart test specs (DST, Cadence, Conflicts)
```

---

## 🧪 Testing & Verification

The core scheduling and validation engine is backed by an automated test suite verifying edge cases like DST transitions across global timezones, quiet-hour boundaries, and reminder state-machine transitions:

```bash
# Run all tests
flutter test
```

```
00:02 +133: All tests passed!
```

---

## 🚀 Building from Source

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) `^3.41.0`
- [Dart SDK](https://dart.dev) `^3.11.0`
- Java JDK 17+
- Android SDK (API 35+)

### Setup & Compilation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Manas8114/hackathon-manager.git
   cd hackathon-manager
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app locally:**
   ```bash
   # Windows Desktop
   flutter run -d windows

   # Chrome / Web
   flutter run -d chrome
   ```

4. **Build release Android APK:**
   ```bash
   flutter build apk --release
   ```
   The compiled artifact will be generated at:  
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
