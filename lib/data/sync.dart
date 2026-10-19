
enum SyncStatus { offline, syncing, synced, error }

abstract interface class SyncRepository {
  Future<void> onMutation();
  Future<SyncStatus> syncNow();
  Stream<SyncStatus> get statusStream;
}

/// FR-25 stub: local-only, always returns offline. The sync seam is designed
/// for FR-25/FR-26 (accounts + merge) but not built in v1.0.
class LocalOnlySyncRepository implements SyncRepository {
  @override
  Future<void> onMutation() async {}

  @override
  Future<SyncStatus> syncNow() async => SyncStatus.offline;

  @override
  Stream<SyncStatus> get statusStream =>
      Stream<SyncStatus>.value(SyncStatus.offline);
}
