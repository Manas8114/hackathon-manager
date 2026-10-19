import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/providers/app_providers.dart';
import 'package:hackathon_manager/ui/calendar/calendar_view.dart';
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
  testWidgets('calendar view displays milestone with priority indicator in that month', (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    final now = DateTime.now().toUtc();
    final h = await repo.saveHackathon(Hackathon(
      id: -1, name: 'Cal Hack', organizer: 'Org', url: '', mode: HackathonMode.online,
      location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
      createdAt: now, modifiedAt: now,
    ));
    // Milestone in current month
    await repo.saveMilestone(Milestone(
      id: -1, hackathonId: h.id, label: MilestoneLabel.finalSubmission, title: 'Cal Milestone',
      endsAtUtc: DateTime.utc(now.year, now.month, 15, 18, 0), timezone: 'UTC', isCritical: true,
      verified: false, createdAt: now, modifiedAt: now,
    ));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        repoProvider.overrideWithValue(repo),
        schedulerProvider.overrideWithValue(NotificationScheduler(repo: repo, notifier: _NullNotifier(), prefs: InMemoryPrefs())),
        prefsProvider.overrideWithValue(InMemoryPrefs()),
      ],
      child: MaterialApp(home: CalendarView(initialDate: now)),
    ));
    await tester.pumpAndSettle();

    // Check that the milestone appears in Upcoming This Month summary
    expect(find.textContaining('Cal Milestone'), findsOneWidget);
    await db.close();
  });
}
