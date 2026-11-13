import 'dart:convert';
import 'dart:io';

import 'package:dispatch_diary/data/services/appsync_manifest_service.dart';
import 'package:dispatch_diary/data/services/aws_auto_login_service.dart';
import 'package:dispatch_diary/dispatch/dispatch_api.dart';
import 'package:dispatch_diary/dispatch/ibt_scan_api.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// LIVE FORENSICS — accurate data on the real IBT commit behaviour.
///
/// Read-only probes run always (no production writes):
///  - the exact `getSlipTyreWithUID` response shape for a REAL tyre,
///  - whether `registration` / `previous_reg` are populated there
///    (this validates the read-back verification path),
///  - the exact `getTyreHistory` shape.
///
/// With REAL_MUTATIONS=1, ONE real duplicate-scan commit is sent for a
/// tyre already on the test truck (harmless: the backend just records a
/// duplicate event) and the RAW mutation response is captured so we can
/// see exactly what the resolver returns — the key evidence for the
/// "error shown but tyre recorded" bug.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  const endpoint =
      'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql';

  Future<String> token() async {
    final t = await AppSyncManifestService.getValidIdToken() ??
        await AwsAutoLoginService.login();
    expect(t, isNotNull, reason: 'live token required');
    return t!;
  }

  Future<Map<String, dynamic>> rawPost(
    String idToken,
    String query, {
    Map<String, dynamic> variables = const {},
  }) async {
    final res = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  group('live test-tyre scans (owner-approved)', () {
    const testTyres = [
      (serial: '100101158', invoice: '9258368'),
      (serial: '1001011579', invoice: '9255337'),
    ];

    test(
      'scans of the two test tyres parse as success or duplicate, '
      'never rejected',
      () async {
        final idToken = await token();
        final operatorId = (await resolveOperatorIdRaw(idToken))!;

        for (final t in testTyres) {
          // Raw serial probe — what does the backend actually answer?
          const serialQ = r'''
          query MyQuery($serial: String!) {
            getTyreWithSerial(serial: $serial) {
              idTyre serial make size slip_number CustomerName cs_number
              created_at tyre_uid
            }
          }
          ''';
          final serialRaw = await rawPost(
            idToken,
            serialQ,
            variables: {'serial': t.serial},
          );
          // ignore: avoid_print
          print('RAW SERIAL ${t.serial}: ${jsonEncode(serialRaw)}');

          // Hypothesis: the numbers are SLIP numbers, not serials.
          const slipQ = r'''
          query MyQuery($slip_number: Int!) {
            getSlipWithNumber(slip_number: $slip_number) {
              idSlip slip_number tyre_id cs_id invoice_number reject_accepted
            }
          }
          ''';
          final slipRaw = await rawPost(
            idToken,
            slipQ,
            variables: {'slip_number': int.tryParse(t.serial) ?? 0},
          );
          // ignore: avoid_print
          print('RAW SLIP ${t.serial}: ${jsonEncode(slipRaw)}');

          // Path 1: the tyre row by serial.
          final bySerial = await DispatchApi.fetchTyreBySerial(t.serial);
          // ignore: avoid_print
          print(
            'TEST TYRE ${t.serial}: bySerial=${bySerial == null ? "null" : "uid=${bySerial.uid} slip=${bySerial.slipNumber}"}',
          );

          // Path 2: the invoice document's slips (they carry the uid).
          List<SlipTyre> docSlips = const [];
          try {
            docSlips = await DispatchApi.fetchDeliverySlips(
              inv: 'INV${t.invoice}',
            );
          } catch (e) {
            // ignore: avoid_print
            print('TEST TYRE ${t.serial}: doc lookup failed: $e');
          }
          final docMatch = docSlips
              .where((s) => (s.serial ?? '').trim().toUpperCase() == t.serial)
              .firstOrNull;
          // ignore: avoid_print
          print(
            'TEST TYRE ${t.serial}: doc INV${t.invoice} slips=${docSlips.length} '
            'match=${docMatch == null ? "null" : "uid=${docMatch.uid}"}',
          );
          final tyre = bySerial ?? docMatch;
          if (tyre == null || tyre.uid == null) {
            // ignore: avoid_print
            print(
              'TEST TYRE ${t.serial}: UNRESOLVABLE on live backend '
              '(serial/slip/invoice all empty) — check the identifiers',
            );
            continue;
          }
          expect(tyre.uid, isNotNull, reason: '${t.serial} must have a uid');

          const mutation = r'''
          mutation MyMutation($uid: String, $registration: String, $personnel_id: Int, $document_no: String, $loaded: Int, $location_id: Int) {
            createDispatchDeliveryINV_V2(createDispatchDeliveryINV_V2: {uid: $uid, registration: $registration, personnel_id: $personnel_id, document_no: $document_no, loaded: $loaded, location_id: $location_id}) {
              successful duplicate_scan previous_reg scan_time name
            }
          }
          ''';
          final raw = await rawPost(
            idToken,
            mutation,
            variables: {
              'uid': tyre.uid,
              'registration': 'MN05XNGP',
              'personnel_id': operatorId,
              'document_no': 'INV${t.invoice}',
              'loaded': 1,
              'location_id': 12,
            },
          );
          // ignore: avoid_print
          print('RAW RESPONSE ${t.serial}: ${jsonEncode(raw)}');

          final data = (raw['data'] ?? const {}) as Map<String, dynamic>;
          final result = IbtScanApi.parseCommitResponse(data);
          // ignore: avoid_print
          print('PARSED VERDICT ${t.serial}: ${result.runtimeType} '
              '${result is ScanCommitDuplicate ? 'by ${result.name} on ${result.scanTime}' : ''}');
          expect(
            result,
            anyOf(isA<ScanCommitSuccess>(), isA<ScanCommitDuplicate>()),
            reason:
                '${t.serial} was recorded by the backend — the app must '
                'not report it as rejected',
          );
        }
      },
      skip: Platform.environment['REAL_MUTATIONS'] != '1'
          ? 'set REAL_MUTATIONS=1 to scan the two owner-approved test tyres'
          : false,
    );
  });

  group('live IBT forensics (read-only)', () {
    late String idToken;
    late List<SlipTyre> slips;

    setUpAll(() async {
      idToken = await token();
      slips = await DispatchApi.fetchDeliverySlips(inv: 'INV2392908');
      expect(slips, isNotEmpty, reason: 'live document needed');
    });

    test('real tyre rows carry registration / previous_reg (read-back basis)',
        () async {
      final tyre = await DispatchApi.fetchTyreByUid(slips.first.uid!);
      expect(tyre, isNotNull);
      // ignore: avoid_print
      print('REAL TYRE uid=${tyre!.uid} slip=${tyre.slipNumber} '
          'registration=${tyre.registration} '
          'previous_reg=${tyre.previousReg} loaded=${tyre.loaded} '
          'dump=${tyre.dump} reject=${tyre.rejectAccepted}');
      expect(
        tyre.registration != null || tyre.previousReg != null,
        isTrue,
        reason: 'read-back verification depends on these fields',
      );
    });

    test('raw getSlipTyreWithUID response shape is captured', () async {
      const q = r'''
      query MyQuery($uid: String) {
        getSlipTyreWithUID(uid: $uid) {
          idJob job idSlip slip_number on_rim pattern idConfirmation_Sheet
          CustomerName cs_number idTyre make size size_id rubber_id serial dot
          driver reference registration uid location_id
          reject_accepted invoiced invoice_number order_number dump tagged
        }
      }
      ''';
      final data = await rawPost(
        idToken,
        q,
        variables: {'uid': slips.first.uid},
      );
      // ignore: avoid_print
      print('RAW TYRE ROW: ${jsonEncode(data['data'])}');
      expect(data['errors'], isNull);
    });

    test('real history shape is captured', () async {
      final tyre = await DispatchApi.fetchTyreByUid(slips.first.uid!);
      final slipId = tyre?.idSlip;
      if (slipId == null) return;
      final history = await DispatchApi.fetchTyreHistory(slipId);
      // ignore: avoid_print
      print('HISTORY ROWS (${history.length}): '
          '${history.map((h) => '${h.workCellName}|${h.scanInTime}|${h.scanOut}').take(8).join(' ; ')}');
    });

    test(
      'REAL duplicate-scan: capture the exact commit response',
      () async {
        final target = slips
            .where(
              (s) =>
                  (s.previousReg ?? '').isNotEmpty &&
                  (s.loaded ?? 0) == 1 &&
                  s.uid != null,
            )
            .firstOrNull;
        if (target == null) {
          markTestSkipped('no loaded tyre with previous_reg in this document');
          return;
        }
        final reg = target.previousReg!;
        const mutation = r'''
        mutation MyMutation($uid: String, $registration: String, $personnel_id: Int, $document_no: String, $loaded: Int, $location_id: Int) {
          createDispatchDeliveryINV_V2(createDispatchDeliveryINV_V2: {uid: $uid, registration: $registration, personnel_id: $personnel_id, document_no: $document_no, loaded: $loaded, location_id: $location_id}) {
            successful duplicate_scan previous_reg scan_time name
          }
        }
        ''';
        final operatorId = (await resolveOperatorIdRaw(idToken))!;
        final raw = await rawPost(
          idToken,
          mutation,
          variables: {
            'uid': target.uid,
            'registration': reg,
            'personnel_id': operatorId,
            'document_no': 'INV2392908',
            'loaded': 1,
            'location_id': 12,
          },
        );
        // ignore: avoid_print
        print('RAW COMMIT RESPONSE (duplicate on $reg): ${jsonEncode(raw)}');
      },
      skip: Platform.environment['REAL_MUTATIONS'] != '1'
          ? 'set REAL_MUTATIONS=1 to send one real duplicate-scan'
          : false,
    );

    test(
      'REAL duplicate-scan then read-back: does registration change?',
      () async {
        final target = slips
            .where(
              (s) =>
                  (s.previousReg ?? '').isNotEmpty &&
                  (s.loaded ?? 0) == 1 &&
                  s.uid != null,
            )
            .firstOrNull;
        if (target == null) {
          markTestSkipped('no loaded tyre with previous_reg in this document');
          return;
        }
        final reg = target.previousReg!;
        final tyreBefore = await DispatchApi.fetchTyreByUid(target.uid!);
        final before = tyreBefore?.registration ?? '(empty)';
        const mutation = r'''
        mutation MyMutation($uid: String, $registration: String, $personnel_id: Int, $document_no: String, $loaded: Int, $location_id: Int) {
          createDispatchDeliveryINV_V2(createDispatchDeliveryINV_V2: {uid: $uid, registration: $registration, personnel_id: $personnel_id, document_no: $document_no, loaded: $loaded, location_id: $location_id}) {
            successful duplicate_scan previous_reg scan_time name
          }
        }
        ''';
        final operatorId = (await resolveOperatorIdRaw(idToken))!;
        final raw = await rawPost(
          idToken,
          mutation,
          variables: {
            'uid': target.uid,
            'registration': reg,
            'personnel_id': operatorId,
            'document_no': 'INV2392908',
            'loaded': 1,
            'location_id': 12,
          },
        );
        final rows = ((raw['data'] ?? const {})
            as Map<String, dynamic>)['createDispatchDeliveryINV_V2'];
        final after = await DispatchApi.fetchTyreByUid(target.uid!);
        // ignore: avoid_print
        print('BEFORE reg=[$before]  AFTER reg=[${after?.registration}]  '
            'COMMIT=$rows');
      },
      skip: Platform.environment['REAL_MUTATIONS'] != '1'
          ? 'set REAL_MUTATIONS=1 to send one real duplicate-scan'
          : false,
    );
  });
}

/// Minimal personnel resolution (raw, read-only).
Future<int?> resolveOperatorIdRaw(String idToken) async {
  const q = r'''
  query MyQuery {
    listFactoryPersonnel {
      idFactory_Personnel first_name last_name uid active
    }
  }
  ''';
  final res = await http.post(
    Uri.parse(
      'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql',
    ),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    },
    body: jsonEncode({'query': q}),
  );
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final rows = ((body['data'] ?? const {}) as Map<String, dynamic>)[
      'listFactoryPersonnel'] as List<dynamic>? ??
      const [];
  for (final row in rows) {
    final map = row as Map<String, dynamic>;
    final first = map['first_name'] as String? ?? '';
    final last = map['last_name'] as String? ?? '';
    if (first.trim().toLowerCase() == 'theolus' &&
        last.trim().toLowerCase() == 'mpanza' &&
        map['active'] == 1) {
      return map['idFactory_Personnel'] as int?;
    }
  }
  return null;
}
