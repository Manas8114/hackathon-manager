import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_manager/engine/models.dart';
import 'package:hackathon_manager/data/database.dart';
import 'package:hackathon_manager/data/repository.dart';
import 'package:hackathon_manager/providers/app_providers.dart';
import 'package:hackathon_manager/ui/settings/settings_view.dart';
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
  testWidgets('settings view toggles profile and quiet hours and persists them', (tester) async {
    final db = AppDatabase();
    final repo = Repository(db);
    final prefs = InMemoryPrefs();
    final scheduler = NotificationScheduler(repo: repo, notifier: _NullNotifier(), prefs: prefs);

    // Initial pump
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repoProvider.overrideWithValue(repo),
        schedulerProvider.overrideWithValue(scheduler),
        prefsProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: SettingsView()),
    ));
    await tester.pumpAndSettle();

    // Select Intense profile
    await tester.tap(find.text('Intense Profile'));
    await tester.pumpAndSettle();

    // Toggle quiet hours switch
    final switchFinder = find.byType(Switch).first;
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Assert that prefs store persisted the changes
    final savedProfile = await prefs.getProfile();
    expect(savedProfile.id, 'intense');

    final savedQuiet = await prefs.getQuietHours();
    expect(savedQuiet.enabled, isTrue);

    // Re-open/pump settings to assert UI displays persisted state
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repoProvider.overrideWithValue(repo),
        schedulerProvider.overrideWithValue(scheduler),
        prefsProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: SettingsView()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Quiet Period:'), findsOneWidget);
    await db.close();
  });
}
