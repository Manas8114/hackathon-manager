import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/models.dart';
import '../../data/change_log.dart';
import '../../providers/app_providers.dart';
import '../shared/widgets.dart';
import 'team_editor.dart';

class TeamDetail extends ConsumerWidget {
  const TeamDetail({super.key, required this.teamId});

  final int teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);

    return StreamBuilder<List<Team>>(
      stream: repo.watchTeamsFor(-1), // or find from allTeams
      builder: (context, snapshot) {
        final all = repo.allTeams;
        final team = all.where((t) => t.id == teamId).firstOrNull;

        if (team == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Team not found')),
          );
        }

        final members = repo.membersFor(team.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(team.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeamEditor(
                        hackathonId: team.hackathonId,
                        initial: team,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              team.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          TeamStatusChip(team.status),
                        ],
                      ),
                      if (team.ideaTitle.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Idea / Project', style: TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
                        const SizedBox(height: 4),
                        Text(team.ideaTitle, style: const TextStyle(fontSize: 16, color: Colors.white)),
                      ],
                      if (team.techStack.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Tech Stack', style: TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: team.techStack.map((tech) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF26263A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(tech, style: const TextStyle(fontSize: 12, color: Color(0xFFCCCCEE))),
                            );
                          }).toList(),
                        ),
                      ],
                      if (team.repoUrl.isNotEmpty || team.chatUrl.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (team.repoUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link, size: 16, color: Color(0xFF6C63FF)),
                                    const SizedBox(width: 4),
                                    Text(team.repoUrl, style: const TextStyle(color: Color(0xFF8B85FF), fontSize: 12)),
                                  ],
                                ),
                              ),
                            if (team.chatUrl.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF00D68F)),
                                  const SizedBox(width: 4),
                                  Text(team.chatUrl, style: const TextStyle(color: Color(0xFF00D68F), fontSize: 12)),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Members (${members.length}${team.maxSize != null ? '/${team.maxSize}' : ''})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              ...members.map((m) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: m.isLead ? const Color(0xFF6C63FF) : const Color(0xFF28283C),
                      child: Icon(m.isLead ? Icons.star : Icons.person, size: 18, color: Colors.white),
                    ),
                    title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${m.role} • ${m.contact}'),
                  ),
                );
              }),
              const SizedBox(height: 20),
              // Audit log (FR-17)
              StreamBuilder<List<TeamChange>>(
                stream: repo.watchTeamChanges(team.id),
                builder: (context, cSnapshot) {
                  final changes = cSnapshot.data ?? [];
                  if (changes.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13131A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF232334)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Audit Log',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF8888AA)),
                        ),
                        const SizedBox(height: 6),
                        ...changes.map((c) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '• ${c.changeType.name}: ${c.entityLabel} (${c.oldValue} -> ${c.newValue})',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                              ),
                            )),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
