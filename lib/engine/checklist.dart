import 'models.dart';

/// FR-22: submission-day checklist, generated 24 hours before final submission.
///
/// Generated on demand; not persisted. The checklist is deterministic given
/// the team and hackathon, so the lead can refresh it without losing state.
class SubmissionChecklist {
  const SubmissionChecklist(this.items, this.generatedAt, this.dueAt);

  final List<ChecklistItem> items;
  final DateTime generatedAt;
  final DateTime dueAt;

  bool get isComplete => items.every((i) => i.done);
  int get doneCount => items.where((i) => i.done).length;
}

class ChecklistItem {
  const ChecklistItem(this.id, this.label, {this.detail});

  final int id;
  final String label;
  final String? detail;
  bool get done => false;
}

class ChecklistGenerator {
  ChecklistGenerator._();

  /// Whether a checklist should be offered right now. True only inside the
  /// [generateLeadTime] window before final submission.
  static bool due(Milestone submission, DateTime now) {
    final lead = submission.endsAtUtc.difference(now.toUtc());
    return lead.isNegative == false &&
        lead <= const Duration(hours: 24) &&
        lead > Duration.zero;
  }

  static const generateLeadTime = Duration(hours: 24);

  static SubmissionChecklist generate(Milestone submission, Team team, DateTime now) {
    final dueAt = submission.endsAtUtc;
    final items = [
      ChecklistItem(1, 'Read the final rules and format requirements'),
      ChecklistItem(2, 'Confirm the repo is public or has judge access',
          detail: team.repoLink.isEmpty ? null : team.repoLink),
      ChecklistItem(3, 'Verify every README link resolves',
          detail: team.repoLink.isEmpty ? null : team.repoLink),
      ChecklistItem(4, 'Push any last commits before the cutoff'),
      ChecklistItem(5, 'Attach the video or demo link if the hackathon asks for one'),
      ChecklistItem(6, 'Run the app end-to-end one last time'),
      ChecklistItem(7, 'Synchronise the team — confirm the lead has the same plan'),
      ChecklistItem(8, 'Submit before the deadline'),
      ChecklistItem(9, 'Attach the confirmation link to the hackathon record'),
    ];
    return SubmissionChecklist(items, now, dueAt);
  }
}
