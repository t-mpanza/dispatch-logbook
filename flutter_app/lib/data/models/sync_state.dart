enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  offline,
}

class SyncState {
  final SyncStatus status;
  final int? lastSyncedAt;
  final int pendingCount;
  final String? errorMessage;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.errorMessage,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? lastSyncedAt,
    int? pendingCount,
    String? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
