import 'models.dart';

/// FR-9: quiet hours silence Normal and High reminders. Critical always fires.
///
/// Suppression is decided at show time by the scheduler, never by skipping the
/// alarm. The alarm record stays the source of truth, so a suppressed reminder
/// still shows up as pending and is re-queued rather than lost.
class QuietHours {
  const QuietHours({
    required this.startMinute,
    required this.endMinute,
    required this.enabled,
  });

  /// Minutes after midnight, local time. 22 * 60 = 22:00.
  final int startMinute;
  final int endMinute;
  final bool enabled;

  static const none = QuietHours(startMinute: 0, endMinute: 0, enabled: false);

  bool get wrapsMidnight => startMinute > endMinute;
}

enum SuppressDecision { fire, suppress }

class QuietDecision {
  const QuietDecision(this.decision, this.effectiveAtUtc);

  final SuppressDecision decision;

  /// When the reminder will actually be shown. Equal to the scheduled time when
  /// the decision is [SuppressDecision.fire].
  final DateTime effectiveAtUtc;
}

class QuietHoursGate {
  QuietHoursGate._();

  /// [localMinuteOfDay] is minutes after midnight in the user's local zone.
  static bool contains(QuietHours h, int localMinuteOfDay) {
    if (!h.enabled) return false;
    if (!h.wrapsMidnight) {
      return localMinuteOfDay >= h.startMinute && localMinuteOfDay < h.endMinute;
    }
    return localMinuteOfDay >= h.startMinute || localMinuteOfDay < h.endMinute;
  }

  static int _minuteOfDay(DateTime local) => local.hour * 60 + local.minute;

  static QuietDecision gate(DateTime firesAtUtc, Priority priority, QuietHours hours,
      DateTime Function(DateTime utc) toLocal) {
    if (priority == Priority.critical) {
      return QuietDecision(SuppressDecision.fire, firesAtUtc.toUtc());
    }
    if (!hours.enabled) {
      return QuietDecision(SuppressDecision.fire, firesAtUtc.toUtc());
    }
    final local = toLocal(firesAtUtc.toUtc());
    if (!contains(hours, _minuteOfDay(local))) {
      return QuietDecision(SuppressDecision.fire, firesAtUtc.toUtc());
    }
    // Advance minute by minute until the first minute outside the window.
    // Bounded at 24 hours so a malformed window cannot loop forever.
    var candidate = firesAtUtc.toUtc();
    for (var i = 0; i < 1441; i++) {
      final next = candidate.add(const Duration(minutes: 1));
      final nLocal = toLocal(next);
      if (!contains(hours, _minuteOfDay(nLocal))) {
        return QuietDecision(SuppressDecision.suppress, next);
      }
      candidate = next;
    }
    return QuietDecision(SuppressDecision.fire, candidate);
  }
}
