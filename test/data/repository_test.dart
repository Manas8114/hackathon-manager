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
