import 'package:flutter/foundation.dart';
import '../models/entry.dart';
import '../models/sync_state.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

class EntryRepository extends ChangeNotifier {
  SyncState _syncState = const SyncState();
  SyncState get syncState => _syncState;

  bool _isSyncRunning = false;

  void _setSyncState(SyncState state) {
    _syncState = state;
    notifyListeners();
  }

  Future<List<Entry>> getAllEntries() async {
    return await DatabaseService.getAllEntries();
  }

  Future<List<Entry>> getEntriesByDay(String dayKey) async {
    return await DatabaseService.getEntriesByDay(dayKey);
  }

  Future<Entry?> getEntryById(String id) async {
    return await DatabaseService.getEntryById(id);
  }

  Future<void> saveEntry(Entry entry, {bool triggerPush = true}) async {
    final updated = entry.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseService.insertOrUpdateEntry(updated);
    notifyListeners();

    if (triggerPush) {
      // Non-blocking cloud push
      SupabaseService.pushEntriesBatch([updated]).then((success) {
        if (success) {
          SupabaseService.broadcastEntryChange(updated.id);
        }
      });
    }
  }

  Future<void> deleteEntry(String id) async {
    // Soft-delete locally (tombstone), then propagate the tombstone to the
    // cloud so the entry never resurrects on other devices.
    await DatabaseService.softDeleteEntry(id);
    notifyListeners();
    try {
      await SupabaseService.deleteRemoteEntry(id);
    } catch (e) {
      debugPrint('Remote tombstone push failed for $id: $e');
    }
  }

  Future<List<Entry>> search(String query) async {
    return await DatabaseService.searchEntries(query);
  }

  Future<List<String>> getAllTags() async {
    return await DatabaseService.getAllTags();
  }

  // ── Full Two-Way Synchronization ───────────────────────────────────────────

  Future<bool> syncNow() async {
    if (_isSyncRunning) return false;
    _isSyncRunning = true;
    _setSyncState(_syncState.copyWith(
      status: SyncStatus.syncing,
      errorMessage: null,
    ));

    try {
      // 1. Push all live local entries
      final local = await DatabaseService.getAllEntries();
      if (local.isNotEmpty) {
        await SupabaseService.pushEntriesBatch(local);
      }

      // 2. Push local delete-tombstones so deletions propagate cross-device
      await SupabaseService.pushTombstones();

      // 3. Pull remote entries & merge (tombstone-aware)
      final success = await SupabaseService.pullAndMerge();

      if (success) {
        _setSyncState(_syncState.copyWith(
          status: SyncStatus.synced,
          lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
          pendingCount: 0,
          errorMessage: null,
        ));
      } else {
        _setSyncState(_syncState.copyWith(
          status: SyncStatus.error,
          errorMessage: 'Sync partially failed or network unavailable',
        ));
      }

      _isSyncRunning = false;
      notifyListeners();
      return success;
    } catch (e) {
      _setSyncState(_syncState.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      ));
      _isSyncRunning = false;
      notifyListeners();
      return false;
    }
  }

  void initRealtime() {
    SupabaseService.setupRealtimeSync(() {
      notifyListeners();
    });
  }
}
