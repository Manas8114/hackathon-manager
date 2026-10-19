import '../engine/models.dart';

enum MilestoneChangeField { endsAt, startsAt, title, label, timezone }

class MilestoneChange {
  const MilestoneChange({
    required this.id,
    required this.milestoneId,
    required this.changedField,
    required this.oldValue,
    required this.newValue,
    required this.changedAtUtc,
  });

  final int id;
  final int milestoneId;
  final MilestoneChangeField changedField;
  final String oldValue;
  final String newValue;
  final DateTime changedAtUtc;
}

enum TeamChangeType { created, memberAdded, memberRemoved, memberUpdated, statusChanged }

class TeamChange {
  const TeamChange({
    required this.id,
    required this.teamId,
    required this.changeType,
    required this.entityLabel,
    required this.oldValue,
    required this.newValue,
    required this.changedAtUtc,
  });

  final int id;
  final int teamId;
  final TeamChangeType changeType;
  final String entityLabel;
  final String oldValue;
  final String newValue;
  final DateTime changedAtUtc;
}

class ReminderStateRecord {
  const ReminderStateRecord({
    required this.key,
    required this.milestoneId,
    required this.scheduleIndex,
    required this.profile,
    required this.firesAtUtc,
    required this.priority,
    required this.state,
    required this.repeatCount,
    this.armedAtUtc,
    required this.updatedAtUtc,
  });

  final String key;
  final int milestoneId;
  final int scheduleIndex;
  final String profile;
  final DateTime firesAtUtc;
  final Priority priority;
  final ReminderState state;
  final int repeatCount;
  final DateTime? armedAtUtc;
  final DateTime updatedAtUtc;

  ReminderStateRecord copyWith({
    String? key,
    int? milestoneId,
    int? scheduleIndex,
    String? profile,
    DateTime? firesAtUtc,
    Priority? priority,
    ReminderState? state,
    int? repeatCount,
    DateTime? armedAtUtc,
    DateTime? updatedAtUtc,
  }) {
    return ReminderStateRecord(
      key: key ?? this.key,
      milestoneId: milestoneId ?? this.milestoneId,
      scheduleIndex: scheduleIndex ?? this.scheduleIndex,
      profile: profile ?? this.profile,
      firesAtUtc: firesAtUtc ?? this.firesAtUtc,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      repeatCount: repeatCount ?? this.repeatCount,
      armedAtUtc: armedAtUtc ?? this.armedAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}
