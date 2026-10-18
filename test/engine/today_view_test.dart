import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/today_view.dart';

final _now = DateTime.utc(2026, 10, 18, 12, 0, 0);

Hackathon _h(int id, {HackathonStatus status = HackathonStatus.upcoming}) =>
    Hackathon(
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

Milestone _m(int id, int hid, DateTime at) => Milestone(
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

Team _t(int id, int hid, TeamStatus s) => Team(
      id: id,
      hackathonId: hid,
      name: 'Team $id',
      status: s,
      ideaTitle: '',
      techStack: const [],
      repoLink: '',
      chatLink: '',
      notes: '',
      createdAt: DateTime.utc(2026, 10, 1),
      modifiedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  group('today view window', () {
    test('milestones inside 7 days are listed, ordered by endsAtUtc', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_m(1, 1, DateTime.utc(2026, 10, 22))],
        2: [_m(2, 2, DateTime.utc(2026, 10, 20))],
      };
      final v = TodayViewBuilder(hs, ms, const []).build(_now);
      expect(v.upcoming.length, 2);
      expect(v.upcoming.first.milestone.id, 2);
      expect(v.upcoming.last.milestone.id, 1);
    });

    test('milestones just past the 7-day window are excluded', () {
      final hs = [_h(1)];
      final ms = {
        1: [_m(1, 1, DateTime.utc(2026, 10, 26, 0, 0, 1))],
      };
      final v = TodayViewBuilder(hs, ms, const []).build(_now);
      expect(v.upcoming, isEmpty);
    });

    test('past milestones are excluded', () {
      final hs = [_h(1)];
      final ms = {
        1: [_m(1, 1, DateTime.utc(2026, 10, 1))],
      };
      final v = TodayViewBuilder(hs, ms, const []).build(_now);
      expect(v.upcoming, isEmpty);
    });

    test('milestones exactly at now are included', () {
      final hs = [_h(1)];
      final ms = {1: [_m(1, 1, _now)]};
      final v = TodayViewBuilder(hs, ms, const []).build(_now);
      expect(v.upcoming.length, 1);
    });
  });

  group('orphaned hackathons', () {
    test('hackathons without a confirmed team are orphaned', () {
      final hs = [_h(1)];
      final v = TodayViewBuilder(hs, {}, const []).build(_now);
      expect(v.orphaned, hasLength(1));
    });

    test('hackathons with a confirmed team are not orphaned', () {
      final hs = [_h(1)];
      final v = TodayViewBuilder(hs, {}, [_t(1, 1, TeamStatus.confirmed)]).build(_now);
      expect(v.orphaned, isEmpty);
    });

    test('non-confirmed team statuses do not clear orphaned', () {
      final hs = [_h(1)];
      final v = TodayViewBuilder(hs, {}, [_t(1, 1, TeamStatus.applied)]).build(_now);
      expect(v.orphaned, hasLength(1));
    });

    test('archived hackathons are never orphaned', () {
      final hs = [_h(1, status: HackathonStatus.archived)];
      final v = TodayViewBuilder(hs, {}, const []).build(_now);
      expect(v.orphaned, isEmpty);
    });
  });

  group('conflicts', () {
    test('overlapping windows surface in the today view', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [
          Milestone(
            id: 1,
            hackathonId: 1,
            label: MilestoneLabel.eventWindow,
            title: 'Win',
            startsAtUtc: DateTime.utc(2026, 10, 20),
            endsAtUtc: DateTime.utc(2026, 10, 27),
            timezone: 'UTC',
            isCritical: false,
            verified: false,
            createdAt: DateTime.utc(2026, 10, 1),
            modifiedAt: DateTime.utc(2026, 10, 1),
          ),
        ],
        2: [
          Milestone(
            id: 2,
            hackathonId: 2,
            label: MilestoneLabel.eventWindow,
            title: 'Win',
            startsAtUtc: DateTime.utc(2026, 10, 24),
            endsAtUtc: DateTime.utc(2026, 10, 31),
            timezone: 'UTC',
            isCritical: false,
            verified: false,
            createdAt: DateTime.utc(2026, 10, 1),
            modifiedAt: DateTime.utc(2026, 10, 1),
          ),
        ],
      };
      final v = TodayViewBuilder(hs, ms, const []).build(_now);
      expect(v.conflicts.any((c) => c.type == ConflictType.overlappingWindows), isTrue);
    });
  });

  group('team rows', () {
    test('one row per hackathon/team pair, ordered by next deadline', () {
      final hs = [_h(1), _h(2)];
      final ms = {
        1: [_m(1, 1, DateTime.utc(2026, 10, 30))],
        2: [_m(2, 2, DateTime.utc(2026, 10, 25))],
      };
      final teams = [_t(1, 1, TeamStatus.confirmed), _t(2, 2, TeamStatus.applied)];
      final rows = TodayViewBuilder(hs, ms, teams).buildTeamRows(_now);
      expect(rows, hasLength(2));
      expect(rows.first.team.id, 2);
      expect(rows.first.nextDeadline!.id, 2);
    });

    test('past-only milestones yield a null next deadline', () {
      final hs = [_h(1)];
      final ms = {1: [_m(1, 1, DateTime.utc(2026, 10, 1))]};
      final rows =
          TodayViewBuilder(hs, ms, [_t(1, 1, TeamStatus.confirmed)]).buildTeamRows(_now);
      expect(rows.single.nextDeadline, isNull);
    });
  });

  group('empty states', () {
    test('an empty store yields an empty today view', () {
      final v = TodayViewBuilder([], {}, const []).build(_now);
      expect(v.upcoming, isEmpty);
      expect(v.orphaned, isEmpty);
      expect(v.conflicts, isEmpty);
    });

    test('the today view knows it is empty', () {
      final v = TodayViewBuilder([], {}, const []).build(_now);
      expect(v.isEmpty, isTrue);
      expect(v.hasAnything, isFalse);
    });
  });
}
