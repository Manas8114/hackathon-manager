import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../engine/timezone_util.dart';
import '../../data/change_log.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets.dart';
import 'milestone_editor.dart';

class HackathonDetail extends ConsumerWidget {
  const HackathonDetail({super.key, required this.hackathonId});

  final int hackathonId;

  Future<void> _editMilestoneDate(
    BuildContext context,
    WidgetRef ref,
    Milestone milestone,
  ) async {
    final oldDate = milestone.endsAtUtc;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: oldDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: oldDate.hour, minute: oldDate.minute),
    );
    if (pickedTime == null || !context.mounted) return;

    final newDate = DateTime.utc(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Show side-by-side comparison modal (FR-5)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181824),
        title: const Text('Confirm Date Change', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review date shift before writing to the immutable audit log:',
              style: TextStyle(color: Color(0xFF9999AA), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101018),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Old:', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      Text(
                        TimezoneUtil.displayWallClock(oldDate, milestone.timezone, style: 'full'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF282838), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('New:', style: TextStyle(color: Color(0xFF00D68F), fontWeight: FontWeight.bold)),
                      Text(
                        TimezoneUtil.displayWallClock(newDate, milestone.timezone, style: 'full'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm & Log'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repo = ref.read(repoProvider);
      final scheduler = ref.read(schedulerProvider);
      final updated = milestone.copyWith(endsAtUtc: newDate);
      await repo.saveMilestone(updated);
      await scheduler.replanForMilestone(updated.id);
    }
  }

  Future<void> _toggleVerified(WidgetRef ref, Milestone milestone) async {
    final repo = ref.read(repoProvider);
    await repo.saveMilestone(milestone.copyWith(verified: !milestone.verified));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);

    return StreamBuilder<List<Hackathon>>(
      stream: repo.watchHackathons(),
      builder: (context, hSnapshot) {
        final hackathons = hSnapshot.data ?? [];
        final hackathon = hackathons.where((h) => h.id == hackathonId).firstOrNull;

        if (hackathon == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Hackathon not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(hackathon.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                tooltip: 'Archive Hackathon',
                onPressed: () async {
                  await repo.archiveHackathon(hackathon.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: StreamBuilder<List<Milestone>>(
            stream: repo.watchMilestonesFor(hackathonId),
            builder: (context, mSnapshot) {
              final milestones = (mSnapshot.data ?? [])
                ..sort((a, b) => a.endsAtUtc.compareTo(b.endsAtUtc));

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                          children: [
                            StatusChip(hackathon.status),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222233),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hackathon.mode.label,
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              hackathon.organizerTimezone,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF8888AA)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Organized by ${hackathon.organizer}',
                          style: const TextStyle(color: Color(0xFF9999AA), fontSize: 14),
                        ),
                        if (hackathon.url.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            hackathon.url,
                            style: const TextStyle(color: Color(0xFF8B85FF), fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Milestones (${milestones.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEEEEFF),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Milestone'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MilestoneEditor(hackathonId: hackathonId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (milestones.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No milestones tracked yet.',
                          style: TextStyle(color: Color(0xFF777788)),
                        ),
                      ),
                    )
                  else
                    ...milestones.map((m) {
                      return _MilestoneTile(
                        milestone: m,
                        onEditDate: () => _editMilestoneDate(context, ref, m),
                        onToggleVerified: () => _toggleVerified(ref, m),
                      );
                    }),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _MilestoneTile extends ConsumerWidget {
  const _MilestoneTile({
    required this.milestone,
    required this.onEditDate,
    required this.onToggleVerified,
  });

  final Milestone milestone;
  final VoidCallback onEditDate;
  final VoidCallback onToggleVerified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (milestone.isCritical) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'CRITICAL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF5252)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    milestone.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    milestone.verified ? Icons.verified : Icons.verified_outlined,
                    color: milestone.verified ? const Color(0xFF00D68F) : const Color(0xFF666677),
                    size: 20,
                  ),
                  tooltip: milestone.verified ? 'Verified' : 'Click to verify',
                  onPressed: onToggleVerified,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Color(0xFF8888AA)),
                const SizedBox(width: 6),
                Text(
                  TimezoneUtil.displayWallClock(milestone.endsAtUtc, milestone.timezone, style: 'full'),
                  style: const TextStyle(fontSize: 13, color: Color(0xFFCCCCDD), fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onEditDate,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Shift date',
                      style: TextStyle(color: Color(0xFF8B85FF), fontSize: 12, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
            if (milestone.criticalReason != null && milestone.criticalReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                milestone.criticalReason!,
                style: const TextStyle(color: Color(0xFF888899), fontSize: 12),
              ),
            ],
            // Change log section (FR-5)
            StreamBuilder<List<MilestoneChange>>(
              stream: repo.watchMilestoneChanges(milestone.id),
              builder: (context, snapshot) {
                final changes = snapshot.data ?? [];
                if (changes.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111118),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change History:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF777788)),
                      ),
                      const SizedBox(height: 4),
                      ...changes.map((c) => Text(
                            '• ${c.changedField.name} shifted from "${c.oldValue}" to "${c.newValue}"',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                          )),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
