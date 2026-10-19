import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../engine/timezone_util.dart';
import '../../engine/conflict_detector.dart';
import '../../providers/app_providers.dart';
import '../../ui/shared/widgets.dart';
import '../hackathons/hackathon_detail.dart';
import '../hackathons/add_hackathon_sheet.dart';

class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);

    return StreamBuilder<List<Hackathon>>(
      stream: repo.watchHackathons(),
      builder: (context, hackSnap) {
        if (!hackSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final hackathons = hackSnap.data!
            .where((h) => h.status != HackathonStatus.archived)
            .toList();

        return StreamBuilder<Map<int, List<Milestone>>>(
          stream: repo.watchMilestonesGrouped(),
          builder: (context, msSnap) {
            final grouped = msSnap.data ?? {};
            final now = DateTime.now().toUtc();
            final cutoff = now.add(const Duration(days: 7));

            // Section 1: deadlines in next 7 days
            final upcoming = <(Hackathon, Milestone)>[];
            for (final h in hackathons) {
              for (final m in grouped[h.id] ?? []) {
                if (m.endsAtUtc.isAfter(now) &&
                    m.endsAtUtc.isBefore(cutoff)) {
                  upcoming.add((h, m));
                }
              }
            }
            upcoming
                .sort((a, b) => a.$2.endsAtUtc.compareTo(b.$2.endsAtUtc));

            // Section 2: hackathons without confirmed team
            final teamsMap = {
              for (final h in hackathons) h.id: repo.teamsFor(h.id),
            };
            final noTeam = hackathons.where((h) {
              final teams = teamsMap[h.id] ?? [];
              return !teams.any((t) => t.status == TeamStatus.confirmed);
            }).toList();

            // Section 3: conflicts
            final conflicts = ConflictDetector.detect(hackathons, grouped, const {})
                .where((c) => c.type != ConflictType.orphanedTeam)
                .toList();

            final isEmpty = upcoming.isEmpty && noTeam.isEmpty;

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    backgroundColor: const Color(0xFF0A0A0F),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6666AA),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: Color(0xFF6C63FF)),
                        onPressed: () => _addHackathon(context),
                        tooltip: 'Add hackathon',
                      ),
                      const SizedBox(width: 8),
                    ],
                    expandedHeight: 80,
                    flexibleSpace: const FlexibleSpaceBar(),
                  ),
                  if (isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.rocket_launch_outlined,
                        title: 'No deadlines coming up',
                        subtitle:
                            'Add a hackathon to start tracking milestones and reminders.',
                        action: FilledButton.icon(
                          onPressed: () => _addHackathon(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Hackathon'),
                        ),
                      ),
                    )
                  else ...[
                    // ── Section 1: Upcoming deadlines ──────────────────────
                    if (upcoming.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: SectionHeader('Next 7 Days'),
                      ),
                      SliverList.separated(
                        itemCount: upcoming.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 2),
                        itemBuilder: (context, i) {
                          final (h, m) = upcoming[i];
                          return _DeadlineCard(
                            hackathon: h,
                            milestone: m,
                            onTap: () => _openDetail(context, h),
                          );
                        },
                      ),
                    ],

                    // ── Section 2: No confirmed team ───────────────────────
                    if (noTeam.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: SectionHeader('Needs a Team'),
                      ),
                      SliverList.builder(
                        itemCount: noTeam.length,
                        itemBuilder: (context, i) {
                          final h = noTeam[i];
                          return _NoTeamCard(
                            hackathon: h,
                            nextDeadline: (grouped[h.id] ?? [])
                                .where((m) => m.endsAtUtc.isAfter(now))
                                .toList()
                              ..sort((a, b) =>
                                  a.endsAtUtc.compareTo(b.endsAtUtc)),
                            onTap: () => _openDetail(context, h),
                          );
                        },
                      ),
                    ],

                    // ── Section 3: Conflicts ───────────────────────────────
                    if (conflicts.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: SectionHeader('Conflicts'),
                      ),
                      SliverList.builder(
                        itemCount: conflicts.length,
                        itemBuilder: (context, i) =>
                            _ConflictCard(conflict: conflicts[i]),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ],
              ),
              floatingActionButton: !isEmpty
                  ? FloatingActionButton(
                      onPressed: () => _addHackathon(context),
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.add_rounded),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning 🌅';
    if (h < 17) return 'Good afternoon ☀️';
    if (h < 21) return 'Good evening 🌙';
    return 'Good night 🌠';
  }

  void _addHackathon(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddHackathonSheet(),
    );
  }

  void _openDetail(BuildContext context, Hackathon h) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HackathonDetail(hackathonId: h.id),
      ),
    );
  }
}

// ── Deadline card ─────────────────────────────────────────────────────────────

class _DeadlineCard extends StatelessWidget {
  const _DeadlineCard({
    required this.hackathon,
    required this.milestone,
    required this.onTap,
  });

  final Hackathon hackathon;
  final Milestone milestone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wallClock = TimezoneUtil.displayWallClock(
      milestone.endsAtUtc,
      milestone.timezone,
      style: 'medium',
    );
    final zoneAbbr = TimezoneUtil.zoneAbbr(
      milestone.timezone,
      milestone.endsAtUtc,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14141E),
            borderRadius: BorderRadius.circular(16),
            border: milestone.isCritical
                ? Border.all(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                    width: 1)
                : null,
          ),
          child: Row(
            children: [
              // ── Left: colored indicator ───────────────────────────────────
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: milestone.isCritical
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              // ── Center: content ───────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hackathon.name,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8888AA),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      milestone.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: const Color(0xFF6666AA),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$wallClock $zoneAbbr',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8888AA),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (milestone.isCritical) const CriticalBadge(),
                        if (milestone.verified) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ── Right: countdown ──────────────────────────────────────────
              CountdownBadge(milestone.endsAtUtc),
            ],
          ),
        ),
      ),
    );
  }
}

// ── No-team warning card ──────────────────────────────────────────────────────

class _NoTeamCard extends StatelessWidget {
  const _NoTeamCard({
    required this.hackathon,
    required this.nextDeadline,
    required this.onTap,
  });

  final Hackathon hackathon;
  final List<Milestone> nextDeadline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1408),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFAA00).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.group_off_rounded,
                  color: Color(0xFFFFAA00), size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hackathon.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No confirmed team${nextDeadline.isNotEmpty ? ' · next deadline ${_days(nextDeadline.first.endsAtUtc)}' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFFFAA00),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF444455), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _days(DateTime d) {
    final diff = d.difference(DateTime.now().toUtc());
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'tomorrow';
    return 'in ${diff.inDays} days';
  }
}

// ── Conflict card ─────────────────────────────────────────────────────────────

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict});
  final Conflict conflict;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: Color(0xFFFF6B6B), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Scheduling Conflict',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              conflict.message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFCCCCDD),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6C63FF)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Mark as Primary',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Mark as Backup',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF8888AA)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
