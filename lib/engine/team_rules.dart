import 'models.dart';

/// FR-14, FR-15, FR-16: team status lifecycle and validation.
///
/// The lifecycle is a hard state machine: a transition is either in
/// [allowedTransitions] or it is not. The store never accepts an illegal
/// transition, so the UI cannot put a team in an impossible state.
class TeamRules {
  TeamRules._();

  static const Map<TeamStatus, List<TeamStatus>> allowedTransitions = {
    TeamStatus.looking: [TeamStatus.applied, TeamStatus.invited, TeamStatus.solo,
      TeamStatus.left, TeamStatus.disbanded],
    TeamStatus.applied: [
      TeamStatus.confirmed,
      TeamStatus.looking,
      TeamStatus.left,
      TeamStatus.disbanded
    ],
    TeamStatus.invited: [
      TeamStatus.confirmed,
      TeamStatus.looking,
      TeamStatus.left,
      TeamStatus.disbanded
    ],
    TeamStatus.confirmed: [
      TeamStatus.registered,
      TeamStatus.left,
      TeamStatus.disbanded,
      TeamStatus.looking,
    ],
    TeamStatus.registered: [TeamStatus.left, TeamStatus.disbanded],
    TeamStatus.left: [TeamStatus.looking],
    TeamStatus.disbanded: [],
    TeamStatus.solo: [TeamStatus.looking, TeamStatus.disbanded],
  };

  static bool canTransition(TeamStatus from, TeamStatus to) {
    if (from == to) return false;
    return allowedTransitions[from]?.contains(to) ?? false;
  }

  /// FR-15: warn when a second Confirmed team is added for the same hackathon.
  static bool warnsOnSecondConfirmed(
      List<Team> existing, Team candidate, int hackathonId) {
    if (candidate.hackathonId != hackathonId) return false;
    if (candidate.status != TeamStatus.confirmed) return false;
    return existing.any((t) =>
        t.hackathonId == hackathonId &&
        t.status == TeamStatus.confirmed &&
        t.id != candidate.id);
  }

  /// FR-16: warn when the roster exceeds the hackathon's team size limit.
  static bool exceedsTeamSizeLimit(List<TeamMember> members, int? limit) {
    if (limit == null || limit <= 0) return false;
    return members.length > limit;
  }
}
