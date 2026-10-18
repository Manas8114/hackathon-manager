import 'models.dart';

/// FR-3: automatically flag registration close and final submission as Critical.
///
/// The label match wins. The title fallback catches organizer phrasing when a
/// milestone is filed under a generic label. The user can override either way;
/// the override is final and is not re-derived.
class PriorityClassifier {
  PriorityClassifier._();

  static const _criticalTitles = [
    'registration close',
    'registration ends',
    'registration deadline',
    'final submission',
    'submission deadline',
    'submission due',
  ];

  static bool isCriticalLabel(MilestoneLabel label) =>
      label == MilestoneLabel.registrationClose ||
      label == MilestoneLabel.finalSubmission;

  /// Returns (priority, reason). `reason` is null for non-critical milestones,
  /// so the UI can explain why something is Critical when it is.
  static (Priority, String?) classify(MilestoneLabel label, String title) {
    if (isCriticalLabel(label)) {
      return (
        Priority.critical,
        'Flagged Critical: this is a ${label.displayName.toLowerCase()} milestone.'
      );
    }
    final low = title.toLowerCase();
    for (final phrase in _criticalTitles) {
      if (low.contains(phrase)) {
        return (Priority.critical, 'Flagged Critical: title mentions "$phrase".');
      }
    }
    return switch (label) {
      MilestoneLabel.pitch ||
      MilestoneLabel.demo ||
      MilestoneLabel.interviews =>
        (Priority.high, null),
      _ => (Priority.normal, null),
    };
  }
}
