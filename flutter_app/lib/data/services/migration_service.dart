import 'dart:convert';

import '../../core/utils/id_generator.dart';
import '../models/entry.dart';
import '../models/loading_sheet_trip.dart';
import 'database_service.dart';

/// One-time startup migrations that repair legacy data so the Home (Today)
/// tab and the Sheet tab always agree.
///
/// 1. Splits "squashed" entries (one entry holding many trucks) into one
///    discrete entry per truck — enforcing the 1 Entry = 1 Truck invariant.
/// 2. Reconciles quantityLoaded / targetQuantity against counter trips and
///    IBT manifest totals (fixes inflated counts like "177 / 78").
/// 3. De-duplicates entries that represent the same truck (same tripId),
///    keeping the latest/richest record and tombstoning the stale copies.
class MigrationService {
  static const String _flagKey = 'migration_ungroup_dedupe_v1';

  static Future<void> runIfNeeded() async {
    final done = await DatabaseService.getSetting(_flagKey);
    if (done == '1') return;

    try {
      await _splitSquashedEntries();
      await _reconcileCounts();
      await _dedupeByTripId();
    } catch (e) {
      // Migration must never brick the app; surface and continue.
      debugPrintMigration('migration failed (continuing): $e');
      return;
    }

    await DatabaseService.saveSetting(_flagKey, '1');
  }

  static String _normTripId(String? s) => (s ?? '').trim().toUpperCase();

  static void debugPrintMigration(String msg) {
    // ignore: avoid_print
    print('[MigrationService] $msg');
  }

  /// Entries that contain more than one loading-sheet trip get split:
  /// the original entry keeps the first trip, and each remaining trip
  /// becomes its own entry.
  static Future<void> _splitSquashedEntries() async {
    final db = await DatabaseService.database;
    final maps = await db.query('entries');

    var splitCount = 0;
    for (final map in maps) {
      final loadingJson = map['loading_sheet_trips'] as String?;
      if (loadingJson == null ||
          loadingJson.isEmpty ||
          loadingJson == '[]' ||
          loadingJson == 'null') {
        continue;
      }

      final List<dynamic> list;
      try {
        final decoded = jsonDecode(loadingJson);
        if (decoded is! List) continue;
        list = decoded;
      } catch (_) {
        continue;
      }
      if (list.length <= 1) continue;

      final entryId = map['id'] as String;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Original entry keeps the first trip.
      final firstTrip = list.first;
      final updatedMap = Map<String, dynamic>.from(map);
      updatedMap['loading_sheet_trips'] = jsonEncode([firstTrip]);
      updatedMap['updated_at'] = nowMs;
      await db.update('entries', updatedMap,
          where: 'id = ?', whereArgs: [entryId]);

      for (var i = 1; i < list.length; i++) {
        final tripMap = Map<String, dynamic>.from(list[i] as Map);
        final tripId = (tripMap['tripId'] as String?) ?? '';
        final presetKey = (tripMap['presetKey'] as String?)?.toLowerCase();

        final newMap = Map<String, dynamic>.from(map);
        newMap['id'] = IdGenerator.generate();
        newMap['title'] = tripId.isNotEmpty ? tripId : 'Truck Load';
        newMap['loading_sheet_trips'] = jsonEncode([tripMap]);
        newMap['trips'] = jsonEncode(<dynamic>[]);
        newMap['notes'] = jsonEncode(<dynamic>[]);
        newMap['attachments'] = jsonEncode(<dynamic>[]);
        newMap['tags'] = jsonEncode([
          'despatch',
          if (presetKey != null && presetKey != 'custom') presetKey,
        ]);
        newMap['expected_total'] = (tripMap['targetQuantity'] as num?)?.toInt();
        final tripCreatedAt = (tripMap['createdAt'] as num?)?.toInt();
        if (tripCreatedAt != null && tripCreatedAt > 0) {
          newMap['created_at'] = tripCreatedAt;
        }
        newMap['updated_at'] = nowMs;
        newMap['deleted_at'] = null;
        await db.insert('entries', newMap);
        splitCount++;
      }
    }

    if (splitCount > 0) {
      debugPrintMigration('split $splitCount squashed trips into own entries');
    }
  }

  /// Reconcile per-trip counters against the actual data:
  /// - IBT trips: quantityLoaded must equal the sum of IBT loaded totals.
  /// - Counter trips: quantityLoaded must equal the sum of trip counts.
  static Future<void> _reconcileCounts() async {
    final all = await DatabaseService.getAllEntries();
    var fixedCount = 0;

    for (final e in all) {
      final sheetTrips = e.loadingSheetTrips ?? [];
      if (sheetTrips.isEmpty) continue;

      final trips = e.trips ?? [];
      final counterTotal =
          trips.fold<int>(0, (s, t) => s + t.count + (t.rejected ?? 0));

      final updated = sheetTrips.map((t) {
        if (t.hasIbtDocuments) {
          final ibtLoaded = t.ibtLoadedTotal;
          if (t.quantityLoaded != ibtLoaded) {
            return t.copyWith(
              quantityLoaded: ibtLoaded,
              targetQuantity: t.targetQuantity ?? t.ibtTargetTotal,
            );
          }
          return t;
        }
        if (!t.isManual && trips.isNotEmpty && t.quantityLoaded != counterTotal) {
          return t.copyWith(quantityLoaded: counterTotal);
        }
        return t;
      }).toList();

      var changed = false;
      for (var i = 0; i < sheetTrips.length; i++) {
        if (!identical(sheetTrips[i], updated[i])) changed = true;
      }
      if (!changed) continue;

      await DatabaseService.insertOrUpdateEntry(
        e.copyWith(loadingSheetTrips: updated),
      );
      fixedCount++;
    }

    if (fixedCount > 0) {
      debugPrintMigration('reconciled counts on $fixedCount entries');
    }
  }

  /// Entries whose loading-sheet trip has the same tripId represent the same
  /// truck. Keep the latest/richest one, merge its data, tombstone the rest.
  static Future<void> _dedupeByTripId() async {
    final all = await DatabaseService.getAllEntries();

    final Map<String, List<(Entry, LoadingSheetTrip)>> groups = {};
    for (final e in all) {
      for (final t in e.loadingSheetTrips ?? []) {
        final key = _normTripId(t.tripId);
        if (key.isEmpty) continue;
        groups.putIfAbsent(key, () => []).add((e, t));
      }
    }

    var dedupeCount = 0;
    for (final group in groups.values) {
      if (group.length <= 1) continue;

      group.sort((a, b) {
        final c = b.$1.updatedAt.compareTo(a.$1.updatedAt);
        if (c != 0) return c;
        final bi = b.$2.ibtDocuments?.length ?? 0;
        final ai = a.$2.ibtDocuments?.length ?? 0;
        if (bi != ai) return bi.compareTo(ai);
        return b.$1.attachments.length.compareTo(a.$1.attachments.length);
      });

      final winner = group.first;
      final losers = group.sublist(1);

      var mergedTrip = winner.$2;
      var mergedEntry = winner.$1;

      for (final loser in losers) {
        final lt = loser.$2;
        if ((mergedTrip.ibtDocuments == null ||
                mergedTrip.ibtDocuments!.isEmpty) &&
            lt.ibtDocuments != null &&
            lt.ibtDocuments!.isNotEmpty) {
          mergedTrip = mergedTrip.copyWith(ibtDocuments: lt.ibtDocuments);
        }
        if (mergedTrip.targetQuantity == null && lt.targetQuantity != null) {
          mergedTrip = mergedTrip.copyWith(targetQuantity: lt.targetQuantity);
        }
        if (mergedTrip.quantityLoaded <= 0 && lt.quantityLoaded > 0) {
          mergedTrip = mergedTrip.copyWith(quantityLoaded: lt.quantityLoaded);
        }
        if (mergedTrip.startTime == null && lt.startTime != null) {
          mergedTrip = mergedTrip.copyWith(startTime: lt.startTime);
        }
        if (mergedTrip.finishTime == null && lt.finishTime != null) {
          mergedTrip = mergedTrip.copyWith(finishTime: lt.finishTime);
        }
        if ((mergedTrip.reg.isEmpty) && lt.reg.isNotEmpty) {
          mergedTrip = mergedTrip.copyWith(reg: lt.reg);
        }
        if (mergedTrip.driverName.isEmpty && lt.driverName.isNotEmpty) {
          mergedTrip = mergedTrip.copyWith(driverName: lt.driverName);
        }

        final noteIds = mergedEntry.notes.map((n) => n.id).toSet();
        mergedEntry = mergedEntry.copyWith(
          notes: [
            ...mergedEntry.notes,
            ...loser.$1.notes.where((n) => !noteIds.contains(n.id)),
          ],
        );
        final attIds = mergedEntry.attachments.map((a) => a.id).toSet();
        mergedEntry = mergedEntry.copyWith(
          attachments: [
            ...mergedEntry.attachments,
            ...loser.$1.attachments.where((a) => !attIds.contains(a.id)),
          ],
        );
      }

      final sheetList = [...?mergedEntry.loadingSheetTrips];
      final tripIdx =
          sheetList.indexWhere((t) => _normTripId(t.tripId) == _normTripId(mergedTrip.tripId));
      if (tripIdx >= 0) {
        sheetList[tripIdx] = mergedTrip;
      } else {
        sheetList.add(mergedTrip);
      }

      await DatabaseService.insertOrUpdateEntry(
        mergedEntry.copyWith(
          loadingSheetTrips: sheetList,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      for (final loser in losers) {
        await DatabaseService.softDeleteEntry(loser.$1.id);
      }
      dedupeCount += losers.length;
    }

    if (dedupeCount > 0) {
      debugPrintMigration('deduplicated $dedupeCount stale truck entries');
    }
  }
}
