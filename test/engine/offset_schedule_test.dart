import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/offset_schedule.dart';

Milestone _m({DateTime? endsAtUtc, bool isCritical = true, int id = 1}) => Milestone(
      id: id,
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

Milestone _normalM() => Milestone(
      id: 2,
      hackathonId: 1,
      label: MilestoneLabel.other,
      title: 'Stretch goal',
      endsAtUtc: DateTime.utc(2026, 10, 24, 23, 59, 59),
      timezone: 'UTC',
      isCritical: false,
      verified: false,
      createdAt: DateTime.utc(2026, 10, 1),
      modifiedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  test('critical cadence under Standard produces 6 reminders at PRD offsets', () {
    final now = DateTime.utc(2026, 10, 1, 12, 0, 0);
    final plan = OffsetSchedule.plan(_m(), ReminderProfile.standard, now);
    expect(plan.length, 6);
    final offsets = plan
        .map((r) => r.firesAtUtc.difference(_m().endsAtUtc).abs())
        .toList()
      ..sort((a, b) => b.compareTo(a));
    expect(offsets.first, const Duration(days: 7));
    expect(offsets.last, const Duration(minutes: 15));
    expect(plan.every((r) => r.priority == Priority.critical), isTrue);
  });

  test('normal cadence has 2 reminders: 1d and 30m', () {
    final now = DateTime.utc(2026, 10, 1, 12, 0, 0);
    final plan = OffsetSchedule.plan(_normalM(), ReminderProfile.standard, now);
    expect(plan.length, 2);
    expect(plan.map((r) => r.priority), everyElement(Priority.normal));
    final offsets = plan.map((r) => r.firesAtUtc.difference(_normalM().endsAtUtc).abs()).toList()
      ..sort((a, b) => b.compareTo(a));
    expect(offsets.first, const Duration(days: 1));
    expect(offsets.last, const Duration(minutes: 30));
  });

  test('high cadence has 3 reminders: 3d, 1d, 1h', () {
    final m = _normalM().copyWith(label: MilestoneLabel.demo);
    final plan = OffsetSchedule.plan(m, ReminderProfile.standard, DateTime.utc(2026, 10, 1));
    expect(plan.length, 3);
    expect(plan.map((r) => r.priority), everyElement(Priority.high));
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
    final endsAt = DateTime.utc(2026, 10, 24, 23, 59, 59);
    final plan = OffsetSchedule.plan(_m(), ReminderProfile.standard, now);
    for (final r in plan) {
      expect(r.firesAtUtc.isAfter(now), isTrue);
      expect(r.firesAtUtc.isBefore(endsAt), isTrue);
    }
  });

  test('keys are unique and stable per schedule index', () {
    final plan = OffsetSchedule.plan(_m(), ReminderProfile.standard, DateTime.utc(2026, 10, 1));
    final keys = plan.map((r) => r.key).toSet();
    expect(keys.length, plan.length);
    expect(plan.first.key, 'm1#0');
    expect(plan.last.key, 'm1#5');
  });

  test('minimal profile for critical keeps only 1d and 1h', () {
    final plan = OffsetSchedule.plan(_m(), ReminderProfile.minimal, DateTime.utc(2026, 10, 1));
    expect(plan.length, 2);
    final offsets = plan.map((r) => r.firesAtUtc.difference(_m().endsAtUtc).abs()).toList()
      ..sort((a, b) => b.compareTo(a));
    expect(offsets.first, const Duration(days: 1));
    expect(offsets.last, const Duration(hours: 1));
  });

  test('intense profile adds a 4h lead time for critical', () {
    final plan = OffsetSchedule.plan(_m(), ReminderProfile.intense, DateTime.utc(2026, 10, 1));
    expect(plan.length, 7);
    final offsets = plan.map((r) => r.firesAtUtc.difference(_m().endsAtUtc).abs()).toList();
    expect(offsets, contains(const Duration(hours: 4)));
  });

  test('replanning after a date change moves every fire time by the same delta', () {
    final now = DateTime.utc(2026, 10, 1, 0, 0, 0);
    final a = OffsetSchedule.plan(_m(endsAtUtc: DateTime.utc(2026, 10, 24)),
        ReminderProfile.standard, now);
    final b = OffsetSchedule.plan(_m(endsAtUtc: DateTime.utc(2026, 11, 1)),
        ReminderProfile.standard, now);
    final delta = DateTime.utc(2026, 11, 1).difference(DateTime.utc(2026, 10, 24));
    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      expect(b[i].firesAtUtc.difference(a[i].firesAtUtc), delta);
      expect(b[i].key, a[i].key);
    }
  });

  test('a milestone exactly now has no scheduled reminders', () {
    final endsAt = DateTime.utc(2026, 10, 18, 0, 0, 0);
    final plan = OffsetSchedule.plan(_m(endsAtUtc: endsAt), ReminderProfile.standard, endsAt);
    expect(plan, isEmpty);
  });

  test('the body names the deadline in the milestone timezone', () {
    final m = _m(endsAtUtc: DateTime.utc(2026, 10, 24, 5, 0, 0));
    final plan = OffsetSchedule.plan(m, ReminderProfile.minimal, DateTime.utc(2026, 10, 1));
    // 05:00 UTC on 24 Oct is 01:00 America/New_York (EDT).
    expect(plan.first.body, contains('01:00'));
  });
}
