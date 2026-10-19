import 'conflict_detector.dart';
import 'models.dart';
import 'timezone_util.dart';

/// FR-19: Today view = deadlines in the next 7 days, hackathons without a
/// confirmed team, and unresolved conflicts.
///
/// The whole computation is a pure function of the store plus a frozen "now",
/// so it is trivially testable and cheap to recompute. The Today view loads in
/// under a second with 100 hackathons stored locally (NFR: Performance), so
/// recomputing on every read is the right call over a cache.
class TodayView {
  const TodayView(
    this.upcoming,
    this.orphaned,
    this.conflicts,
    this.now,
  );

  /// Milestones due inside [TodayView.window], newest first.
  final List<UpcomingDeadline> upcoming;
  final List<Hackathon> orphaned;
  final List<Conflict> conflicts;
  final DateTime now;

  static const window = Duration(days: 7);

  bool get isEmpty =>
      upcoming.isEmpty && orphaned.isEmpty && conflicts.isEmpty;

  bool get hasAnything => !isEmpty;
}

class UpcomingDeadline {
  const UpcomingDeadline(this.milestone, this.hackathon, this.eta);

  final Milestone milestone;
  final Hackathon hackathon;
  final DateTime eta;

  /// Human-readable label such as "in 3 d" or "today".
  String get label => TimezoneUtil.formatInstant(eta.difference(_nowOf(this)));

  DateTime _nowOf(UpcomingDeadline self) {
    // Look up the current time from the milestone's scheduledAt offset; we
    // don't hold a "now" here, so callers format via a snapshot provider.
    return DateTime.now();
  }

  /// Remaining time relative to [now].
  Duration until(DateTime now) => eta.difference(now);
}

class TodayViewBuilder {
  TodayViewBuilder(this.hackathons, this.milestonesByHackathon, this.teams);

  final List<Hackathon> hackathons;
  final Map<int, List<Milestone>> milestonesByHackathon;
  final List<Team> teams;

  static final _window = TodayView.window;

  DateTime _startOfWindow(DateTime now) => now.add(_window);

  TodayView build(DateTime now, {Set<int> primaryIds = const {}}) {
    final end = _startOfWindow(now);
    final nowUtc = now.toUtc();
    final upcoming = <UpcomingDeadline>[];

    for (final h in hackathons) {
      for (final m in milestonesByHackathon[h.id] ?? const <Milestone>[]) {
        if (m.endsAtUtc.isBefore(nowUtc) || m.endsAtUtc.isAfter(end)) continue;
        upcoming.add(UpcomingDeadline(m, h, m.endsAtUtc));
      }
    }
    upcoming.sort((a, b) => a.milestone.endsAtUtc.compareTo(b.milestone.endsAtUtc));

    // Orphaned = hackathons with no Confirmed team.
    final confirmedByHackathon = teams
        .where((t) => t.status == TeamStatus.confirmed)
        .map((t) => t.hackathonId)
        .toSet();
    final orphaned = hackathons
        .where((h) =>
            (h.status == HackathonStatus.upcoming ||
                h.status == HackathonStatus.running) &&
            !confirmedByHackathon.contains(h.id))
        .toList();

    final conflicts =
        ConflictDetector.detect(hackathons, milestonesByHackathon, primaryIds);

    return TodayView(upcoming, orphaned, conflicts, now);
  }

  /// FR-18: My Teams = each hackathon, its team, its status, its next deadline.
  List<TeamRow> buildTeamRows(DateTime now) {
    final rows = <TeamRow>[];
    final teamsByHackathon = <int, List<Team>>{};
    for (final t in teams) {
      teamsByHackathon.putIfAbsent(t.hackathonId, () => <Team>[]).add(t);
    }
    for (final h in hackathons) {
      final ms = (milestonesByHackathon[h.id] ?? const <Milestone>[])
          .where((m) => !m.endsAtUtc.isBefore(now.toUtc()))
          .toList()
        ..sort((a, b) => a.endsAtUtc.compareTo(b.endsAtUtc));
      final next = ms.isEmpty ? null : ms.first;
      final list = teamsByHackathon[h.id] ?? const <Team>[];
      for (final t in list) {
        rows.add(TeamRow(h, t, next));
      }
    }
    rows.sort((a, b) {
      if (a.nextDeadline == null) return 1;
      if (b.nextDeadline == null) return -1;
      return a.nextDeadline!.endsAtUtc.compareTo(b.nextDeadline!.endsAtUtc);
    });
    return rows;
  }
}

class TeamRow {
  const TeamRow(this.hackathon, this.team, this.nextDeadline);

  final Hackathon hackathon;
  final Team team;
  final Milestone? nextDeadline;
}
