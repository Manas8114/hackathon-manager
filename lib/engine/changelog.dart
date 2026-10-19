
/// FR-17: timestamped change log for every membership or status change.
///
/// Append-only by construction: the only operation is [append]. There is no
/// edit or delete, so the log is the audit trail it claims to be. Each entry
/// carries the before and after of the field that changed.
class ChangeLog {
  const ChangeLog(this.entries);

  final List<ChangeEntry> entries;

  ChangeLog append(ChangeEntry entry) => ChangeLog([
        ...entries,
        entry,
      ]);

  List<ChangeEntry> forHackathon(int hackathonId) =>
      entries.where((e) => e.hackathonId == hackathonId).toList();

  List<ChangeEntry> forTeam(int teamId) =>
      entries.where((e) => e.teamId == teamId).toList();

  List<ChangeEntry> get reversed =>
      List.of(entries.reversed.cast<ChangeEntry>());
}

class ChangeEntry {
  const ChangeEntry({
    required this.at,
    required this.hackathonId,
    required this.teamId,
    required this.field,
    required this.from,
    required this.to,
    this.actor = 'user',
  });

  final DateTime at;
  final int hackathonId;
  final int teamId;
  final ChangeField field;
  final String from;
  final String to;
  final String actor;
}

enum ChangeField { status, memberAdded, memberRemoved, memberRole, memberLead }
