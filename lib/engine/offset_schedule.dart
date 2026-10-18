import 'models.dart';
import 'priority.dart';
import 'timezone_util.dart';

/// FR-6: schedule reminders by priority. Offsets count backwards from
/// [Milestone.endsAtUtc].
///
/// Planning is idempotent per (milestoneId, scheduleIndex, profile). Re-running
/// after a date change produces the same keys at the shifted times, so the
/// scheduler can replace a milestone's alarms wholesale without leaking state.
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
        body: 'In ${TimezoneUtil.formatInstant(offsets[i])} — '
            '${TimezoneUtil.displayWallClock(m.endsAtUtc, m.timezone, style: 'full')}',
      ));
    }
    return result;
  }

  /// Builds a reminder key from its parts. Shared by the planner and the
  /// scheduler so both agree on identity.
  static String keyFor(int milestoneId, int scheduleIndex) => 'm${milestoneId}#$scheduleIndex';

  static Priority _priorityOf(Milestone m) => PriorityClassifier.classify(m.label, m.title).$1;
}
