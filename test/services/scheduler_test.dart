import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/services/scheduler.dart';
import 'package:hackathon_manager/services/prefs_test_impl.dart';

class FakeNotifier implements Notifier {
  final List<String> scheduled = [];
  final List<String> cancelled = [];
  final List<String> shown = [];
  DateTime? lastFireAt;

  @override
  Future<void> schedule({required String key, required DateTime fireAt, required String title,
      required String body, required Priority priority}) async {
    scheduled.add(key);
    lastFireAt = fireAt;
  }
  @override
  Future<void> cancel(String key) async => cancelled.add(key);
  @override
  Future<void> show({required String key, required String title, required String body,
      required Priority priority}) async {
    shown.add(key);
  }
}

void main() {
  late AppDatabase db;
  late Repository repo;
  late FakeNotifier notifier;
  late NotificationScheduler scheduler;

  setUp(() async {
    db = AppDatabase();
    repo = Repository(db);
    notifier = FakeNotifier();
    scheduler = NotificationScheduler(repo: repo, notifier: notifier, prefs: InMemoryPrefs());
  });

  tearDown(() => db.close());

  Hackathon _h() => Hackathon(
        id: -1, name: 'Alpha', organizer: 'Org', url: '', mode: HackathonMode.online,
        location: '', organizerTimezone: 'UTC', status: HackathonStatus.upcoming,
        createdAt: DateTime.utc(2026, 10, 17), modifiedAt: DateTime.utc(2026, 10, 17),
      );

  Milestone _m(int hid) {
    final now = DateTime.now().toUtc();
    return Milestone(
      id: -1, hackathonId: hid, label: MilestoneLabel.finalSubmission, title: 'Submit',
      endsAtUtc: now.add(const Duration(days: 10)), timezone: 'UTC', isCritical: true,
      verified: false, createdAt: now, modifiedAt: now,
    );
  }

  test('planAll schedules a reminder for each milestone', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    expect(notifier.scheduled, contains('m${m.id}#0'));
  });

  test('markDone persists the transition and cancels the alarm', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    await scheduler.markDone('m${m.id}#0');
    final row = await repo.reminder('m${m.id}#0');
    expect(row!.state, ReminderState.done);
  });

  test('skip is terminal', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    await scheduler.skip('m${m.id}#0');
    expect((await repo.reminder('m${m.id}#0'))!.state, ReminderState.skipped);
  });

  test('replanForMilestone reschedules with new fire times', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    final before = notifier.scheduled.length;
    await repo.saveMilestone(m.copyWith(endsAtUtc: m.endsAtUtc.add(const Duration(days: 1))));
    await scheduler.replanForMilestone(m.id);
    // Old alarms cancelled, new ones scheduled.
    expect(notifier.cancelled, isNotEmpty);
    expect(notifier.scheduled.length, greaterThan(before));
  });

  test('pendingReminders returns only future, non-terminal rows', () async {
    final h = await repo.saveHackathon(_h());
    final m = await repo.saveMilestone(_m(h.id));
    await scheduler.planAll();
    await scheduler.skip('m${m.id}#0');
    final pending = await scheduler.pendingReminders();
    expect(pending.any((r) => r.key == 'm${m.id}#0'), isFalse);
  });
}
