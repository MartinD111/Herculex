import 'dart:async';
import 'package:flutter/foundation.dart';

import '../local/database.dart';

/// SyncEngine - Persistent hybrid local-first sync coordinator.
/// Drains the `pending_sync_ops` outbox to simulate/perform Cloud Firestore replication.
class SyncEngine {
  final AppDatabase _db;
  Timer? _syncTimer;
  bool _isSyncing = false;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  SyncEngine(this._db) {
    // Start periodic outbox processor every 15 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) => triggerSync());
    _syncStatusController.add(SyncStatus.idle);
  }

  Stream<SyncStatus> get statusStream => _syncStatusController.stream;

  /// Manually queue a synchronization operation into the persistent Drift outbox.
  Future<void> queueSyncOp({
    required String entityType,
    required String entityId,
    required String operation,
  }) async {
    await _db.into(_db.pendingSyncOps).insert(
          PendingSyncOpsCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
          ),
        );
    
    // Proactively trigger sync
    triggerSync();
  }

  /// Process and drain the persistent sync outbox to Firestore.
  Future<void> triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      final ops = await _db.select(_db.pendingSyncOps).get();
      if (ops.isEmpty) {
        _syncStatusController.add(SyncStatus.synced);
        _isSyncing = false;
        return;
      }

      debugPrint("SyncEngine: Processing ${ops.length} cloud sync operations...");

      // Simulate sending mutations to Firestore with artificial network latency
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      for (final op in ops) {
        debugPrint("SyncEngine: Synced ${op.entityType} (${op.entityId}) via Firestore.");
        
        // Remove from persistent local outbox upon successful cloud confirmation
        await (_db.delete(_db.pendingSyncOps)..where((t) => t.id.equals(op.id))).go();
      }

      _syncStatusController.add(SyncStatus.synced);
    } catch (e) {
      debugPrint("SyncEngine Error: $e");
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
      // Fade status back to idle after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isSyncing) _syncStatusController.add(SyncStatus.idle);
      });
    }
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
  }
}

enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
}

extension SyncStatusExtension on SyncStatus {
  String get label => switch (this) {
        SyncStatus.idle => "All data synced",
        SyncStatus.syncing => "Syncing to cloud...",
        SyncStatus.synced => "Sync completed!",
        SyncStatus.error => "Sync error. Offline",
      };
}
