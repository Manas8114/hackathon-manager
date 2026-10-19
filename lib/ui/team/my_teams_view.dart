import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../engine/timezone_util.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets.dart';
import 'team_detail.dart';
import 'team_editor.dart';

class MyTeamsView extends ConsumerWidget {
  const MyTeamsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Teams'),
      ),
      body: StreamBuilder<List<Hackathon>>(
        stream: repo.watchHackathons(),
        builder: (context, hSnapshot) {
          final hackathons = (hSnapshot.data ?? [])
              .where((h) => h.status != HackathonStatus.archived)
              .toList();

          return StreamBuilder<Map<int, List<Milestone>>>(
            stream: repo.watchMilestonesGrouped(),
            builder: (context, mSnapshot) {
              final groupedMilestones = mSnapshot.data ?? {};

              return StreamBuilder<Map<int, int>>(
                stream: repo.watchMemberCounts(),
                builder: (context, countSnapshot) {
                  final memberCounts = countSnapshot.data ?? {};

                  if (hackathons.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hackathons tracked yet',
                        style: TextStyle(color: Color(0xFF777788)),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: hackathons.length,
                    itemBuilder: (context, index) {
                      final h = hackathons[index];
                      final teams = repo.teamsFor(h.id);
                      final milestones = groupedMilestones[h.id] ?? [];
                      final now = DateTime.now().toUtc();
                      final nextM = milestones
                          .where((m) => m.endsAtUtc.isAfter(now))
                          .toList()
                        ..sort((a, b) => a.endsAtUtc.compareTo(b.endsAtUtc));
                      final nextDeadline = nextM.firstOrNull;

                      final confirmedCount = teams
                          .where((t) => t.status == TeamStatus.confirmed)
                          .length;
                      final hasMultipleConfirmed = confirmedCount > 1;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      h.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('New Team', style: TextStyle(fontSize: 12)),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => TeamEditor(hackathonId: h.id),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              if (nextDeadline != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.alarm, size: 14, color: Color(0xFF8888AA)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Next deadline: ${nextDeadline.title} (${TimezoneUtil.displayWallClock(nextDeadline.endsAtUtc, h.organizerTimezone, style: 'compact')})',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF9999AA)),
                                    ),
                                  ],
                                ),
                              ],
                              if (hasMultipleConfirmed) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFAA00).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFFAA00).withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFFFAA00)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Another confirmed team exists for this hackathon.',
                                          style: TextStyle(fontSize: 12, color: Color(0xFFFFAA00), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (teams.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No team formed yet. Looking for teammates or going solo?',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF666677)),
                                  ),
                                )
                              else
                                ...teams.map((t) {
                                  final membersCount = memberCounts[t.id] ?? repo.membersFor(t.id).length;
                                  return Card(
                                    color: const Color(0xFF161622),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => TeamDetail(teamId: t.id),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    t.name,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    t.ideaTitle.isNotEmpty
                                                        ? t.ideaTitle
                                                        : '$membersCount member${membersCount == 1 ? '' : 's'}',
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF8888AA)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            TeamStatusChip(t.status),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.chevron_right, size: 18, color: Colors.white30),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
