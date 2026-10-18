import 'package:test/test.dart';
import 'package:hackathon_manager/engine/changelog.dart';

ChangeEntry _e({
  int hackathonId = 1,
  int teamId = 1,
  ChangeField field = ChangeField.status,
  String from = 'looking',
  String to = 'confirmed',
  DateTime? at,
}) =>
    ChangeEntry(
      at: at ?? DateTime.utc(2026, 10, 18, 12, 0),
      hackathonId: hackathonId,
      teamId: teamId,
      field: field,
      from: from,
      to: to,
    );

void main() {
  group('append-only', () {
    test('append returns a new ChangeLog and does not mutate the input', () {
      const log = ChangeLog([]);
      final grown = log.append(_e());
      expect(log.entries, isEmpty);
      expect(grown.entries, hasLength(1));
    });

    test('entries can be appended in sequence', () {
      var log = const ChangeLog([]);
      log = log.append(_e());
      log = log.append(_e(field: ChangeField.memberAdded, from: '', to: 'Ana'));
      expect(log.entries, hasLength(2));
    });

    test('the constructor with a non-empty list keeps all entries', () {
      final log = ChangeLog([_e(), _e(hackathonId: 2)]);
      expect(log.entries, hasLength(2));
    });
  });

  group('queries', () {
    test('forHackathon filters by hackathon', () {
      final log = ChangeLog([_e(hackathonId: 1), _e(hackathonId: 2), _e(hackathonId: 1)]);
      expect(log.forHackathon(1), hasLength(2));
      expect(log.forHackathon(2), hasLength(1));
    });

    test('forTeam filters by team', () {
      final log = ChangeLog([_e(teamId: 1), _e(teamId: 2), _e(teamId: 1)]);
      expect(log.forTeam(1), hasLength(2));
      expect(log.forTeam(2), hasLength(1));
    });

    test('reversed returns a copy in reverse order', () {
      final log = ChangeLog([
        _e(from: 'a', to: 'b'),
        _e(from: 'b', to: 'c'),
      ]);
      expect(log.reversed, hasLength(2));
      expect(log.reversed.first.from, 'b');
      expect(log.reversed.last.from, 'a');
    });

    test('empty log queries return empty lists', () {
      const log = ChangeLog([]);
      expect(log.forHackathon(1), isEmpty);
      expect(log.forTeam(1), isEmpty);
      expect(log.reversed, isEmpty);
    });
  });

  group('entry shape', () {
    test('entries carry before and after values', () {
      final e = _e(from: 'looking', to: 'confirmed');
      expect(e.from, 'looking');
      expect(e.to, 'confirmed');
      expect(e.field, ChangeField.status);
    });

    test('actor defaults to user', () {
      expect(_e().actor, 'user');
    });

    test('all change fields are covered', () {
      expect(ChangeField.values,
          containsAll([
            ChangeField.status,
            ChangeField.memberAdded,
            ChangeField.memberRemoved,
            ChangeField.memberRole,
            ChangeField.memberLead,
          ]));
    });
  });
}
