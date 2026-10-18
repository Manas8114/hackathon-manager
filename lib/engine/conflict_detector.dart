import 'models.dart';

/// FR-20: conflict detection for overlapping windows, Critical deadlines within
/// 24 hours of each other, and hackathons with no confirmed team.
///
/// Conflicts are computed on demand and never stored, so they stay consistent
/// without a sync path. [primaryIds] marks a hackathon Primary or Backup: that
/// marking suppresses the conflict on its side and reports it against the other.
class ConflictDetector {
  ConflictDetector._();

  static final _nearCriticalWindow = const Duration(hours: 24);

  static List<Conflict> detect(
    List<Hackathon> hackathons,
    Map<int, List<Milestone>> milestonesByHackathon,
    Set<int> primaryIds,
  ) {
    final out = <Conflict>[];
    final active = hackathons
        .where((h) =>
            h.status == HackathonStatus.upcoming || h.status == HackathonStatus.running)
        .toList();

    for (final h in active) {
      if (primaryIds.contains(h.id)) continue;
      out.add(Conflict(
        type: ConflictType.orphanedTeam,
        severity: ConflictSeverity.warning,
        hackathonId: h.id,
        message: 'No confirmed team for ${h.name} yet.',
      ));
    }

    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        final a = active[i];
        final b = active[j];
        final sa = windowStart(a, milestonesByHackathon[a.id] ?? const []);
        final ea = windowEnd(a, milestonesByHackathon[a.id] ?? const []);
        final sb = windowStart(b, milestonesByHackathon[b.id] ?? const []);
        final eb = windowEnd(b, milestonesByHackathon[b.id] ?? const []);
        if (sa == null || ea == null || sb == null || eb == null) continue;
        // Half-open intervals: two events touching at exactly one instant do not overlap.
        final overlaps = sa.isBefore(eb) && sb.isBefore(ea);
        if (!overlaps) continue;
        // When both sides are marked Primary the overlap is accepted by the
        // user and no conflict is reported.
        if (primaryIds.contains(a.id) && primaryIds.contains(b.id)) continue;
        final reportAgainst =
            primaryIds.contains(b.id) ? a.id : b.id;
        out.add(Conflict(
          type: ConflictType.overlappingWindows,
          severity: ConflictSeverity.danger,
          hackathonId: reportAgainst,
          partnerHackathonId: reportAgainst == a.id ? b.id : a.id,
          message: '${a.name} and ${b.name} run at the same time.',
        ));
      }
    }

    final criticals = <(Milestone, Hackathon)>[];
    for (final h in active) {
      for (final m in milestonesByHackathon[h.id] ?? const <Milestone>[]) {
        if (m.isCritical) criticals.add((m, h));
      }
    }
    for (var i = 0; i < criticals.length; i++) {
      for (var j = i + 1; j < criticals.length; j++) {
        final (ma, ha) = criticals[i];
        final (mb, hb) = criticals[j];
        if (ha.id == hb.id) continue;
        final delta = ma.endsAtUtc.difference(mb.endsAtUtc).abs();
        if (delta > _nearCriticalWindow) continue;
        final reportAgainst = primaryIds.contains(hb.id) ? ha.id : hb.id;
        out.add(Conflict(
          type: ConflictType.closeCritical,
          severity: ConflictSeverity.danger,
          hackathonId: reportAgainst,
          partnerHackathonId: reportAgainst == ha.id ? hb.id : ha.id,
          message: 'Critical deadlines within 24 hours: ${ha.name} and ${hb.name}.',
        ));
      }
    }
    return out;
  }

  /// Earliest `startsAtUtc` across the hackathon's milestones, falling back to
  /// the earliest point milestone's `endsAtUtc`.
  static DateTime? windowStart(Hackathon h, List<Milestone> ms) {
    if (ms.isEmpty) return null;
    DateTime? best;
    for (final m in ms) {
      final s = m.startsAtUtc ?? m.endsAtUtc;
      if (best == null || s.isBefore(best)) best = s;
    }
    return best;
  }

  /// Latest `endsAtUtc` across the hackathon's milestones.
  static DateTime? windowEnd(Hackathon h, List<Milestone> ms) {
    if (ms.isEmpty) return null;
    DateTime? best;
    for (final m in ms) {
      if (best == null || m.endsAtUtc.isAfter(best)) best = m.endsAtUtc;
    }
    return best;
  }
}
