// Pure Dart. Never import Flutter, drift, or any plugin.

enum HackathonMode { online, inPerson, hybrid }

enum HackathonStatus { upcoming, running, done, archived }

enum TeamStatus {
  looking,
  applied,
  invited,
  confirmed,
  registered,
  left,
  disbanded,
  solo,
}

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

extension TeamStatusExt on TeamStatus {
  bool get isActive =>
      this == TeamStatus.applied ||
      this == TeamStatus.invited ||
      this == TeamStatus.confirmed ||
      this == TeamStatus.registered;
}

extension HackathonModeExt on HackathonMode {
  String get label => switch (this) {
        HackathonMode.online => 'Online',
        HackathonMode.inPerson => 'In person',
        HackathonMode.hybrid => 'Hybrid',
      };
}

extension HackathonStatusExt on HackathonStatus {
  String get label => switch (this) {
        HackathonStatus.upcoming => 'Upcoming',
        HackathonStatus.running => 'Running',
        HackathonStatus.done => 'Done',
        HackathonStatus.archived => 'Archived',
      };
}

extension TeamStatusExt2 on TeamStatus {
  String get label => switch (this) {
        TeamStatus.looking => 'Looking',
        TeamStatus.applied => 'Applied',
        TeamStatus.invited => 'Invited',
        TeamStatus.confirmed => 'Confirmed',
        TeamStatus.registered => 'Registered',
        TeamStatus.left => 'Left',
        TeamStatus.disbanded => 'Disbanded',
        TeamStatus.solo => 'Solo',
      };
}

class _NullSentinel {
  const _NullSentinel();
  @override
  String toString() => '<null sentinel>';
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

  MilestoneKind get kind =>
      startsAtUtc == null ? MilestoneKind.point : MilestoneKind.window;

  /// Sentinel used to detect "explicitly passed null" in [copyWith].
  static const _nullSentinel = _NullSentinel();

  Milestone copyWith({
    MilestoneLabel? label,
    String? title,
    Object? startsAtUtc = _nullSentinel,
    DateTime? endsAtUtc,
    String? timezone,
    bool? isCritical,
    String? criticalReason,
    String? sourceUrl,
    bool? verified,
    String? note,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    // Pass `startsAtUtc: null` to clear the field; omit it to keep the old value.
    final effectiveStart = startsAtUtc == _nullSentinel
        ? this.startsAtUtc
        : startsAtUtc as DateTime?;
    return Milestone(
      id: id,
      hackathonId: hackathonId,
      label: label ?? this.label,
      title: title ?? this.title,
      startsAtUtc: effectiveStart,
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
}

class Team {
  const Team({
    required this.id,
    required this.hackathonId,
    required this.name,
    required this.status,
    required this.ideaTitle,
    required this.techStack,
    required this.repoLink,
    required this.chatLink,
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
  final List<String> techStack;
  final String repoLink;
  final String chatLink;
  final String notes;
  final int? maxSize;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Team copyWith({
    String? name,
    TeamStatus? status,
    String? ideaTitle,
    List<String>? techStack,
    String? repoLink,
    String? chatLink,
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
        repoLink: repoLink ?? this.repoLink,
        chatLink: chatLink ?? this.chatLink,
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

/// FR-12: reminder profiles scale the PRD cadence table; they do not redefine it.
class ReminderProfile {
  const ReminderProfile._(
    this.id,
    this.label,
    this.enabledCritical,
    this.enabledHigh,
    this.enabledNormal,
  );

  final String id;
  final String label;
  final List<Duration> enabledCritical;
  final List<Duration> enabledHigh;
  final List<Duration> enabledNormal;

  static const standard = ReminderProfile._(
    'standard',
    'Standard',
    [
      Duration(days: 7),
      Duration(days: 3),
      Duration(days: 1),
      Duration(hours: 6),
      Duration(hours: 1),
      Duration(minutes: 15),
    ],
    [Duration(days: 3), Duration(days: 1), Duration(hours: 1)],
    [Duration(days: 1), Duration(minutes: 30)],
  );

  static const intense = ReminderProfile._(
    'intense',
    'Intense',
    [
      Duration(days: 7),
      Duration(days: 3),
      Duration(days: 1),
      Duration(hours: 6),
      Duration(hours: 4),
      Duration(hours: 1),
      Duration(minutes: 15),
    ],
    [
      Duration(days: 3),
      Duration(days: 1),
      Duration(hours: 4),
      Duration(hours: 1),
    ],
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

  static ReminderProfile byId(String id) =>
      values.firstWhere((p) => p.id == id, orElse: () => standard);

  List<Duration> offsetsFor(Priority priority) => switch (priority) {
        Priority.critical => enabledCritical,
        Priority.high => enabledHigh,
        Priority.normal => enabledNormal,
      };

  String get description => switch (this) {
        ReminderProfile.standard =>
          'Every deadline, every cadence the PRD specifies.',
        ReminderProfile.intense =>
          'Adds a 4 hour lead time for Critical and High.',
        ReminderProfile.minimal =>
          'Only 1 day and 1 hour before, for Critical and High.',
        _ => 'Custom reminder profile.',
      };
}
