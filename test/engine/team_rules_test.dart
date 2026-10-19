import 'package:test/test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/engine/team_rules.dart';

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
  group('status transitions', () {
    test('looking can move to applied', () {
      expect(TeamRules.canTransition(TeamStatus.looking, TeamStatus.applied), isTrue);
    });

    test('applied can move to confirmed', () {
      expect(TeamRules.canTransition(TeamStatus.applied, TeamStatus.confirmed), isTrue);
    });

    test('confirmed can move to registered', () {
      expect(TeamRules.canTransition(TeamStatus.confirmed, TeamStatus.registered), isTrue);
    });

    test('looking can jump straight to solo', () {
      expect(TeamRules.canTransition(TeamStatus.looking, TeamStatus.solo), isTrue);
    });

    test('disbanded is terminal', () {
      for (final s in TeamStatus.values) {
        expect(TeamRules.canTransition(TeamStatus.disbanded, s), isFalse,
            reason: 'disbanded -> $s');
      }
    });

    test('registered cannot go back to looking', () {
      expect(TeamRules.canTransition(TeamStatus.registered, TeamStatus.looking), isFalse);
    });

    test('no-op transitions are rejected', () {
      for (final s in TeamStatus.values) {
        expect(TeamRules.canTransition(s, s), isFalse, reason: '$s -> $s');
      }
    });

    test('left can be revived to looking', () {
      expect(TeamRules.canTransition(TeamStatus.left, TeamStatus.looking), isTrue);
    });
  });

  group('FR-15: second confirmed team', () {
    test('a second confirmed team in the same hackathon triggers a warning', () {
      final existing = [_t(1, 1, TeamStatus.confirmed)];
      final candidate = _t(2, 1, TeamStatus.confirmed);
      expect(TeamRules.warnsOnSecondConfirmed(existing, candidate, 1), isTrue);
    });

    test('one confirmed team per hackathon is fine', () {
      final existing = <Team>[];
      final candidate = _t(1, 1, TeamStatus.confirmed);
      expect(TeamRules.warnsOnSecondConfirmed(existing, candidate, 1), isFalse);
    });

    test('a confirmed team in a different hackathon is not a warning', () {
      final existing = [_t(1, 1, TeamStatus.confirmed)];
      final candidate = _t(2, 2, TeamStatus.confirmed);
      expect(TeamRules.warnsOnSecondConfirmed(existing, candidate, 2), isFalse);
    });

    test('a non-confirmed candidate is never a warning', () {
      final existing = [_t(1, 1, TeamStatus.confirmed)];
      final candidate = _t(2, 1, TeamStatus.applied);
      expect(TeamRules.warnsOnSecondConfirmed(existing, candidate, 1), isFalse);
    });
  });

  group('FR-16: roster size', () {
    TeamMember _m(int i) => TeamMember(
          id: i,
          teamId: 1,
          name: 'Member $i',
          role: 'Engineer',
          contact: '',
          isLead: i == 1,
        );

    test('roster over the limit is flagged', () {
      final members = [_m(1), _m(2), _m(3), _m(4)];
      expect(TeamRules.exceedsTeamSizeLimit(members, 3), isTrue);
    });

    test('roster at the limit is fine', () {
      final members = [_m(1), _m(2), _m(3)];
      expect(TeamRules.exceedsTeamSizeLimit(members, 3), isFalse);
    });

    test('null limit means no limit', () {
      final members = [_m(1), _m(2), _m(3), _m(4), _m(5)];
      expect(TeamRules.exceedsTeamSizeLimit(members, null), isFalse);
    });

    test('zero limit is treated as no limit', () {
      final members = [_m(1)];
      expect(TeamRules.exceedsTeamSizeLimit(members, 0), isFalse);
    });
  });
}
