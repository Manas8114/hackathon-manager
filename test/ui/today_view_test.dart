import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/providers/app_providers.dart';
import 'package:hackathon_manager/ui/today/today_view.dart';
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

Future<void> _seed(WidgetTester tester, {bool addConfirmedTeam = false}) async {
  final db = AppDatabase();
  final repo = Repository(db);
  final scheduler = NotificationScheduler(repo: repo, notifier: _NullNotifier(), prefs: InMemoryPrefs());
  final now = DateTime.now().toUtc();
  final h = await repo.saveHackathon(Hackathon(
    id: -1, name: 'Alpha Hack', organizer: 'Org', url: '', mode: HackathonMode.online,
    location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
    createdAt: now, modifiedAt: now,
  ));
  await repo.saveMilestone(Milestone(
    id: -1, hackathonId: h.id, label: MilestoneLabel.finalSubmission, title: 'Final submission',
    endsAtUtc: now.add(const Duration(days: 3)), timezone: 'UTC', isCritical: true,
    verified: false, createdAt: now, modifiedAt: now,
  ));
  if (addConfirmedTeam) {
    await repo.saveTeam(Team(
      id: -1,
      hackathonId: h.id,
      name: 'Team Alpha',
      status: TeamStatus.confirmed,
      ideaTitle: 'Cool Idea',
      notes: '',
      createdAt: now,
      modifiedAt: now,
    ));
  }
  await tester.pumpWidget(ProviderScope(overrides: [
    repoProvider.overrideWithValue(repo),
    schedulerProvider.overrideWithValue(scheduler),
    prefsProvider.overrideWithValue(InMemoryPrefs()),
  ], child: const MaterialApp(home: TodayView())));
  await tester.pumpAndSettle();
  expect(find.text('Alpha Hack'), findsWidgets);
}

void main() {
  testWidgets('today view shows the next 7 days of deadlines', (tester) async {
    await _seed(tester);
  });

  testWidgets('today view flags a hackathon without a confirmed team', (tester) async {
    await _seed(tester);
    expect(find.textContaining('No confirmed team'), findsOneWidget);
  });
}
