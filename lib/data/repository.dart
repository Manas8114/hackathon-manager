import 'dart:async';
import '../engine/models.dart';
import 'database.dart';

/// Repository wraps AppDatabase and exposes domain-level methods.
/// All writes go through here; direct DB access is disallowed from UI/services.
class Repository {
  Repository(this._db);

  final AppDatabase _db;

  // ── Hackathons ──────────────────────────────────────────────────────────────

  Stream<List<Hackathon>> watchHackathons() => _db.watchHackathons();
  Future<Hackathon> saveHackathon(Hackathon h) => _db.saveHackathon(h);
  Future<void> archiveHackathon(int id) => _db.archiveHackathon(id);
  Future<int> countHackathons() => _db.countHackathons();

  // ── Milestones ──────────────────────────────────────────────────────────────

  Stream<List<Milestone>> watchMilestonesFor(int hackathonId) =>
      _db.watchMilestonesFor(hackathonId);
  Stream<Map<int, List<Milestone>>> watchMilestonesGrouped() =>
      _db.watchMilestonesGrouped();
  Future<Milestone?> milestone(int id) => _db.milestone(id);
  Future<Milestone> saveMilestone(Milestone m) => _db.saveMilestone(m);
  Future<void> deleteMilestone(int id) => _db.deleteMilestone(id);
  Stream<List<MilestoneChange>> watchMilestoneChanges(int milestoneId) =>
      _db.watchMilestoneChanges(milestoneId);

  // ── Teams ───────────────────────────────────────────────────────────────────

  Stream<List<Team>> watchTeamsFor(int hackathonId) =>
      _db.watchTeamsFor(hackathonId);
  Stream<Map<int, int>> watchMemberCounts() => _db.watchMemberCounts();
  Future<Team> saveTeam(Team t) => _db.saveTeam(t);
  Future<void> saveTeamMembers(int teamId, List<TeamMember> members) =>
      _db.saveTeamMembers(teamId, members);
  Future<void> setTeamStatus(int teamId, TeamStatus s) =>
      _db.setTeamStatus(teamId, s);
  Stream<List<TeamChange>> watchTeamChanges(int teamId) =>
      _db.watchTeamChanges(teamId);

  List<TeamMember> membersFor(int teamId) => _db.membersFor(teamId);
  List<Team> teamsFor(int hackathonId) => _db.teamsFor(hackathonId);
  List<Team> get allTeams => _db.allTeams;
  List<Hackathon> get cachedHackathons => _db.allHackathons;
  Map<int, List<Milestone>> get cachedMilestones => _db.buildGrouped();

  // ── Reminder States ─────────────────────────────────────────────────────────

  Stream<List<ReminderStateRecord>> watchScheduledReminders() =>
      _db.watchScheduledReminders();
  Future<ReminderStateRecord?> reminder(String key) => _db.reminder(key);
  Future<List<ReminderStateRecord>> remindersForMilestone(int milestoneId) =>
      _db.remindersForMilestone(milestoneId);
  Future<void> upsertReminderState(ReminderStateRecord r) =>
      _db.upsertReminderState(r);
  Future<void> deleteReminderState(String key) =>
      _db.deleteReminderState(key);
  Future<void> updateReminderState(
    String key,
    ReminderState state, {
    DateTime? firesAtUtc,
    int? repeatCount,
    DateTime? armedAtUtc,
  }) =>
      _db.updateReminderState(
        key,
        state,
        firesAtUtc: firesAtUtc,
        repeatCount: repeatCount,
        armedAtUtc: armedAtUtc,
      );
}
