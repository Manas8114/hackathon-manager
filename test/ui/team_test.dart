import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/providers/app_providers.dart';
import 'package:hackathon_manager/ui/team/my_teams_view.dart';
import 'package:hackathon_manager/services/prefs_test_impl.dart';
import 'package:hackathon_manager/services/scheduler.dart' as sched;
import 'package:hackathon_manager/services/scheduler.dart' show NotificationScheduler;

class _NullNotifier implements sched.Notifier {
  @override
  Future<void> schedule({required String key, required DateTime fireAt, required String title,
      required String body, required Priority priority}) async {}
  @override
  Future<void> cancel(String key) async {}
  @override
  Future<void> show({required String key, required String title, required String body,
      required Priority priority}) async {}
}

void main() {
  testWidgets('my teams view lists hackathon, team, status, and next deadline', (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    final now = DateTime.now().toUtc();
    final h = await repo.saveHackathon(Hackathon(
      id: -1, name: 'Alpha', organizer: 'Org', url: '', mode: HackathonMode.online,
      location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
      createdAt: now, modifiedAt: now,
    ));
    await repo.saveMilestone(Milestone(
      id: -1, hackathonId: h.id, label: MilestoneLabel.finalSubmission, title: 'Submit',
      endsAtUtc: now.add(const Duration(days: 5)), timezone: 'UTC', isCritical: true,
      verified: false, createdAt: now, modifiedAt: now,
    ));
    await repo.saveTeam(Team(
      id: -1, hackathonId: h.id, name: 'Night Owls', status: TeamStatus.confirmed,
      ideaTitle: 'Sleep app', techStack: 'Flutter', repoUrl: '', chatUrl: '', notes: '',
      createdAt: now, modifiedAt: now,
    ));
    await tester.pumpWidget(ProviderScope(overrides: [
      repoProvider.overrideWithValue(repo),
      schedulerProvider.overrideWithValue(NotificationScheduler(repo: repo, notifier: _NullNotifier(), prefs: InMemoryPrefs())),
      prefsProvider.overrideWithValue(InMemoryPrefs()),
    ], child: const MaterialApp(home: MyTeamsView())));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Night Owls'), findsWidgets);
    expect(find.text('Confirmed'), findsWidgets);
    await db.close();
  });

  testWidgets('a second confirmed team for the same hackathon warns', (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    final now = DateTime.now().toUtc();
    final h = await repo.saveHackathon(Hackathon(
      id: -1, name: 'Alpha', organizer: 'Org', url: '', mode: HackathonMode.online,
      location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
      createdAt: now, modifiedAt: now,
    ));
    for (final name in ['Night Owls', 'Second Team']) {
      await repo.saveTeam(Team(
        id: -1, hackathonId: h.id, name: name, status: TeamStatus.confirmed,
        ideaTitle: '', techStack: '', repoUrl: '', chatUrl: '', notes: '',
        createdAt: now, modifiedAt: now,
      ));
    }
    await tester.pumpWidget(ProviderScope(overrides: [
      repoProvider.overrideWithValue(repo),
      schedulerProvider.overrideWithValue(NotificationScheduler(repo: repo, notifier: _NullNotifier(), prefs: InMemoryPrefs())),
      prefsProvider.overrideWithValue(InMemoryPrefs()),
    ], child: const MaterialApp(home: MyTeamsView())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Another confirmed team'), findsOneWidget);
    await db.close();
  });
}
