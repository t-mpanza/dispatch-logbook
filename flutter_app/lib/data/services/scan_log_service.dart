import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'supabase_service.dart';

/// Scanner diagnostics pipeline — the evidence trail for scan bugs.
///
/// Every scan event is written to local SQLite FIRST (offline-safe), then
/// flushed to Supabase `scan_logs` in batches. Nothing sensitive is ever
/// logged: no tokens, no credentials — only the operational facts
/// (screen, event, uid, registration, document, response shapes).
class ScanLogService {
  ScanLogService._();

  static bool _flushing = false;
  static Timer? _flushTimer;

  /// Record one event. Local write is immediate; the Supabase flush is
  /// debounced and fire-and-forget — logging must never slow a scan.
  static Future<void> log({
    required String screen,
    required String event,
    String? uid,
    String? registration,
    String? documentNo,
    Object? detail,
  }) async {
    try {
      await DatabaseService.insertScanLog(
        screen: screen,
        event: event,
        uid: uid,
        registration: registration,
        documentNo: documentNo,
        detail: detail == null
            ? null
            : (detail is String ? detail : jsonEncode(detail)),
      );
      _scheduleFlush();
    } catch (e) {
      debugPrint('ScanLogService: local write failed: $e');
    }
  }

  static void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 5), () {
      unawaited(flush());
    });
  }

  /// Push the backlog to Supabase. Batch of 100, loop until drained.
  static Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final userId = await SupabaseService.getUserId();
      if (userId == null) return;
      final client = SupabaseService.client;

      for (var round = 0; round < 10; round++) {
        final rows = await DatabaseService.unpushedScanLogs();
        if (rows.isEmpty) break;

        final pushed = <int>[];
        for (final row in rows) {
          try {
            await client.from('scan_logs').insert({
              'created_at': DateTime.fromMillisecondsSinceEpoch(
                row['created_at'] as int,
              ).toUtc().toIso8601String(),
              'screen': row['screen'],
              'event': row['event'],
              'uid': row['uid'],
              'registration': row['registration'],
              'document_no': row['document_no'],
              'detail': row['detail'],
            });
            pushed.add(row['id'] as int);
          } catch (e) {
            debugPrint('ScanLogService: supabase insert failed: $e');
            break;
          }
        }
        if (pushed.isNotEmpty) {
          await DatabaseService.markScanLogsPushed(pushed);
        } else {
          break;
        }
      }
      await DatabaseService.pruneScanLogs();
    } catch (e) {
      debugPrint('ScanLogService: flush failed: $e');
    } finally {
      _flushing = false;
    }
  }
}
