import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/conflict_detector.dart';

Hackathon _h(int id, {HackathonStatus status = HackathonStatus.upcoming}) => Hackathon(
      id: id,
      name: 'H$id',
      organizer: 'O$id',
      url: '',
      mode: HackathonMode.online,
      location: '',
      organizerTimezone: 'UTC',
      status: status,
      createdAt: DateTime.utc(2026, 10, 1),
      modifiedAt: DateTime.utc(2026, 10, 1),
    );

Milestone _m(int id, int hid, {DateTime? start, DateTime? end}) => Milestone(
      id: id,
      hackathonId: hid,
      label: MilestoneLabel.eventWindow,
      title: 'Window',
      startsAtUtc: start,
      endsAtUtc: end ?? DateTime.utc(2026, 10, 24, 23, 59),
      timezone: 'UTC',
      isCritical: false,
      verified: false,
      createdAt: DateTime.utc(2026, 10, 1),
      modifiedAt: DateTime.utc(2026, 10, 1),
    );

Milestone _crit(int id, int hid, DateTime at) => Milestone(
      id: id,
      hackathonId: hid,
      label: MilestoneLabel.finalSubmission,
      title: 'Final submission',
      endsAtUtc: at,
      timezone: 'UTC',
      isCritical: true,
      criticalReason: 'Final submission',
      verified: false,
      createdAt: DateTime.utc(2026, 10, 1),
      modifiedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  group('overlapping windows', () {
    test('overlapping windows are flagged', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 27))],
        2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.overlappingWindows);
      expect(c, isNotEmpty);
      expect(c.first.severity, ConflictSeverity.danger);
    });

    test('non-overlapping windows are not flagged', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 22))],
        2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.overlappingWindows);
      expect(c, isEmpty);
    });

    test('windows that touch at exactly one instant do not overlap', () {
      final hs = [_h(1), _h(2)];
      final boundary = DateTime.utc(2026, 10, 24);
      final ms = {
        1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: boundary)],
        2: [_m(2, 2, start: boundary, end: DateTime.utc(2026, 10, 31))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.overlappingWindows);
      expect(c, isEmpty);
    });

    test('archived hackathons never conflict', () {
      final hs = [
        _h(1, status: HackathonStatus.upcoming),
        _h(2, status: HackathonStatus.archived),
      ];
      final ms = {
        1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 27))],
        2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.overlappingWindows);
      expect(c, isEmpty);
    });

    test('done hackathons never conflict', () {
      final hs = [
        _h(1, status: HackathonStatus.upcoming),
        _h(2, status: HackathonStatus.done),
      ];
      final ms = {
        1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 27))],
        2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.overlappingWindows);
      expect(c, isEmpty);
    });

    test('a hackathon with no milestones cannot produce a window conflict', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 27))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.overlappingWindows);
      expect(c, isEmpty);
    });
  });

  group('close critical deadlines', () {
    test('critical deadlines within 24 hours of each other are flagged', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_crit(1, 1, DateTime.utc(2026, 10, 24, 12, 0))],
        2: [_crit(2, 2, DateTime.utc(2026, 10, 24, 22, 0))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.closeCritical);
      expect(c, isNotEmpty);
    });

    test('critical deadlines exactly 24 hours apart are flagged (inclusive bound)', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_crit(1, 1, DateTime.utc(2026, 10, 24, 12, 0))],
        2: [_crit(2, 2, DateTime.utc(2026, 10, 25, 12, 0))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.closeCritical);
      expect(c, isNotEmpty);
    });

    test('critical deadlines 25 hours apart are not flagged', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_crit(1, 1, DateTime.utc(2026, 10, 24, 12, 0))],
        2: [_crit(2, 2, DateTime.utc(2026, 10, 25, 13, 0))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.closeCritical);
      expect(c, isEmpty);
    });

    test('two critical deadlines within one hackathon do not self-conflict', () {
      final hs = [_h(1)];
      final ms = {
        1: [
          _crit(1, 1, DateTime.utc(2026, 10, 24, 12, 0)),
          _crit(2, 1, DateTime.utc(2026, 10, 24, 13, 0)),
        ],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.closeCritical);
      expect(c, isEmpty);
    });

    test('non-critical milestones do not produce close-critical conflicts', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_m(1, 1, end: DateTime.utc(2026, 10, 24, 12, 0))],
        2: [_m(2, 2, end: DateTime.utc(2026, 10, 24, 13, 0))],
      };
      final c = ConflictDetector.detect(hs, ms, {}).where((x) => x.type == ConflictType.closeCritical);
      expect(c, isEmpty);
    });
  });

  group('orphaned teams', () {
    test('hackathons without a confirmed team are flagged orphaned', () {
      final hs = [_h(1)];
      final c = ConflictDetector.detect(hs, {}, {}).where((x) => x.type == ConflictType.orphanedTeam);
      expect(c, isNotEmpty);
      expect(c.first.severity, ConflictSeverity.warning);
    });

    test('marking a hackathon Primary suppresses its own orphan warning', () {
      final hs = [_h(1)];
      final c = ConflictDetector.detect(hs, {}, {1}).where((x) => x.type == ConflictType.orphanedTeam);
      expect(c, isEmpty);
    });

    test('archived hackathons are never flagged orphaned', () {
      final hs = [_h(1, status: HackathonStatus.archived)];
      final c = ConflictDetector.detect(hs, {}, {}).where((x) => x.type == ConflictType.orphanedTeam);
      expect(c, isEmpty);
    });
  });

  group('primary marking', () {
    test('primary marking suppresses the overlapping conflict on that side', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 27))],
        2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
      };
      final withPrimary = ConflictDetector.detect(hs, ms, {1}).where((x) => x.type == ConflictType.overlappingWindows);
      final ids = withPrimary.map((c) => c.hackathonId).toSet();
      expect(ids.contains(1), isFalse);
      expect(ids.contains(2), isTrue);
    });

    test('marking both sides Primary leaves no overlapping conflict', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_m(1, 1, start: DateTime.utc(2026, 10, 20), end: DateTime.utc(2026, 10, 27))],
        2: [_m(2, 2, start: DateTime.utc(2026, 10, 24), end: DateTime.utc(2026, 10, 31))],
      };
      final withBoth = ConflictDetector.detect(hs, ms, {1, 2}).where((x) => x.type == ConflictType.overlappingWindows);
      expect(withBoth, isEmpty);
    });
  });

  group('window helpers', () {
    test('windowStart prefers an explicit start over a point milestone end', () {
      final h = _h(1);
      final ms = [
        _m(1, 1, start: DateTime.utc(2026, 10, 20)),
        _m(2, 1, end: DateTime.utc(2026, 10, 25)),
      ];
      expect(ConflictDetector.windowStart(h, ms), DateTime.utc(2026, 10, 20));
    });

    test('windowStart falls back to the earliest point milestone end', () {
      final h = _h(1);
      final ms = [
        _m(1, 1, end: DateTime.utc(2026, 10, 25)),
        _m(2, 1, end: DateTime.utc(2026, 10, 22)),
      ];
      expect(ConflictDetector.windowStart(h, ms), DateTime.utc(2026, 10, 22));
    });

    test('windowEnd returns the latest end', () {
      final h = _h(1);
      final ms = [
        _m(1, 1, end: DateTime.utc(2026, 10, 25)),
        _m(2, 1, end: DateTime.utc(2026, 10, 31)),
      ];
      expect(ConflictDetector.windowEnd(h, ms), DateTime.utc(2026, 10, 31));
    });

    test('both helpers return null for an empty milestone list', () {
      final h = _h(1);
      expect(ConflictDetector.windowStart(h, const []), isNull);
      expect(ConflictDetector.windowEnd(h, const []), isNull);
    });
  });

  group('empty input', () {
    test('no conflicts with an empty input', () {
      expect(ConflictDetector.detect([], {}, {}), isEmpty);
    });

    test('a single hackathon produces only an orphan warning', () {
      final c = ConflictDetector.detect([_h(1)], {}, {});
      expect(c.length, 1);
      expect(c.first.type, ConflictType.orphanedTeam);
    });
  });
}
