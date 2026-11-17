import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/staged_document.dart';

/// Thrown when a document number is staged twice on the same truck (D8).
class DuplicateDocumentException implements Exception {
  const DuplicateDocumentException(this.documentNo);

  final String documentNo;

  @override
  String toString() => '$documentNo is already staged on this truck';
}

/// Persistence for documents staged on a truck entry — the local-first
/// cache (D15). Mirrors the reference app's `StagedDocumentDao`: the
/// manifest rides as JSON so the truck restores offline.
class StagedDocumentRepository {
  StagedDocumentRepository(this._db);

  final DatabaseExecutor _db;

  Map<String, Object?> _row(StagedDocument doc) => {
    'id': doc.id,
    'entry_id': doc.entryId,
    'stream': doc.stream.name,
    'document_no': doc.documentNo,
    'customer_name': doc.customerName,
    'total': doc.total,
    'manifest_json': doc.encodeManifest(),
    'cached_at': doc.cachedAt,
  };

  /// Insert only. The UNIQUE(entry, stream, document_no) constraint is
  /// D8 — a duplicate number on the truck throws.
  Future<void> save(StagedDocument doc) async {
    try {
      await _db.insert(
        'staged_documents',
        _row(doc),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.toString().toLowerCase().contains('unique')) {
        throw DuplicateDocumentException(doc.documentNo);
      }
      rethrow;
    }
  }

  /// Insert or refresh (cache re-hydration must never be blocked by D8).
  Future<void> upsert(StagedDocument doc) async {
    await _db.insert(
      'staged_documents',
      _row(doc),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<StagedDocument>> listForEntry(String entryId) async {
    final rows = await _db.query(
      'staged_documents',
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'cached_at ASC, id ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<StagedDocument?> find(String entryId, String documentNo) async {
    final rows = await _db.query(
      'staged_documents',
      where: 'entry_id = ? AND document_no = ?',
      whereArgs: [entryId, documentNo],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> remove(String entryId, String documentNo) async {
    await _db.delete(
      'staged_documents',
      where: 'entry_id = ? AND document_no = ?',
      whereArgs: [entryId, documentNo],
    );
  }

  Future<void> clearForEntry(String entryId) async {
    await _db.delete(
      'staged_documents',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
  }

  /// Every document number the operator has ever staged, newest first —
  /// the RECENT tap-to-stage chips (fewer keystrokes, fewer errors).
  Future<List<String>> recentDocumentNos({int limit = 8}) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT document_no FROM staged_documents '
      'ORDER BY cached_at DESC LIMIT ?',
      [limit],
    );
    return rows.map((r) => r['document_no'] as String).toList();
  }

  StagedDocument _fromRow(Map<String, Object?> row) {
    final manifest = row['manifest_json'] as String?;
    final json = manifest == null
        ? const <String, dynamic>{}
        : jsonDecode(manifest) as Map<String, dynamic>;
    return StagedDocument.fromJson(
      id: row['id'] as String,
      entryId: row['entry_id'] as String,
      cachedAt: row['cached_at'] as int? ?? 0,
      json: json,
    );
  }
}
