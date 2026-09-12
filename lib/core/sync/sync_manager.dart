import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import 'sync_state_notifier.dart';

/// Central singleton coordinator for automatic background synchronization.
/// Listens to network connectivity transitions and database queue events.
class SyncManager {
  static final SyncManager instance = SyncManager._internal();
  SyncManager._internal();

  /// Reactive notifier incremented whenever cloud sync modifies local data.
  final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _debounceTimer;
  SyncStateNotifier? _notifier;
  Connectivity? _connectivity;
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  /// Notifies listeners that local SQLite tables have been refreshed from cloud.
  void notifyDataChanged() {
    dataVersion.value++;
  }

  /// Initializes connectivity listener and hooks database queue changes.
  void initialize({
    required SyncStateNotifier notifier,
    Connectivity? connectivity,
  }) {
    _notifier = notifier;
    _connectivity = connectivity ?? Connectivity();

    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to device connectivity changes
    _connectivitySubscription = _connectivity!.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      _handleConnectivityChange(online);
    });

    // Check initial connectivity status
    _connectivity!.checkConnectivity().then((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      _handleConnectivityChange(online);
      if (online) {
        // Initial auto-sync shortly after launch if pending items exist
        scheduleAutoSync(delay: const Duration(seconds: 2));
      }
    }).catchError((_) {
      _handleConnectivityChange(true);
    });

    // Hook into database queue changes
    DatabaseHelper.instance.onQueueChanged = () {
      _notifier?.refreshPendingCount();
      scheduleAutoSync();
    };
  }

  void _handleConnectivityChange(bool online) {
    final wasOffline = !_isOnline && online;
    _isOnline = online;
    _notifier?.updateOnlineStatus(online);

    if (wasOffline) {
      // Reconnected from offline -> trigger sync
      scheduleAutoSync(delay: const Duration(milliseconds: 800));
    }
  }

  /// Schedules a debounced background sync (default 1.5s debounce).
  void scheduleAutoSync({Duration delay = const Duration(milliseconds: 1500)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      triggerSync(silent: true);
    });
  }

  /// Triggers background or manual synchronization.
  Future<void> triggerSync({bool silent = true}) async {
    if (_isSyncing) return;
    if (_notifier == null) return;

    if (!_isOnline) {
      await _notifier!.refreshPendingCount();
      return;
    }

    _isSyncing = true;
    try {
      await _notifier!.syncNow(silent: silent);
    } catch (_) {
      // Suppress any uncaught network exceptions in background sync
    } finally {
      _isSyncing = false;
    }
  }

  /// Disposes timers and stream subscriptions.
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    DatabaseHelper.instance.onQueueChanged = null;
    _isInitialized = false;
  }
}
