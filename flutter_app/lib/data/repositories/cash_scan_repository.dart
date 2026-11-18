import 'package:sqflite/sqflite.dart';

/// The persisted cash-scan log — the cross-session double-scan guard
/// (audit #3). A tyre committed as cash stays known-loaded in SQLite
/// until it is OFFLOADED, so re-scanning it tomorrow still opens the
/// offload window instead of silently double-committing.
class CashScanRepository {
  CashScanRepository(this._db);

  final DatabaseExecutor _db;

  Future<void> record(String uid, String documentNo) async {
    await _db.insert(
      'cash_scans',
      {
        'uid': uid,
        'document_no': documentNo,
        'at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isRecorded(String uid) async {
    final rows = await _db.query(
      'cash_scans',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<String?> documentNoFor(String uid) async {
    final rows = await _db.query(
      'cash_scans',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['document_no'] as String?;
  }

  Future<Set<String>> recordedUids() async {
    final rows = await _db.query('cash_scans', columns: ['uid']);
    return rows.map((r) => r['uid'] as String).toSet();
  }

  Future<void> remove(String uid) async {
    await _db.delete('cash_scans', where: 'uid = ?', whereArgs: [uid]);
  }
}
