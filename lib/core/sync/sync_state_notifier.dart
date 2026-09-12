import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_manager.dart';
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
  final bool isOnline;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.errorMessage,
    this.isOnline = true,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool? isOnline,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

/// Provider for the SyncService instance
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    endpointUrl:
        'https://script.google.com/macros/s/AKfycbxLnaF6AG1Ag06TD2MDp0Tws45ZOlVC9NJNdQKmYMGg6gy1OQmJfZVdkuX0hD9xfoz9ug/exec',
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

  /// Updates current network reachability
  void updateOnlineStatus(bool online) {
    state = state.copyWith(isOnline: online);
  }

  /// Triggers immediate or background synchronization of pending queue items.
  /// If [silent] is true, errors revert to [SyncStatus.idle] without surfacing noise.
  Future<SyncResult> syncNow({bool silent = false}) async {
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

    final result = await _syncService.syncTwoWay();

    final remainingItems = await _syncService.dbHelper.getPendingSyncItems();

    if (result.isSuccess) {
      state = state.copyWith(
        status: SyncStatus.success,
        pendingCount: remainingItems.length,
        lastSyncedAt: DateTime.now(),
        errorMessage: null,
      );
      try {
        SyncManager.instance.notifyDataChanged();
      } catch (_) {}
    } else {
      state = state.copyWith(
        status: silent ? SyncStatus.idle : SyncStatus.error,
        pendingCount: remainingItems.length,
        errorMessage: silent ? null : result.errorMessage,
      );
    }

    return result;
  }

  /// Downloads all cloud data and replaces local tables.
  /// Used after reinstall/uninstall to pull the database back into the app.
  Future<RestoreResult> restoreNow() async {
    if (state.status == SyncStatus.syncing) {
      return const RestoreResult(
        isSuccess: false,
        errorMessage: 'Sinkronisasi sedang berjalan',
      );
    }

    state = state.copyWith(
      status: SyncStatus.syncing,
      errorMessage: null,
    );

    final result = await _syncService.restoreFromCloud();

    if (result.isSuccess) {
      state = state.copyWith(
        status: SyncStatus.success,
        pendingCount: 0,
        lastSyncedAt: DateTime.now(),
        errorMessage: null,
      );
      try {
        SyncManager.instance.notifyDataChanged();
      } catch (_) {}
    } else {
      final remainingItems =
          await _syncService.dbHelper.getPendingSyncItems();
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
