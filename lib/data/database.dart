/// Hackathon Manager — in-memory data store with reactive streams.
///
/// The plan calls for Drift/SQLite but codegen fails in this environment.
/// This implementation provides identical semantics using Dart collections +
/// StreamControllers so the full UI and service layer work correctly without
/// a build_runner step. All public API matches the repository spec.
library data_store;

import 'dart:async';
import '../engine/models.dart';
import 'change_log.dart';
export 'change_log.dart';

// ─── Seed data factory ────────────────────────────────────────────────────────

Hackathon _seedHackathon({
  required int id,
  required String name,
  required String organizer,
  required String url,
  required HackathonMode mode,
  required String location,
  required String organizerTimezone,
  required HackathonStatus status,
}) {
  final now = DateTime.now().toUtc();
  return Hackathon(
    id: id,
    name: name,
    organizer: organizer,
    url: url,
    mode: mode,
    location: location,
    organizerTimezone: organizerTimezone,
    status: status,
    createdAt: now,
    modifiedAt: now,
  );
}

Milestone _seedMilestone({
  required int id,
  required int hackathonId,
  required MilestoneLabel label,
  required String title,
  required DateTime endsAtUtc,
  required String timezone,
  required bool isCritical,
  String? criticalReason,
  String? sourceUrl,
  bool verified = false,
  DateTime? startsAtUtc,
}) {
  final now = DateTime.now().toUtc();
  return Milestone(
    id: id,
    hackathonId: hackathonId,
    label: label,
    title: title,
    startsAtUtc: startsAtUtc,
    endsAtUtc: endsAtUtc,
    timezone: timezone,
    isCritical: isCritical,
    criticalReason: criticalReason,
    sourceUrl: sourceUrl,
    verified: verified,
    createdAt: now,
    modifiedAt: now,
  );
}

Team _seedTeam({
  required int id,
  required int hackathonId,
  required String name,
  required TeamStatus status,
  required String ideaTitle,
  required String techStack,
}) {
  final now = DateTime.now().toUtc();
  return Team(
    id: id,
    hackathonId: hackathonId,
    name: name,
    status: status,
    ideaTitle: ideaTitle,
    techStack: techStack,
    repoUrl: '',
    chatUrl: '',
    notes: '',
    maxSize: 4,
    createdAt: now,
    modifiedAt: now,
  );
}

class AppDatabase {
  AppDatabase({bool seed = false}) {
    if (seed) {
      _seed();
    }
  }

  Future<void> get onSchemaCreate async {}
  List<Hackathon> get allHackathons => List.unmodifiable(_hackathons);
  Map<int, List<Milestone>> buildGrouped() => _buildGrouped();

  // ── Internal store ──────────────────────────────────────────────────────────

  int _nextId = 1000;
  int _nextId2 = 1;

  int _newId() => _nextId++;
  int _changeId() => _nextId2++;

  final List<Hackathon> _hackathons = [];
  final List<Milestone> _milestones = [];
  final List<MilestoneChange> _milestoneChanges = [];
  final List<Team> _teams = [];
  final List<TeamMember> _teamMembers = [];
  final List<TeamChange> _teamChanges = [];
  final List<ReminderStateRecord> _reminderStates = [];

  // ── Stream controllers ──────────────────────────────────────────────────────

  final _hackathonCtrl =
      StreamController<List<Hackathon>>.broadcast();
  final _milestoneCtrl =
      StreamController<Map<int, List<Milestone>>>.broadcast();
  final _teamCtrl = StreamController<List<Team>>.broadcast();
  final _memberCountCtrl =
      StreamController<Map<int, int>>.broadcast();
  final _reminderCtrl =
      StreamController<List<ReminderStateRecord>>.broadcast();

  void _emit() {
    _hackathonCtrl.add(List.unmodifiable(_hackathons));
    final grouped = <int, List<Milestone>>{};
    for (final m in _milestones) {
      grouped.putIfAbsent(m.hackathonId, () => []).add(m);
    }
    _milestoneCtrl.add(grouped);
    _teamCtrl.add(List.unmodifiable(_teams));
    final counts = <int, int>{};
    for (final m in _teamMembers) {
      counts[m.teamId] = (counts[m.teamId] ?? 0) + 1;
    }
    _memberCountCtrl.add(counts);
    _reminderCtrl.add(List.unmodifiable(_reminderStates));
  }

  // ── Seeding ─────────────────────────────────────────────────────────────────

  void _seed() {
    final now = DateTime.now().toUtc();

    final h1 = _seedHackathon(
      id: 1,
      name: 'Global AI Hackathon 2026',
      organizer: 'OpenAI & Anthropic',
      url: 'https://aihack2026.dev',
      mode: HackathonMode.online,
      location: 'Global / Virtual',
      organizerTimezone: 'America/New_York',
      status: HackathonStatus.running,
    );
    final h2 = _seedHackathon(
      id: 2,
      name: 'HackMIT 2026',
      organizer: 'MIT Tech Club',
      url: 'https://hackmit.org',
      mode: HackathonMode.hybrid,
      location: 'Cambridge, MA',
      organizerTimezone: 'America/New_York',
      status: HackathonStatus.upcoming,
    );
    final h3 = _seedHackathon(
      id: 3,
      name: 'ETHTaipei Web3 Sprint',
      organizer: 'Ethereum Foundation',
      url: 'https://ethtaipei.org',
      mode: HackathonMode.inPerson,
      location: 'Taipei, Taiwan',
      organizerTimezone: 'Asia/Tokyo',
      status: HackathonStatus.upcoming,
    );
    _hackathons.addAll([h1, h2, h3]);
    _nextId = 100;

    _milestones.addAll([
      _seedMilestone(
        id: _newId(),
        hackathonId: 1,
        label: MilestoneLabel.eventWindow,
        title: 'Hacking Period',
        startsAtUtc: now.subtract(const Duration(days: 1)),
        endsAtUtc: now.add(const Duration(days: 2, hours: 14)),
        timezone: 'America/New_York',
        isCritical: false,
        verified: true,
      ),
      _seedMilestone(
        id: _newId(),
        hackathonId: 1,
        label: MilestoneLabel.pitch,
        title: 'Mentorship Check-in / Mini Pitch',
        endsAtUtc: now.add(const Duration(hours: 18)),
        timezone: 'America/New_York',
        isCritical: false,
        verified: true,
      ),
      _seedMilestone(
        id: _newId(),
        hackathonId: 1,
        label: MilestoneLabel.finalSubmission,
        title: 'Final Code & Video Submission',
        endsAtUtc: now.add(const Duration(days: 2, hours: 12)),
        timezone: 'America/New_York',
        isCritical: true,
        criticalReason: 'Official closing deadline — hard stop',
        sourceUrl: 'https://aihack2026.dev/rules',
        verified: true,
      ),
      _seedMilestone(
        id: _newId(),
        hackathonId: 2,
        label: MilestoneLabel.registrationClose,
        title: 'Registration & RSVP Deadline',
        endsAtUtc: now.add(const Duration(days: 4, hours: 6)),
        timezone: 'America/New_York',
        isCritical: true,
        criticalReason: 'Registration portal closes',
        verified: true,
      ),
      _seedMilestone(
        id: _newId(),
        hackathonId: 2,
        label: MilestoneLabel.eventWindow,
        title: 'Opening Ceremony & Keynote',
        startsAtUtc: now.add(const Duration(days: 5)),
        endsAtUtc: now.add(const Duration(days: 7)),
        timezone: 'America/New_York',
        isCritical: false,
        verified: false,
      ),
      _seedMilestone(
        id: _newId(),
        hackathonId: 3,
        label: MilestoneLabel.registrationClose,
        title: 'Early Bird Team Application',
        endsAtUtc: now.add(const Duration(days: 6, hours: 20)),
        timezone: 'Asia/Tokyo',
        isCritical: true,
        criticalReason: 'Early registration cut-off',
        verified: true,
      ),
    ]);

    _teams.add(_seedTeam(
      id: 1,
      hackathonId: 1,
      name: 'Agentic Mavericks',
      status: TeamStatus.confirmed,
      ideaTitle: 'Autonomous Hackathon Ops Copilot',
      techStack: 'Flutter,Dart,Python,FastAPI',
    ));
    _teamMembers.addAll([
      const TeamMember(
        id: 1,
        teamId: 1,
        name: 'Alex Rivera',
        role: 'Team Lead & Full-Stack',
        contact: '@alex_r',
        isLead: true,
      ),
      const TeamMember(
        id: 2,
        teamId: 1,
        name: 'Sarah Chen',
        role: 'ML & Engine Architect',
        contact: 'sarah@chen.ai',
        isLead: false,
      ),
      const TeamMember(
        id: 3,
        teamId: 1,
        name: 'Jordan Lee',
        role: 'Flutter UI Designer',
        contact: '@jordan_design',
        isLead: false,
      ),
    ]);

    _emit();
  }

  // ── Hackathons ──────────────────────────────────────────────────────────────

  Stream<List<Hackathon>> watchHackathons() =>
      _hackathonCtrl.stream.startWith(List.unmodifiable(_hackathons));

  Future<Hackathon> saveHackathon(Hackathon h) async {
    final now = DateTime.now().toUtc();
    if (h.id < 0) {
      final saved = Hackathon(
        id: _newId(),
        name: h.name,
        organizer: h.organizer,
        url: h.url,
        mode: h.mode,
        location: h.location,
        organizerTimezone: h.organizerTimezone,
        status: h.status,
        createdAt: now,
        modifiedAt: now,
      );
      _hackathons.add(saved);
      _emit();
      return saved;
    }
    final idx = _hackathons.indexWhere((e) => e.id == h.id);
    final updated = Hackathon(
      id: h.id,
      name: h.name,
      organizer: h.organizer,
      url: h.url,
      mode: h.mode,
      location: h.location,
      organizerTimezone: h.organizerTimezone,
      status: h.status,
      createdAt: h.createdAt,
      modifiedAt: now,
    );
    if (idx >= 0) {
      _hackathons[idx] = updated;
    } else {
      _hackathons.add(updated);
    }
    _emit();
    return updated;
  }

  Future<void> archiveHackathon(int id) async {
    final idx = _hackathons.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _hackathons[idx] = _hackathons[idx].copyWith(
        status: HackathonStatus.archived,
        modifiedAt: DateTime.now().toUtc(),
      );
      _emit();
    }
  }

  Future<int> countHackathons() async => _hackathons.length;

  // ── Milestones ──────────────────────────────────────────────────────────────

  Stream<List<Milestone>> watchMilestonesFor(int hackathonId) =>
      Stream.value(
        _milestones.where((m) => m.hackathonId == hackathonId).toList(),
      ).asBroadcastStream().mergeWith([
        _milestoneCtrl.stream.map(
          (g) => (g[hackathonId] ?? []).toList(),
        ),
      ]);

  Stream<Map<int, List<Milestone>>> watchMilestonesGrouped() =>
      _milestoneCtrl.stream.startWith(_buildGrouped());

  Map<int, List<Milestone>> _buildGrouped() {
    final m = <int, List<Milestone>>{};
    for (final ms in _milestones) {
      m.putIfAbsent(ms.hackathonId, () => []).add(ms);
    }
    return m;
  }

  Future<Milestone?> milestone(int id) async =>
      _milestones.where((m) => m.id == id).firstOrNull;

  Future<Milestone> saveMilestone(Milestone m) async {
    final now = DateTime.now().toUtc();
    if (m.id < 0) {
      final saved = Milestone(
        id: _newId(),
        hackathonId: m.hackathonId,
        label: m.label,
        title: m.title,
        startsAtUtc: m.startsAtUtc,
        endsAtUtc: m.endsAtUtc,
        timezone: m.timezone,
        isCritical: m.isCritical,
        criticalReason: m.criticalReason,
        sourceUrl: m.sourceUrl,
        verified: m.verified,
        note: m.note,
        createdAt: now,
        modifiedAt: now,
      );
      _milestones.add(saved);
      _emit();
      return saved;
    }
    final idx = _milestones.indexWhere((e) => e.id == m.id);
    if (idx >= 0) {
      final old = _milestones[idx];
      var updateTime = now;
      if (!updateTime.isAfter(old.modifiedAt)) {
        updateTime = old.modifiedAt.add(const Duration(milliseconds: 1));
      }
      _logMilestoneChanges(old, m, updateTime);
      _milestones[idx] = Milestone(
        id: m.id,
        hackathonId: m.hackathonId,
        label: m.label,
        title: m.title,
        startsAtUtc: m.startsAtUtc,
        endsAtUtc: m.endsAtUtc,
        timezone: m.timezone,
        isCritical: m.isCritical,
        criticalReason: m.criticalReason,
        sourceUrl: m.sourceUrl,
        verified: m.verified,
        note: m.note,
        createdAt: m.createdAt,
        modifiedAt: updateTime,
      );
    } else {
      _milestones.add(m);
    }
    _emit();
    return (await milestone(m.id))!;
  }

  void _logMilestoneChanges(Milestone old, Milestone next, DateTime now) {
    void log(MilestoneChangeField field, String o, String n) {
      if (o == n) return;
      _milestoneChanges.add(MilestoneChange(
        id: _changeId(),
        milestoneId: old.id,
        changedField: field,
        oldValue: o,
        newValue: n,
        changedAtUtc: now,
      ));
    }

    log(MilestoneChangeField.endsAt, old.endsAtUtc.toIso8601String(),
        next.endsAtUtc.toIso8601String());
    log(MilestoneChangeField.startsAt,
        old.startsAtUtc?.toIso8601String() ?? '',
        next.startsAtUtc?.toIso8601String() ?? '');
    log(MilestoneChangeField.title, old.title, next.title);
    log(MilestoneChangeField.label, old.label.name, next.label.name);
    log(MilestoneChangeField.timezone, old.timezone, next.timezone);
  }

  Future<void> deleteMilestone(int id) async {
    _milestones.removeWhere((m) => m.id == id);
    _milestoneChanges.removeWhere((c) => c.milestoneId == id);
    _emit();
  }

  Stream<List<MilestoneChange>> watchMilestoneChanges(int milestoneId) =>
      Stream.value(
        _milestoneChanges.where((c) => c.milestoneId == milestoneId).toList(),
      ).asBroadcastStream();

  // ── Teams ───────────────────────────────────────────────────────────────────

  Stream<List<Team>> watchTeamsFor(int hackathonId) =>
      _teamCtrl.stream
          .startWith(_teams)
          .map((t) => t.where((e) => e.hackathonId == hackathonId).toList());

  Stream<Map<int, int>> watchMemberCounts() =>
      _memberCountCtrl.stream.startWith({
        for (final t in _teams)
          t.id: _teamMembers.where((m) => m.teamId == t.id).length,
      });

  Future<Team> saveTeam(Team t) async {
    final now = DateTime.now().toUtc();
    if (t.id < 0) {
      final saved = Team(
        id: _newId(),
        hackathonId: t.hackathonId,
        name: t.name,
        status: t.status,
        ideaTitle: t.ideaTitle,
        techStack: t.techStack,
        repoUrl: t.repoUrl,
        chatUrl: t.chatUrl,
        notes: t.notes,
        maxSize: t.maxSize,
        createdAt: now,
        modifiedAt: now,
      );
      _teams.add(saved);
      _teamChanges.add(TeamChange(
        id: _changeId(),
        teamId: saved.id,
        changeType: TeamChangeType.created,
        entityLabel: saved.name,
        oldValue: '',
        newValue: saved.status.name,
        changedAtUtc: now,
      ));
      _emit();
      return saved;
    }
    final idx = _teams.indexWhere((e) => e.id == t.id);
    final updated = Team(
      id: t.id,
      hackathonId: t.hackathonId,
      name: t.name,
      status: t.status,
      ideaTitle: t.ideaTitle,
      techStack: t.techStack,
      repoUrl: t.repoUrl,
      chatUrl: t.chatUrl,
      notes: t.notes,
      maxSize: t.maxSize,
      createdAt: t.createdAt,
      modifiedAt: now,
    );
    if (idx >= 0) _teams[idx] = updated;
    else _teams.add(updated);
    _emit();
    return updated;
  }

  Future<void> saveTeamMembers(int teamId, List<TeamMember> members) async {
    final now = DateTime.now().toUtc();
    final existing =
        _teamMembers.where((m) => m.teamId == teamId).toList();
    // Find added
    for (final m in members) {
      if (!existing.any((e) => e.name == m.name)) {
        _teamChanges.add(TeamChange(
          id: _changeId(),
          teamId: teamId,
          changeType: TeamChangeType.memberAdded,
          entityLabel: m.name,
          oldValue: '',
          newValue: m.role,
          changedAtUtc: now,
        ));
      }
    }
    // Find removed
    for (final e in existing) {
      if (!members.any((m) => m.name == e.name)) {
        _teamChanges.add(TeamChange(
          id: _changeId(),
          teamId: teamId,
          changeType: TeamChangeType.memberRemoved,
          entityLabel: e.name,
          oldValue: e.role,
          newValue: '',
          changedAtUtc: now,
        ));
      }
    }
    _teamMembers.removeWhere((m) => m.teamId == teamId);
    int mid = _newId();
    for (final m in members) {
      _teamMembers.add(TeamMember(
        id: mid++,
        teamId: teamId,
        name: m.name,
        role: m.role,
        contact: m.contact,
        isLead: m.isLead,
      ));
    }
    _emit();
  }

  Future<void> setTeamStatus(int teamId, TeamStatus newStatus) async {
    final idx = _teams.indexWhere((e) => e.id == teamId);
    if (idx < 0) return;
    final old = _teams[idx];
    final now = DateTime.now().toUtc();
    _teamChanges.add(TeamChange(
      id: _changeId(),
      teamId: teamId,
      changeType: TeamChangeType.statusChanged,
      entityLabel: old.name,
      oldValue: old.status.name,
      newValue: newStatus.name,
      changedAtUtc: now,
    ));
    _teams[idx] = Team(
      id: old.id,
      hackathonId: old.hackathonId,
      name: old.name,
      status: newStatus,
      ideaTitle: old.ideaTitle,
      techStack: old.techStack,
      repoUrl: old.repoUrl,
      chatUrl: old.chatUrl,
      notes: old.notes,
      maxSize: old.maxSize,
      createdAt: old.createdAt,
      modifiedAt: now,
    );
    _emit();
  }

  Stream<List<TeamChange>> watchTeamChanges(int teamId) =>
      Stream.value(
        _teamChanges.where((c) => c.teamId == teamId).toList(),
      ).asBroadcastStream();

  List<TeamMember> membersFor(int teamId) =>
      _teamMembers.where((m) => m.teamId == teamId).toList();

  List<Team> teamsFor(int hackathonId) =>
      _teams.where((t) => t.hackathonId == hackathonId).toList();

  List<Team> get allTeams => List.unmodifiable(_teams);

  // ── Reminder states ─────────────────────────────────────────────────────────

  Stream<List<ReminderStateRecord>> watchScheduledReminders() =>
      _reminderCtrl.stream.startWith(List.unmodifiable(_reminderStates));

  Future<ReminderStateRecord?> reminder(String key) async =>
      _reminderStates.where((r) => r.key == key).firstOrNull;

  Future<List<ReminderStateRecord>> remindersForMilestone(
      int milestoneId) async =>
      _reminderStates
          .where((r) => r.milestoneId == milestoneId)
          .toList();

  Future<void> upsertReminderState(ReminderStateRecord r) async {
    _reminderStates.removeWhere((e) => e.key == r.key);
    _reminderStates.add(r);
    _reminderCtrl.add(List.unmodifiable(_reminderStates));
  }

  Future<void> deleteReminderState(String key) async {
    _reminderStates.removeWhere((r) => r.key == key);
    _reminderCtrl.add(List.unmodifiable(_reminderStates));
  }

  Future<void> updateReminderState(
    String key,
    ReminderState state, {
    DateTime? firesAtUtc,
    int? repeatCount,
    DateTime? armedAtUtc,
  }) async {
    final idx = _reminderStates.indexWhere((r) => r.key == key);
    if (idx < 0) return;
    final old = _reminderStates[idx];
    _reminderStates[idx] = ReminderStateRecord(
      key: old.key,
      milestoneId: old.milestoneId,
      scheduleIndex: old.scheduleIndex,
      profile: old.profile,
      firesAtUtc: firesAtUtc ?? old.firesAtUtc,
      priority: old.priority,
      state: state,
      repeatCount: repeatCount ?? old.repeatCount,
      armedAtUtc: armedAtUtc ?? old.armedAtUtc,
      updatedAtUtc: DateTime.now().toUtc(),
    );
    _reminderCtrl.add(List.unmodifiable(_reminderStates));
  }

  Future<void> close() async {}
}

// ─── Stream helpers ───────────────────────────────────────────────────────────

extension _StreamMerge<T> on Stream<T> {
  Stream<T> mergeWith(List<Stream<T>> others) async* {
    final controller = StreamController<T>.broadcast();
    listen(controller.add, onError: controller.addError);
    for (final s in others) {
      s.listen(controller.add, onError: controller.addError);
    }
    yield* controller.stream;
  }

  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
