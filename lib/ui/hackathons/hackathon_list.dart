import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../engine/timezone_util.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets.dart';
import 'hackathon_detail.dart';
import 'add_hackathon_sheet.dart';

class HackathonList extends ConsumerWidget {
  const HackathonList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hackathons'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Hackathon',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AddHackathonSheet(),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Hackathon>>(
        stream: repo.watchHackathons(),
        builder: (context, hSnapshot) {
          final hackathons = (hSnapshot.data ?? [])
              .where((h) => h.status != HackathonStatus.archived)
              .toList();

          if (hackathons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.code, size: 64, color: Color(0xFF333348)),
                  const SizedBox(height: 16),
                  const Text(
                    'No hackathons tracked yet',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your first hackathon to track deadlines and teams',
                    style: TextStyle(fontSize: 13, color: Color(0xFF666677)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Hackathon'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AddHackathonSheet(),
                      );
                    },
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<Map<int, List<Milestone>>>(
            stream: repo.watchMilestonesGrouped(),
            builder: (context, mSnapshot) {
              final grouped = mSnapshot.data ?? {};

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: hackathons.length,
                itemBuilder: (context, index) {
                  final h = hackathons[index];
                  final milestones = grouped[h.id] ?? [];
                  final now = DateTime.now().toUtc();
                  final upcomingMs = milestones
                      .where((m) => m.endsAtUtc.isAfter(now))
                      .toList()
                    ..sort((a, b) => a.endsAtUtc.compareTo(b.endsAtUtc));
                  final nextM = upcomingMs.firstOrNull;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HackathonDetail(hackathonId: h.id),
                          ),
                        );
                      },
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
                                StatusChip(h.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  h.organizer,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF888899),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('•', style: TextStyle(color: Color(0xFF555566))),
                                const SizedBox(width: 8),
                                Text(
                                  h.mode.label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6C63FF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (nextM != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161622),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.alarm,
                                      size: 16,
                                      color: nextM.isCritical ? const Color(0xFFFF5252) : const Color(0xFF00D68F),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Next: ${nextM.title}',
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      TimezoneUtil.displayWallClock(nextM.endsAtUtc, nextM.timezone, style: 'compact'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: nextM.isCritical ? const Color(0xFFFF5252) : const Color(0xFF00D68F),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Text(
                                '${milestones.length} milestones tracked',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF666677)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
