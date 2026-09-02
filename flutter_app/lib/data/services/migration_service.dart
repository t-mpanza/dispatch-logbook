import 'package:sqflite/sqflite.dart';

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
/// 3. De-duplicates entries that represent the same truck (same tripId, same
///    day), keeping the latest/richest record and tombstoning stale copies.
///
/// Only live (non-tombstoned) entries are touched, so previously deleted
/// data can never be resurrected by the migration. Everything is computed
/// first and then written in a single transaction.
class MigrationService {
  static const String _flagKey = 'migration_ungroup_dedupe_v1';

  static Future<void> runIfNeeded() async {
    final done = await DatabaseService.getSetting(_flagKey);
    if (done == '1') return;

    try {
      await _migrate();
    } catch (e) {
      // Migration must never brick the app; surface and continue.
      debugPrintMigration('migration failed (continuing): $e');
      return;
    }

    await DatabaseService.saveSetting(_flagKey, '1');
  }

  static String _normTripId(String? s) => (s ?? '').trim().toUpperCase();

  static String _groupKey(String dayKey, String tripId) =>
      '${dayKey.toUpperCase()}|${_normTripId(tripId)}';

  static void debugPrintMigration(String msg) {
    // ignore: avoid_print
    print('[MigrationService] $msg');
  }

  static Future<void> _migrate() async {
    final db = await DatabaseService.database;

    // Step 0: read ALL live entries with their raw rows (we need raw maps
    // for row-level writes and models for the pure logic).
    final rawMaps = await db.query('entries', where: 'deleted_at IS NULL');
    final liveEntries = rawMaps.map((m) => Entry.fromMap(m)).toList();

    // ── Phase 1: split squashed entries ────────────────────────────────────
    final splits = _planSplits(liveEntries);
    // ── Phase 2: reconcile counts ──────────────────────────────────────────
    final reconciled = _planReconcile(liveEntries);
    // ── Phase 3: dedupe by day+tripId ──────────────────────────────────────
    final dedupe = _planDedupe(liveEntries);

    if (splits.isEmpty && reconciled.isEmpty && dedupe.isEmpty) return;

    await db.transaction((txn) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (final s in splits) {
        await txn.update(
          'entries',
          s.original.toMap(),
          where: 'id = ?',
          whereArgs: [s.original.id],
        );
        for (final fresh in s.freshEntries) {
          await txn.insert('entries', fresh.toMap());
        }
      }

      for (final entry in reconciled) {
        await txn.update(
          'entries',
          entry.toMap(),
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }

      for (final d in dedupe) {
        await txn.update(
          'entries',
          d.winner.copyWith(
            loadingSheetTrips: d.mergedTrips,
            updatedAt: nowMs,
          ).toMap(),
          where: 'id = ?',
          whereArgs: [d.winner.id],
        );
        for (final loser in d.losers) {
          await txn.update(
            'entries',
            {'deleted_at': nowMs},
            where: 'id = ?',
            whereArgs: [loser.id],
          );
        }
      }

      await txn.insert(
        'settings',
        {'key': _flagKey, 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    debugPrintMigration(
      'migrated: ${splits.length} splits, ${reconciled.length} reconciles, '
      '${dedupe.fold<int>(0, (s, d) => s + d.losers.length)} tombstones',
    );
  }

  // ── Phase 1 plan ──────────────────────────────────────────────────────────

  static List<_Split> _planSplits(List<Entry> liveEntries) {
    final splits = <_Split>[];
    for (final e in liveEntries) {
      final trips = e.loadingSheetTrips ?? [];
      if (trips.length <= 1) continue;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final freshEntries = <Entry>[];

      for (var i = 1; i < trips.length; i++) {
        final trip = trips[i];
        final presetName = trip.presetKey?.name.toLowerCase();
        final newId = IdGenerator.generate();
        freshEntries.add(
          Entry(
            id: newId,
            title: trip.tripId.isNotEmpty ? trip.tripId : 'Truck Load',
            tags: [
              'despatch',
              if (presetName != null && presetName != 'custom') presetName,
            ],
            expectedTotal:
                (trip.targetQuantity != null && trip.targetQuantity! > 0)
                    ? trip.targetQuantity
                    : null,
            notes: const [],
            attachments: const [],
            trips: const [],
            loadingSheetTrips: [trip.copyWith(entryId: newId)],
            createdAt: trip.createdAt > 0 ? trip.createdAt : e.createdAt,
            updatedAt: nowMs,
            dayKey: e.dayKey,
            monthKey: e.monthKey,
            yearKey: e.yearKey,
          ),
        );
      }

      splits.add(
        _Split(
          original: e.copyWith(
            loadingSheetTrips: [trips.first],
            updatedAt: nowMs,
          ),
          freshEntries: freshEntries,
        ),
      );
    }
    return splits;
  }

  // ── Phase 2 plan ──────────────────────────────────────────────────────────

  static List<Entry> _planReconcile(List<Entry> liveEntries) {
    final reconciled = <Entry>[];
    for (final e in liveEntries) {
      final sheetTrips = e.loadingSheetTrips ?? [];
      if (sheetTrips.isEmpty) continue;

      final trips = e.trips ?? [];
      final counterTotal =
          trips.fold<int>(0, (s, t) => s + t.count + (t.rejected ?? 0));

      var changed = false;
      final updated = sheetTrips.map((t) {
        if (t.hasIbtDocuments) {
          final ibtLoaded = t.ibtLoadedTotal;
          if (t.quantityLoaded != ibtLoaded) {
            changed = true;
            return t.copyWith(
              quantityLoaded: ibtLoaded,
              targetQuantity: t.targetQuantity ?? t.ibtTargetTotal,
            );
          }
          return t;
        }
        if (!t.isManual && trips.isNotEmpty && t.quantityLoaded != counterTotal) {
          changed = true;
          return t.copyWith(quantityLoaded: counterTotal);
        }
        return t;
      }).toList();

      if (changed) {
        reconciled.add(e.copyWith(loadingSheetTrips: updated));
      }
    }
    return reconciled;
  }

  // ── Phase 3 plan ──────────────────────────────────────────────────────────

  /// Entries whose (non-manual) loading-sheet trip resolves to the same
  /// tripId on the same day represent the same truck. Keep the latest /
  /// richest record, merge its data, tombstone the rest.
  static List<_Dedupe> _planDedupe(List<Entry> liveEntries) {
    final groups = <String, List<(Entry, LoadingSheetTrip)>>{};
    for (final e in liveEntries) {
      for (final t in e.loadingSheetTrips ?? []) {
        if (t.isManual) continue; // manual rows are unique adds, never merged
        if (_normTripId(t.tripId).isEmpty) continue;
        groups
            .putIfAbsent(_groupKey(e.dayKey, t.tripId), () => [])
            .add((e, t));
      }
    }

    final dedupes = <_Dedupe>[];
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
        if ((mergedTrip.ibtDocuments == null ||
                mergedTrip.ibtDocuments!.isEmpty) &&
            mergedTrip.quantityLoaded <= 0 &&
            lt.quantityLoaded > 0) {
          mergedTrip = mergedTrip.copyWith(quantityLoaded: lt.quantityLoaded);
        }
        if (mergedTrip.startTime == null && lt.startTime != null) {
          mergedTrip = mergedTrip.copyWith(startTime: lt.startTime);
        }
        if (mergedTrip.finishTime == null && lt.finishTime != null) {
          mergedTrip = mergedTrip.copyWith(finishTime: lt.finishTime);
        }
        if (mergedTrip.reg.isEmpty && lt.reg.isNotEmpty) {
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

      final key = _groupKey(winner.$1.dayKey, mergedTrip.tripId);
      final mergedTrips = [...?mergedEntry.loadingSheetTrips]
        ..removeWhere((t) => _groupKey(mergedEntry.dayKey, t.tripId) == key)
        ..add(mergedTrip);

      dedupes.add(
        _Dedupe(
          winner: mergedEntry,
          mergedTrips: mergedTrips,
          losers: losers.map((l) => l.$1).toList(),
        ),
      );
    }
    return dedupes;
  }
}

class _Split {
  final Entry original;
  final List<Entry> freshEntries;

  const _Split({required this.original, required this.freshEntries});
}

class _Dedupe {
  final Entry winner;
  final List<LoadingSheetTrip> mergedTrips;
  final List<Entry> losers;

  const _Dedupe({
    required this.winner,
    required this.mergedTrips,
    required this.losers,
  });
}
