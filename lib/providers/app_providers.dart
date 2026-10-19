import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../data/prefs.dart';
import '../data/sync.dart';
import '../services/scheduler.dart' as sched;
import '../services/scheduler.dart' show NotificationScheduler, NullNotifier;

// ─── Core infrastructure ──────────────────────────────────────────────────────

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase(seed: true));

final repoProvider = Provider<Repository>((ref) {
  final db = ref.watch(dbProvider);
  return Repository(db);
});

final prefsProvider = Provider<PrefsStore>((ref) => PrefsStore.inMemory());

final syncProvider = Provider<SyncRepository>((ref) => LocalOnlySyncRepository());

final notifierProvider = Provider<sched.Notifier>((ref) => NullNotifier());

final schedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(
    repo: ref.watch(repoProvider),
    notifier: ref.watch(notifierProvider),
    prefs: ref.watch(prefsProvider),
  );
});
