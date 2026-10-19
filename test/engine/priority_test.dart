import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/priority.dart';

void main() {
  group('label classification', () {
    test('registration close is critical with an explanatory reason', () {
      final (p, reason) = PriorityClassifier.classify(MilestoneLabel.registrationClose, '');
      expect(p, Priority.critical);
      expect(reason, isNotNull);
    });

    test('final submission is critical', () {
      final (p, reason) = PriorityClassifier.classify(MilestoneLabel.finalSubmission, '');
      expect(p, Priority.critical);
      expect(reason, isNotNull);
    });

    test('pitch and demo are high', () {
      expect(PriorityClassifier.classify(MilestoneLabel.pitch, '').$1, Priority.high);
      expect(PriorityClassifier.classify(MilestoneLabel.demo, '').$1, Priority.high);
      expect(PriorityClassifier.classify(MilestoneLabel.interviews, '').$1, Priority.high);
    });

    test('other labels fall through to normal', () {
      expect(PriorityClassifier.classify(MilestoneLabel.other, '').$1, Priority.normal);
      expect(PriorityClassifier.classify(MilestoneLabel.eventWindow, '').$1, Priority.normal);
      expect(PriorityClassifier.classify(MilestoneLabel.registrationOpen, '').$1,
          Priority.normal);
      expect(PriorityClassifier.classify(MilestoneLabel.preparing, '').$1, Priority.normal);
    });

    test('non-critical milestones carry no reason', () {
      expect(PriorityClassifier.classify(MilestoneLabel.demo, '').$2, isNull);
      expect(PriorityClassifier.classify(MilestoneLabel.other, '').$2, isNull);
    });
  });

  group('title fallback', () {
    test('title matching catches critical phrasing when the label is generic', () {
      final (p, reason) =
          PriorityClassifier.classify(MilestoneLabel.other, 'Registration closes Friday');
      expect(p, Priority.critical);
      expect(reason, isNotNull);
    });

    test('final submission phrasing is caught case-insensitively', () {
      final (p, _) =
          PriorityClassifier.classify(MilestoneLabel.other, 'FINAL SUBMISSION deadline');
      expect(p, Priority.critical);
    });

    test('submission deadline phrasing is caught', () {
      expect(
        PriorityClassifier.classify(MilestoneLabel.other, 'Submission Deadline is Sunday').$1,
        Priority.critical,
      );
    });

    test('a benign title with no critical phrasing stays normal', () {
      expect(PriorityClassifier.classify(MilestoneLabel.other, 'Team formation').$1,
          Priority.normal);
      expect(PriorityClassifier.classify(MilestoneLabel.other, 'Kickoff call').$1,
          Priority.normal);
    });

    test('the label classification wins over a contradicting title', () {
      // A registration-close milestone whose title does not mention the phrase
      // is still Critical because the label says so.
      final (p, reason) =
          PriorityClassifier.classify(MilestoneLabel.registrationClose, 'Whatever');
      expect(p, Priority.critical);
      expect(reason!, contains('registration'));
    });
  });

  group('isCriticalLabel', () {
    test('only registration close and final submission qualify', () {
      expect(PriorityClassifier.isCriticalLabel(MilestoneLabel.registrationClose), isTrue);
      expect(PriorityClassifier.isCriticalLabel(MilestoneLabel.finalSubmission), isTrue);
      expect(PriorityClassifier.isCriticalLabel(MilestoneLabel.registrationOpen), isFalse);
      expect(PriorityClassifier.isCriticalLabel(MilestoneLabel.demo), isFalse);
      expect(PriorityClassifier.isCriticalLabel(MilestoneLabel.other), isFalse);
    });
  });
}
