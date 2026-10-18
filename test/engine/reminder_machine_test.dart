import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/reminder_machine.dart';

void main() {
  group('terminal transitions', () {
    test('fired + done reaches terminal done', () {
      expect(ReminderMachine.next(ReminderState.fired, ReminderAction.done), ReminderState.done);
      expect(ReminderMachine.isTerminal(ReminderState.done), isTrue);
    });

    test('fired + skip reaches terminal skipped', () {
      expect(ReminderMachine.next(ReminderState.fired, ReminderAction.skip),
          ReminderState.skipped);
      expect(ReminderMachine.isTerminal(ReminderState.skipped), isTrue);
    });

    test('skip from scheduled also terminates', () {
      expect(ReminderMachine.next(ReminderState.scheduled, ReminderAction.skip),
          ReminderState.skipped);
    });

    test('terminal states ignore further actions', () {
      expect(ReminderMachine.next(ReminderState.done, ReminderAction.done), ReminderState.done);
      expect(
        ReminderMachine.next(ReminderState.skipped, ReminderAction.snoozeTomorrow),
        ReminderState.skipped,
      );
      expect(ReminderMachine.next(ReminderState.done, ReminderAction.elapsed),
          ReminderState.done);
    });
  });

  group('snooze', () {
    test('snooze moves to snoozed and then back to fired on elapse', () {
      final snoozed = ReminderMachine.next(ReminderState.fired, ReminderAction.snoozeOneHour);
      expect(snoozed, ReminderState.snoozed);
      expect(ReminderMachine.next(ReminderState.snoozed, ReminderAction.elapsed),
          ReminderState.fired);
    });

    test('snooze tomorrow behaves the same way in the state machine', () {
      expect(ReminderMachine.next(ReminderState.fired, ReminderAction.snoozeTomorrow),
          ReminderState.snoozed);
    });

    test('snoozed from scheduled also moves to snoozed', () {
      expect(ReminderMachine.next(ReminderState.scheduled, ReminderAction.snoozeOneHour),
          ReminderState.snoozed);
    });
  });

  group('repeat cap', () {
    test('critical repeats up to 3 times then gives up', () {
      expect(ReminderMachine.shouldRepeat(Priority.critical, 0), isTrue);
      expect(ReminderMachine.shouldRepeat(Priority.critical, 1), isTrue);
      expect(ReminderMachine.shouldRepeat(Priority.critical, 2), isTrue);
      expect(ReminderMachine.shouldRepeat(Priority.critical, 3), isFalse);
      expect(ReminderMachine.shouldRepeat(Priority.critical, 4), isFalse);
      expect(ReminderMachine.nextRepeatCount(0), 1);
      expect(ReminderMachine.nextRepeatCount(2), 3);
      expect(ReminderMachine.maxRepeats, 3);
    });

    test('non-critical does not repeat', () {
      expect(ReminderMachine.shouldRepeat(Priority.high, 0), isFalse);
      expect(ReminderMachine.shouldRepeat(Priority.normal, 0), isFalse);
    });

    test('elapsed on a fired reminder arms a repeat', () {
      expect(ReminderMachine.next(ReminderState.fired, ReminderAction.elapsed),
          ReminderState.repeatArmed);
    });

    test('elapsed on a repeatArmed reminder re-fires', () {
      expect(ReminderMachine.next(ReminderState.repeatArmed, ReminderAction.elapsed),
          ReminderState.fired);
    });

    test('skip from repeatArmed terminates', () {
      expect(ReminderMachine.next(ReminderState.repeatArmed, ReminderAction.skip),
          ReminderState.skipped);
    });

    test('done from repeatArmed terminates', () {
      expect(ReminderMachine.next(ReminderState.repeatArmed, ReminderAction.done),
          ReminderState.done);
    });
  });

  group('noop actions', () {
    test('elapsed on scheduled is a no-op', () {
      expect(ReminderMachine.next(ReminderState.scheduled, ReminderAction.elapsed),
          ReminderState.scheduled);
      expect(ReminderMachine.applies(ReminderState.scheduled, ReminderAction.elapsed), isFalse);
    });

    test('applies reports whether an action changed state', () {
      expect(ReminderMachine.applies(ReminderState.fired, ReminderAction.done), isTrue);
      expect(ReminderMachine.applies(ReminderState.done, ReminderAction.done), isFalse);
    });
  });
}
