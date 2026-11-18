import 'package:dispatch_diary/data/repositories/cash_scan_repository.dart';
import 'package:dispatch_diary/data/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Audit #3 — the persisted cash-scan log: a cash tyre stays known-loaded
/// across sessions until it is offloaded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  final uid = 'CASH-UID-${DateTime.now().millisecondsSinceEpoch}';

  tearDown(() async {
    final repo = CashScanRepository(await DatabaseService.database);
    await repo.remove(uid);
  });

  test('v8 migration created cash_scans', () async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='cash_scans'",
    );
    expect(rows, isNotEmpty);
  });

  test('record → isRecorded → recordedUids round-trip', () async {
    final repo = CashScanRepository(await DatabaseService.database);
    expect(await repo.isRecorded(uid), isFalse);
    await repo.record(uid, 'IBT122773');
    expect(await repo.isRecorded(uid), isTrue);
    expect(await repo.documentNoFor(uid), 'IBT122773');
    expect(await repo.recordedUids(), contains(uid));
  });

  test('remove forgets the tyre (it can be loaded elsewhere again)', () async {
    final repo = CashScanRepository(await DatabaseService.database);
    await repo.record(uid, 'IBT122773');
    await repo.remove(uid);
    expect(await repo.isRecorded(uid), isFalse);
  });
}
