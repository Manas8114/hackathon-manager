import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/ui/app.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/services/prefs_test_impl.dart';
import 'package:hackathon_manager/services/scheduler.dart' as sched;
import 'package:hackathon_manager/services/scheduler.dart' show NotificationScheduler;
import 'package:hackathon_manager/providers/app_providers.dart';

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
  testWidgets('app shell renders the four destinations', (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    final notifier = _NullNotifier();
    final scheduler = NotificationScheduler(repo: repo, notifier: notifier, prefs: InMemoryPrefs());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        repoProvider.overrideWithValue(repo),
        schedulerProvider.overrideWithValue(scheduler),
        prefsProvider.overrideWithValue(InMemoryPrefs()),
      ],
      child: const HackathonManagerApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await db.close();
  });
}
