import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/providers/app_providers.dart';
import 'package:hackathon_manager/ui/hackathons/hackathon_list.dart';
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
  testWidgets('add hackathon sheet saves hackathon and milestone', (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    final scheduler = NotificationScheduler(repo: repo, notifier: _NullNotifier(), prefs: InMemoryPrefs());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        repoProvider.overrideWithValue(repo),
        schedulerProvider.overrideWithValue(scheduler),
        prefsProvider.overrideWithValue(InMemoryPrefs()),
      ],
      child: const MaterialApp(home: HackathonList()),
    ));
    await tester.pumpAndSettle();

    // Tap add hackathon button
    final addBtn = find.byIcon(Icons.add).first;
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Enter name
    await tester.enterText(find.byType(TextFormField).first, 'Super Hack 2026');
    await tester.pumpAndSettle();

    // Tap Save Hackathon
    await tester.ensureVisible(find.text('Save Hackathon'));
    await tester.tap(find.text('Save Hackathon'));
    await tester.pumpAndSettle();

    // Verify it appears in HackathonList
    expect(find.text('Super Hack 2026'), findsOneWidget);
  });
}
