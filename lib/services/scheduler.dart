import '../engine/models.dart';
import '../engine/offset_schedule.dart';
import '../engine/quiet_hours.dart';
import '../engine/reminder_machine.dart';
import '../engine/timezone_util.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../data/prefs.dart';
import '../data/change_log.dart';


// ─── Notifier interface ───────────────────────────────────────────────────────

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

// ─── Null notifier (for tests / desktop where notifications aren't wired) ────

class NullNotifier implements Notifier {
  @override
  Future<void> schedule({
    required String key,
    required DateTime fireAt,
    required String title,
    required String body,
    required Priority priority,
  }) async {}

  @override
  Future<void> cancel(String key) async {}

  @override
  Future<void> show({
    required String key,
    required String title,
    required String body,
    required Priority priority,
  }) async {}
}

// ─── Scheduler ────────────────────────────────────────────────────────────────

class NotificationScheduler {
  NotificationScheduler({
    required this.repo,
    required this.notifier,
    required this.prefs,
  });

  final Repository repo;
  final Notifier notifier;
  final PrefsStore prefs;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Plans all reminders for all non-archived milestones. Idempotent.
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

  /// Replans a single milestone after a date or profile change.
  Future<void> replanForMilestone(int milestoneId) async {
    final m = await repo.milestone(milestoneId);
    if (m == null) return;
    await _replan(m, await prefs.getProfile(), DateTime.now().toUtc());
  }

  /// Called when the OS fires an alarm. Transitions Scheduled → Fired.
  Future<void> handleReminder(String key) async {
    final row = await repo.reminder(key);
    if (row == null || ReminderMachine.isTerminal(row.state)) return;
    final next = ReminderMachine.next(row.state, ReminderAction.elapsed);
    final newCount = (next == ReminderState.repeatArmed &&
            row.state == ReminderState.fired)
        ? ReminderMachine.nextRepeatCount(row.repeatCount)
        : row.repeatCount;
    if (next == ReminderState.repeatArmed &&
        !ReminderMachine.shouldRepeat(row.priority, newCount)) {
      await repo.updateReminderState(key, ReminderState.skipped);
      return;
    }
    await repo.updateReminderState(
      key,
      next,
      repeatCount: newCount,
      armedAtUtc: DateTime.now().toUtc(),
    );
    await notifier.show(
      key: key,
      title: _titleFor(row),
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
    final delta =
        tomorrow ? const Duration(hours: 24) : const Duration(hours: 1);
    final newFire = row.firesAtUtc.add(delta);
    await repo.updateReminderState(
      key,
      ReminderState.snoozed,
      firesAtUtc: newFire,
      armedAtUtc: DateTime.now().toUtc(),
    );
    await notifier.schedule(
      key: key,
      fireAt: newFire,
      title: 'Snoozed reminder',
      body: '',
      priority: row.priority,
    );
  }

  Future<void> skip(String key) async {
    await repo.updateReminderState(key, ReminderState.skipped);
    await notifier.cancel(key);
  }

  Future<List<ScheduledReminder>> pendingReminders() async {
    final rows = await repo.watchScheduledReminders().first;
    final now = DateTime.now().toUtc();
    return rows
        .where((r) =>
            !ReminderMachine.isTerminal(r.state) &&
            r.firesAtUtc.isAfter(now))
        .map((r) => ScheduledReminder(
              key: r.key,
              milestoneId: r.milestoneId,
              scheduleIndex: r.scheduleIndex,
              firesAtUtc: r.firesAtUtc,
              priority: r.priority,
              title: _titleFor(r),
              body: '',
            ))
        .toList();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _titleFor(ReminderStateRecord r) =>
      'Reminder (milestone ${r.milestoneId})';

  Future<void> _replan(
      Milestone m, ReminderProfile profile, DateTime now) async {
    // Cancel + delete existing non-terminal reminders for this milestone.
    final existing = await repo.remindersForMilestone(m.id);
    for (final e in existing) {
      if (!ReminderMachine.isTerminal(e.state)) {
        await notifier.cancel(e.key);
      }
      await repo.deleteReminderState(e.key);
    }

    // Build the new plan.
    final plan = OffsetSchedule.plan(m, profile, now);
    final quietHours = await prefs.getQuietHours();
    final tz = await prefs.getUserTimezone();

    for (final r in plan) {
      // QuietHoursGate.gate expects a DateTime Function(DateTime utc)
      // TimezoneUtil provides offsetMinutes which we use to build the local time.
      final gate = QuietHoursGate.gate(
        r.firesAtUtc,
        r.priority,
        quietHours,
        (utc) {
          final offset = TimezoneUtil.offsetMinutes(utc, tz);
          return utc.add(Duration(minutes: offset));
        },
      );
      final record = ReminderStateRecord(
        key: r.key,
        milestoneId: r.milestoneId,
        scheduleIndex: r.scheduleIndex,
        profile: profile.id,
        firesAtUtc: gate.effectiveAtUtc,
        priority: r.priority,
        state: ReminderState.scheduled,
        repeatCount: 0,
        updatedAtUtc: DateTime.now().toUtc(),
      );
      // Persist BEFORE scheduling the alarm (crash safety).
      await repo.upsertReminderState(record);
      await notifier.schedule(
        key: r.key,
        fireAt: gate.effectiveAtUtc,
        title: r.title,
        body: r.body,
        priority: r.priority,
      );
    }
  }
}
