import 'dart:convert';
import 'dart:io';

import 'package:dispatch_diary/data/repositories/staged_document_repository.dart';
import 'package:dispatch_diary/data/services/aws_auto_login_service.dart';
import 'package:dispatch_diary/data/services/document_resolver.dart';
import 'package:dispatch_diary/dispatch/dispatch_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// LIVE MULTI-DOC RECON — read-only probes for the Multi-Document Truck
/// Hub (MVP P1). Answers the open questions in docs/mvp-tracking.md §5:
///  - getDeliveryInfo DIBT/INV slip shape (loaded/previous_reg/scan_time
///    per slip, customer at block level)
///  - getSlipWithNumber / getTyreWithSerial existence + shape (manual
///    slip-number entry, UID-free UX)
///  - reject_accepted reality on a known dispatched tyre + slip row
///  - movement vocabulary for the known tyre (reject cells)
///  - full query catalogue (batch/list resolvers, cash possibilities)
///
/// NO production writes. Real document numbers from the live backend
/// (backend-reality.md): INV2392908 (EPS), DIBT0179154 (EPS, 5 tyres).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  final live = Platform.environment['RUN_LIVE_TESTS'] == '1';
  if (!live) {
    test('P1 live recon (skipped without RUN_LIVE_TESTS=1)', () {},
        skip: 'set RUN_LIVE_TESTS=1 to hit the live backend');
    return;
  }
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const endpoint =
      'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql';

  Future<Map<String, dynamic>> post(
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final idToken = await AwsAutoLoginService.login();
    final res = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'query': query, 'variables': variables}),
        )
        .timeout(const Duration(seconds: 25));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['errors'] != null) {
      // ignore: avoid_print
      print('  ! ERROR: ${body['errors']}');
    }
    return body['data'] as Map<String, dynamic>? ?? const {};
  }

  test('P1: getDeliveryInfo INV2392908 — slip shape with loaded state',
      () async {
    const q = r'''
    query MyQuery($inv: String, $dibt: String, $amsInv: String, $ibt: String) {
      getDeliveryInfo(getDeliveryInfo: {amsInv: $amsInv, dibt: $dibt, ibt: $ibt, inv: $inv}) {
        inv {
          customerName customerCode total
          slips { uid slip_number size make serial pattern location_code loaded name previous_reg scan_time dump }
        }
      }
    }
    ''';
    final data = await post(q, {'inv': 'INV2392908', 'dibt': '', 'amsInv': '', 'ibt': ''});
    final info = (data['getDeliveryInfo'] ?? const {}) as Map<String, dynamic>;
    final inv = (info['inv'] ?? const {}) as Map<String, dynamic>;
    // ignore: avoid_print
    print('INV2392908 customer=${inv['customerName']} total=${inv['total']} '
        'slips=${(inv['slips'] as List?)?.length ?? 0}');
    for (final s in (inv['slips'] as List? ?? const []).take(8)) {
      // ignore: avoid_print
      print('  slip=${s['slip_number']} uid=${s['uid']} loaded=${s['loaded']} '
          'prev=${s['previous_reg']} scan_time=${s['scan_time']} '
          'reject=${s['reject_accepted']} size=${s['size']} make=${s['make']}');
    }
    expect(inv['customerName'], isNotNull);
  });

  test('P1: getDeliveryInfo DIBT0179154 — the 5-tyre EPS DIBT', () async {
    const q = r'''
    query MyQuery($inv: String, $dibt: String, $amsInv: String, $ibt: String) {
      getDeliveryInfo(getDeliveryInfo: {amsInv: $amsInv, dibt: $dibt, ibt: $ibt, inv: $inv}) {
        dibt {
          customerName customerCode total
          slips { uid slip_number size make serial pattern location_code loaded name previous_reg scan_time dump }
        }
      }
    }
    ''';
    final data = await post(q, {'inv': '', 'dibt': 'DIBT0179154', 'amsInv': '', 'ibt': ''});
    final info = (data['getDeliveryInfo'] ?? const {}) as Map<String, dynamic>;
    final dibt = (info['dibt'] ?? const {}) as Map<String, dynamic>;
    // ignore: avoid_print
    print('DIBT0179154 customer=${dibt['customerName']} total=${dibt['total']} '
        'slips=${(dibt['slips'] as List?)?.length ?? 0}');
    for (final s in (dibt['slips'] as List? ?? const [])) {
      // ignore: avoid_print
      print('  slip=${s['slip_number']} uid=${s['uid']} loaded=${s['loaded']} '
          'prev=${s['previous_reg']} scan_time=${s['scan_time']} '
          'reject=${s['reject_accepted']} customer=${s['CustomerName']}');
    }
    expect(dibt['customerName'], isNotNull);
  });

  test('P1: getSlipWithNumber(96975621) — manual slip entry shape', () async {
    final slip = await DispatchApi.fetchSlipWithNumber(96975621);
    // ignore: avoid_print
    print('getSlipWithNumber(96975621): ${slip == null ? 'NULL' : 'found'}');
    expect(slip, isNotNull);
  });

  test('P1: getTyreWithSerial(2608E105) — serial lookup', () async {
    final tyre = await DispatchApi.fetchTyreBySerial('2608E105');
    // ignore: avoid_print
    print('getTyreWithSerial(2608E105): ${tyre == null ? 'NULL' : 'slip=${tyre.slipNumber} customer=${tyre.customerName}'}');
    expect(tyre, isNotNull);
  });

  test('P1: tyre history — movement vocabulary for slip 1060772', () async {
    final cells = await DispatchApi.fetchTyreHistory(1060772);
    // ignore: avoid_print
    print('history(${cells.length} cells): '
        '${cells.map((c) => c.workCellName ?? '?').join(' → ')}');
    expect(cells, isNotEmpty);
  });

  test('P1: listTyresAtDispatchFull — reject_accepted reality check', () async {
    // Introspect the return type, then query with a safe field subset.
    const typeQ = r'''
    query Introspect {
      queryType: __type(name: "Query") {
        fields { name
          type { name kind ofType { name kind ofType { name kind ofType { name kind ofType { name kind } } } } }
        }
      }
    }
    ''';
    final tdata = await post(typeQ);
    final fields = ((tdata['queryType']?['fields'] as List?) ?? const []);
    // ignore: avoid_print
    print('introspected ${fields.length} root fields');
    String? retType;
    for (final f in fields) {
      if (f['name'] == 'listTyresAtDispatchFull') {
        dynamic t = f['type'];
        while (t is Map) {
          if (t['name'] != null) {
            retType = t['name'] as String;
            break;
          }
          t = t['ofType'];
        }
      }
    }
    // ignore: avoid_print
    print('listTyresAtDispatchFull return type: $retType');
    expect(retType, isNotNull);
    if (retType == null) return;

    final typeFieldsQ =
        'query Introspect { t: __type(name: "$retType") { fields { name } } }';
    final fdata = await post(typeFieldsQ);
    final typeFields = ((fdata['t']?['fields'] as List?) ?? const [])
        .map((f) => f['name'] as String)
        .toList();
    // ignore: avoid_print
    print('$retType fields: ${typeFields.join(', ')}');

    const wanted = [
      'slip_number', 'uid', 'reject_accepted', 'loaded', 'job', 'size',
      'make', 'CustomerName', 'customerName', 'idSlip', 'dump', 'serial',
      'registration', 'previous_reg', 'scan_time', 'location_id', 'idTyre',
    ];
    final subset =
        typeFields.where((n) => wanted.contains(n)).take(17).join(' ');
    if (subset.isEmpty) {
      // ignore: avoid_print
      print('No wanted fields in $retType — skipping row probe');
      return;
    }
    final rowsQ =
        'query MyQuery { listTyresAtDispatchFull { $subset } }';
    final rdata = await post(rowsQ);
    final rows = (rdata['listTyresAtDispatchFull'] as List?) ?? const [];
    // ignore: avoid_print
    print('listTyresAtDispatchFull rows: ${rows.length}');
    final byReject = <int, int>{};
    for (final r in rows) {
      final ra = r['reject_accepted'];
      byReject[ra is int ? ra : -1] = (byReject[ra is int ? ra : -1] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('reject_accepted histogram (null=-1): $byReject');
    for (final r in rows.take(10)) {
      // ignore: avoid_print
      print('  slip=${r['slip_number']} reject=${r['reject_accepted']} '
          'loaded=${r['loaded']} job=${r['job']} size=${r['size']} '
          'make=${r['make']}');
    }
    expect(rows.length, greaterThanOrEqualTo(0));
  });

  test('P2: DocumentResolver stages INV+DIBT in parallel against prod',
      () async {
    final repo = StagedDocumentRepository(
      await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) => d.execute('''
            CREATE TABLE staged_documents (
              id TEXT PRIMARY KEY,
              entry_id TEXT NOT NULL,
              stream TEXT NOT NULL,
              document_no TEXT NOT NULL,
              customer_name TEXT,
              total INTEGER,
              manifest_json TEXT NOT NULL,
              cached_at INTEGER NOT NULL,
              UNIQUE(entry_id, stream, document_no)
            )
          '''),
        ),
      ),
    );
    final resolver = DocumentResolver(repository: repo);
    final results = await resolver.resolveBatch(
      entryId: 'live-recon-truck',
      input: 'INV2392908, DIBT0179154',
    );
    // ignore: avoid_print
    print('RESOLVER: ${results.map((r) => '${r.input}=${r.status.name}').join(', ')}');
    expect(results.length, 2);
    expect(results.every((r) => r.isOk), isTrue);
    final docs = await repo.listForEntry('live-recon-truck');
    expect(docs.length, 2);
    for (final d in docs) {
      // ignore: avoid_print
      print('  cached ${d.documentNo} customer=${d.customerName} '
          'total=${d.total} slips=${d.slips.length} '
          'loaded=${d.loadedCount}');
      expect(d.slips, isNotEmpty);
    }
    // D8 against prod: re-staging the same number is refused.
    final again = await resolver.resolveBatch(
      entryId: 'live-recon-truck',
      input: 'DIBT0179154',
    );
    expect(again.single.status, DocumentResolveStatus.duplicate);
  });

  test('P1: full query catalogue — batch/list resolvers', () async {
    const q = r'''
    query Introspect {
      queryType: __type(name: "Query") {
        fields(includeDeprecated: true) {
          name
          args { name }
        }
      }
    }
    ''';
    final data = await post(q);
    final fields = ((data['queryType']?['fields'] as List?) ?? const []);
    // ignore: avoid_print
    print('LIVE Query root: ${fields.length} fields');
    for (final f in fields) {
      final n = f['name'] as String;
      if (n == 'listTyresAtDispatch' ||
          n == 'listTyresAtDispatchFull' ||
          n == 'getRejectInfo' ||
          n == 'getAmountOfRejects' ||
          n == 'getInProcessRejectInfo' ||
          n == 'slipNumberCheck' ||
          n == 'getConfirmationSheetWithCSID') {
        final args = ((f['args'] as List?) ?? const []).map((a) => a['name']).join(', ');
        // ignore: avoid_print
        print('  $n($args)');
      }
    }
    expect(fields, isNotEmpty);
  });
}
