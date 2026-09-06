import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_service.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.errorMessage,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage,
    );
  }
}

/// Provider for the SyncService instance
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    endpointUrl: '', // Default blank; configured by app settings or env
  );
});

/// StateNotifier to coordinate and monitor background/manual synchronization
class SyncStateNotifier extends StateNotifier<SyncState> {
  final SyncService _syncService;

  SyncStateNotifier(this._syncService) : super(const SyncState()) {
    refreshPendingCount();
  }

  /// Refreshes the local pending queue count
  Future<void> refreshPendingCount() async {
    try {
      final pendingItems = await _syncService.dbHelper.getPendingSyncItems();
      state = state.copyWith(
        pendingCount: pendingItems.length,
      );
    } catch (_) {
      // Ignore database read error on initial count refresh
    }
  }

  /// Triggers immediate synchronization of pending queue items
  Future<SyncResult> syncNow() async {
    if (state.status == SyncStatus.syncing) {
      return const SyncResult(
        isSuccess: false,
        syncedCount: 0,
        errorMessage: 'Sinkronisasi sedang berjalan',
      );
    }

    state = state.copyWith(
      status: SyncStatus.syncing,
      errorMessage: null,
    );

    final result = await _syncService.syncPending();

    final remainingItems = await _syncService.dbHelper.getPendingSyncItems();

    if (result.isSuccess) {
      state = state.copyWith(
        status: SyncStatus.success,
        pendingCount: remainingItems.length,
        lastSyncedAt: DateTime.now(),
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        status: SyncStatus.error,
        pendingCount: remainingItems.length,
        errorMessage: result.errorMessage,
      );
    }

    return result;
  }
}

/// Provider for SyncStateNotifier
final syncStateProvider = StateNotifierProvider<SyncStateNotifier, SyncState>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return SyncStateNotifier(syncService);
});
