import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';

void main() {
  test('priority levels order critical > high > normal', () {
    expect(Priority.values.indexOf(Priority.critical),
        lessThan(Priority.values.indexOf(Priority.normal)));
  });

  test('team status lifecycle covers every PRD FR-14 state', () {
    expect(TeamStatus.values, containsAll([
      TeamStatus.looking,
      TeamStatus.applied,
      TeamStatus.invited,
      TeamStatus.confirmed,
      TeamStatus.left,
      TeamStatus.disbanded,
      TeamStatus.solo,
    ]));
  });

  test('reminder state machine states are all represented', () {
    expect(ReminderState.values, containsAll([
      ReminderState.scheduled,
      ReminderState.fired,
      ReminderState.done,
      ReminderState.snoozed,
      ReminderState.skipped,
      ReminderState.repeatArmed,
    ]));
  });

  test('team status isActive only covers applied, invited, confirmed', () {
    expect(TeamStatus.applied.isActive, isTrue);
    expect(TeamStatus.invited.isActive, isTrue);
    expect(TeamStatus.confirmed.isActive, isTrue);
    expect(TeamStatus.looking.isActive, isFalse);
    expect(TeamStatus.solo.isActive, isFalse);
  });

  test('milestone kind is window only when a start is set', () {
    final withWindow = Milestone(
      id: 1,
      hackathonId: 1,
      label: MilestoneLabel.eventWindow,
      title: 'Window',
      startsAtUtc: DateTime.utc(2026, 10, 20),
      endsAtUtc: DateTime.utc(2026, 10, 27),
      timezone: 'UTC',
      isCritical: false,
      verified: false,
      createdAt: DateTime.utc(2026, 10, 1),
      modifiedAt: DateTime.utc(2026, 10, 1),
    );
    final point = withWindow.copyWith(startsAtUtc: null);
    expect(withWindow.kind, MilestoneKind.window);
    expect(point.kind, MilestoneKind.point);
  });

  test('reminder profiles are all distinct and byId resolves', () {
    final ids = ReminderProfile.values.map((p) => p.id).toSet();
    expect(ids.length, 3);
    expect(ReminderProfile.byId('intense'), ReminderProfile.intense);
    expect(ReminderProfile.byId('no-such'), ReminderProfile.standard);
  });

  test('hackathon isArchived only for the archived status', () {
    final h = Hackathon(
      id: 1,
      name: 'X',
      organizer: 'O',
      url: '',
      mode: HackathonMode.online,
      location: '',
      organizerTimezone: 'UTC',
      status: HackathonStatus.archived,
      createdAt: DateTime.utc(2026, 10, 1),
      modifiedAt: DateTime.utc(2026, 10, 1),
    );
    expect(h.isArchived, isTrue);
    expect(h.copyWith(status: HackathonStatus.upcoming).isArchived, isFalse);
  });
}
