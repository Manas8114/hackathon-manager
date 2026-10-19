import 'models.dart';

/// FR-7 and FR-8: the reminder state machine.
///
///   Scheduled --show--> Fired --Done--> Done (terminal)
///                      Fired --Snooze--> Snoozed --elapsed--> Fired
///                      Fired --Skip--> Skipped (terminal)
///                      Fired --elapsed, Critical, count<3--> RepeatArmed
///                      RepeatArmed --elapsed--> Fired
///                      Fired --elapsed, Critical, count==3--> Skipped
///
/// Non-critical reminders do not repeat. Terminal states ignore further input.
/// The scheduler persists each transition BEFORE showing the notification, so a
/// crash mid-notification cannot double-fire or resurrect an acknowledged one.
class ReminderMachine {
  ReminderMachine._();

  static const maxRepeats = 3;

  static bool isTerminal(ReminderState s) =>
      s == ReminderState.done || s == ReminderState.skipped;

  static int nextRepeatCount(int current) => current + 1;

  static bool shouldRepeat(Priority p, int repeatCount) =>
      p == Priority.critical && repeatCount < maxRepeats;

  /// The next state after [action] applies to [current].
  static ReminderState next(ReminderState current, ReminderAction action) {
    if (isTerminal(current)) return current;
    return switch ((current, action)) {
      (_, ReminderAction.done) => ReminderState.done,
      (_, ReminderAction.skip) => ReminderState.skipped,
      (ReminderState.scheduled, ReminderAction.snoozeOneHour) ||
      (ReminderState.scheduled, ReminderAction.snoozeTomorrow) =>
        ReminderState.snoozed,
      (ReminderState.fired, ReminderAction.snoozeOneHour) ||
      (ReminderState.fired, ReminderAction.snoozeTomorrow) =>
        ReminderState.snoozed,
      (ReminderState.snoozed, ReminderAction.elapsed) => ReminderState.fired,
      (ReminderState.repeatArmed, ReminderAction.elapsed) => ReminderState.fired,
      (ReminderState.fired, ReminderAction.elapsed) => ReminderState.repeatArmed,
      _ => current,
    };
  }

  /// Whether [action] changes [current] at all. Terminal states never change.
  static bool applies(ReminderState current, ReminderAction action) =>
      next(current, action) != current;
}

enum ReminderAction { done, snoozeOneHour, snoozeTomorrow, skip, elapsed }
