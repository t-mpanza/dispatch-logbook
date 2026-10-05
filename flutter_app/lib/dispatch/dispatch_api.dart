import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/services/appsync_manifest_service.dart';
import 'models/dispatch_models.dart';
import 'models/json_helpers.dart';
import 'models/slip_tyre.dart';

/// Live read-only queries against the shared ATT AppSync backend.
///
/// Fused from dispatch-app's operations catalog. Every call reuses the
/// app's existing token pipeline (silent auto-login included), so the
/// Dispatch Hub works out-of-the-box with no manual sign-in.
class DispatchApi {
  static const String endpoint =
      'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql';

  static Future<Map<String, dynamic>> _post({
    required String query,
    Map<String, dynamic> variables = const {},
  }) async {
    final idToken = await AppSyncManifestService.getValidIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('No AppSync session — sign in or check connectivity.');
    }

    final res = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'query': query, 'variables': variables}),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('AppSync error (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['errors'] != null && (data['errors'] as List).isNotEmpty) {
      throw Exception(
        'AppSync GraphQL Error: ${data['errors'][0]['message']}',
      );
    }
    return data['data'] as Map<String, dynamic>? ?? const {};
  }

  // ── Tyre lookup ────────────────────────────────────────────────────────────

  static Future<SlipTyre?> fetchTyreByUid(String uid) async {
    const q = r'''
    query MyQuery($uid: String) {
      getSlipTyreWithUID(uid: $uid) {
        idJob job idSlip slip_number on_rim pattern idConfirmation_Sheet
        CustomerName cs_number idTyre make size serial dot driver reference
        registration uid location_id reject_accepted invoiced invoice_number
        order_number dump tagged
      }
    }
    ''';
    final data = await _post(query: q, variables: {'uid': uid});
    final rows = jsonMapList(data['getSlipTyreWithUID']);
    return rows.isEmpty ? null : SlipTyre.fromJson(rows.first);
  }

  static Future<List<TyreHistoryEntry>> fetchTyreHistory(int slipId) async {
    const q = r'''
    query MyQuery($slip_id: Int) {
      getTyreHistory(slip_id: $slip_id) {
        first_name last_name work_cell_name scan_in_time scan_out_time scan_out
      }
    }
    ''';
    final data = await _post(query: q, variables: {'slip_id': slipId});
    return jsonMapList(data['getTyreHistory'])
        .map((m) => TyreHistoryEntry.fromJson(m))
        .toList();
  }

  static Future<SlipDetail?> fetchSlipWithNumber(int slipNumber) async {
    const q = r'''
    query MyQuery($slip_number: Int!) {
      getSlipWithNumber(slip_number: $slip_number) {
        idSlip slip_number tyre_id job_id cs_id on_rim rubber_id position_in_batch
        job_staged through_initial_inspection ready_to_cut missing no_guarantee
        casing_grade casing_added invoiced casing_code reject_accepted
        green_block invoice_number previous_slip_id repeat_uid
        through_final_inspection through_dispatch_inspection created_at late
        circumference width
      }
    }
    ''';
    final data = await _post(query: q, variables: {'slip_number': slipNumber});
    final rows = jsonMapList(data['getSlipWithNumber']);
    return rows.isEmpty ? null : SlipDetail.fromJson(rows.first);
  }

  static Future<String?> fetchSerialByJobNumber(int slipNumber) async {
    const q = r'''
    query MyQuery($slip_number: Int) {
      getTyreWithJobNumber(slip_number: $slip_number) {
        serial idTyre reject_accepted
      }
    }
    ''';
    final data = await _post(query: q, variables: {'slip_number': slipNumber});
    final rows = jsonMapList(data['getTyreWithJobNumber']);
    return rows.isEmpty ? null : jsonString(rows.first['serial']);
  }

  static Future<SlipTyre?> fetchTyreBySerial(String serial) async {
    const q = r'''
    query MyQuery($serial: String!) {
      getTyreWithSerial(serial: $serial) {
        make idTyre size slip_number CustomerName cs_number serial created_at tyre_uid
      }
    }
    ''';
    final data = await _post(query: q, variables: {'serial': serial});
    final rows = jsonMapList(data['getTyreWithSerial']);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final slipNumber = jsonInt(row['slip_number']);
    if (slipNumber != null) {
      final slip = await fetchSlipWithNumber(slipNumber);
      final bySlip = await fetchTyreByCsId(slip?.csId);
      if (slip != null) {
        for (final t in bySlip) {
          if (t.idSlip == slip.idSlip) return t;
        }
      }
    }
    return SlipTyre(
      serial: jsonString(row['serial']),
      make: jsonString(row['make']),
      size: jsonString(row['size']),
      csNumber: jsonString(row['cs_number']),
      customerName: jsonString(row['CustomerName']),
      slipNumber: slipNumber,
    );
  }

  static Future<List<SlipTyre>> fetchTyreByCsId(int? csId) async {
    if (csId == null) return const [];
    const q = r'''
    query MyQuery($cs_id: Int!) {
      getSlipTyreWithCSID(cs_id: $cs_id) {
        idJob job idSlip slip_number on_rim pattern idConfirmation_Sheet
        CustomerName cs_number idTyre make make_id size size_id serial dot
        driver reference registration uid location_id reject_accepted invoiced
        invoice_number order_number dump tagged
      }
    }
    ''';
    final data = await _post(query: q, variables: {'cs_id': csId});
    return jsonMapList(data['getSlipTyreWithCSID'])
        .map((m) => SlipTyre.fromJson(m))
        .toList();
  }

  static Future<Map<String, dynamic>?> fetchConfirmationSheetByCsNumber(
    String csNumber,
  ) async {
    const q = r'''
    query MyQuery($cs_number: String!) {
      getConfiramtionSheetWithCSNumber(cs_number: $cs_number) {
        idConfirmation_Sheet CustomerName CustomerCode slips batched_time
        complete factory_complete at_dispatch first_in_time last_out_time
        cs_number
      }
    }
    ''';
    final data = await _post(
      query: q,
      variables: {'cs_number': csNumber},
    );
    final rows = jsonMapList(data['getConfiramtionSheetWithCSNumber']);
    return rows.isEmpty ? null : rows.first;
  }

  /// Delivery slips for a staged document (INV/DIBT/AMS number) — the
  /// inspect HUD's source of truth in the lite (text-input) mode.
  static Future<List<SlipTyre>> fetchDeliverySlips({
    String inv = '',
    String dibt = '',
    String amsInv = '',
  }) async {
    const q = r'''
    query MyQuery($inv: String, $dibt: String, $amsInv: String) {
      getDeliveryInfo(getDeliveryInfo: {amsInv: $amsInv, dibt: $dibt, inv: $inv}) {
        inv {
          customerName customerCode total
          slips {
            slip_number size make serial pattern location_code uid loaded
            name previous_reg scan_time dump
          }
        }
        dibt {
          customerName customerCode total
          slips {
            slip_number size make serial pattern location_code uid loaded
            name previous_reg scan_time dump
          }
        }
      }
    }
    ''';
    final data = await _post(
      query: q,
      variables: {'inv': inv, 'dibt': dibt, 'amsInv': amsInv},
    );
    final delivery = jsonMapField(data['getDeliveryInfo']);
    final tyres = <SlipTyre>[];
    for (final key in const ['inv', 'dibt']) {
      final block = jsonMapField(delivery[key]);
      for (final m in jsonMapList(block['slips'])) {
        tyres.add(SlipTyre.fromJson(m));
      }
    }
    return tyres;
  }

  // ── Dispatch board ─────────────────────────────────────────────────────────

  /// The backend's `times!` input: an object with epoch-second bounds.
  /// Today's range = start of local day → now.
  static (int, int) todayRange([DateTime? now]) {
    final t = now ?? DateTime.now();
    final nowSec = t.millisecondsSinceEpoch ~/ 1000;
    final startSec = nowSec - (nowSec % 86400);
    return (startSec, nowSec);
  }

  static Map<String, dynamic> timesInput(int start, int end) => {
    'start_time': start,
    'end_time': end,
  };

  static Future<List<DispatchTyre>> fetchTyresAtDispatch() async {
    const q = r'''
    query MyQuery {
      listTyresAtDispatchFull {
        idSlip slip_number cs_number CustomerName size make serial pattern
        at_dispatch invoiced through_dispatch_inspection first_in_time
        EVO_status idConfirmation_Sheet
      }
    }
    ''';
    final data = await _post(query: q);
    return jsonMapList(data['listTyresAtDispatchFull'])
        .map((m) => DispatchTyre.fromJson(m))
        .toList();
  }

  static Future<List<OutstandingBatch>> fetchOutstandingBatches() async {
    const q = r'''
    query MyQuery {
      listOutstandingBatches {
        slips CustomerName created_at cs_number at_dispatch first_in_time
        idConfirmation_Sheet first_out_time last_out_time
      }
    }
    ''';
    final data = await _post(query: q);
    return jsonMapList(data['listOutstandingBatches'])
        .map((m) => OutstandingBatch.fromJson(m))
        .toList();
  }

  static Future<List<LateBatchTyre>> fetchLateBatches() async {
    const q = r'''
    query MyQuery {
      getLateBatchQuery {
        idConfirmation_Sheet first_out_time cs_number reference CustomerName
        idSlip slip_number make size serial job pattern position_in_batch
      }
    }
    ''';
    final data = await _post(query: q);
    return jsonMapList(data['getLateBatchQuery'])
        .map((m) => LateBatchTyre.fromJson(m))
        .toList();
  }

  static Future<int?> fetchRejectsAmount(int startTime, int endTime) async {
    const q = r'''
    query MyQuery($getAmountOfRejects: times!) {
      getAmountOfRejects(getAmountOfRejects: $getAmountOfRejects) {
        number_of_tyres
      }
    }
    ''';
    final data = await _post(
      query: q,
      variables: {'getAmountOfRejects': timesInput(startTime, endTime)},
    );
    final rows = jsonMapList(data['getAmountOfRejects']);
    return rows.isEmpty ? null : jsonInt(rows.first['number_of_tyres']);
  }

  static Future<int?> fetchTotalTyres(int startTime, int endTime) async {
    const q = r'''
    query MyQuery($getTotalNumTyres: times!) {
      getTotalNumTyres(getTotalNumTyres: $getTotalNumTyres) {
        amounts
      }
    }
    ''';
    final data = await _post(
      query: q,
      variables: {'getTotalNumTyres': timesInput(startTime, endTime)},
    );
    final rows = jsonMapList(data['getTotalNumTyres']);
    return rows.isEmpty ? null : jsonInt(rows.first['amounts']);
  }

  static Future<List<ShiftTotal>> fetchShiftTotals(
    int startTime,
    int endTime,
  ) async {
    const q = r'''
    query MyQuery($getShiftTotal: times!) {
      getShiftTotal(getShiftTotal: $getShiftTotal) {
        work_cell_name number_of_tyres work_cell_id cell_quota
      }
    }
    ''';
    final data = await _post(
      query: q,
      variables: {'getShiftTotal': timesInput(startTime, endTime)},
    );
    return jsonMapList(data['getShiftTotal'])
        .map((m) => ShiftTotal.fromJson(m))
        .toList();
  }

  static Future<ActiveDispatchSession?> fetchActiveDispatchSession() async {
    const q = r'''
    query MyQuery($bPrep: Int) {
      getActiveDispatchSession(bPrep: $bPrep) {
        idDispatch_Session iLocation_ID cLocation iPersonnel_ID cName bPrep
        cComment dStart_Time
      }
    }
    ''';
    final data = await _post(query: q, variables: {'bPrep': 0});
    final rows = jsonMapList(data['getActiveDispatchSession']);
    return rows.isEmpty
        ? null
        : ActiveDispatchSession.fromJson(rows.first);
  }

  static Future<List<DispatchSessionTyre>> fetchDispatchSessionTyres(
    int sessionId,
  ) async {
    const q = r'''
    query MyQuery($idDispatch_Session: Int) {
      getDispatchSession(idDispatch_Session: $idDispatch_Session) {
        idSlip cSlip_Number cMake cSize cSerial cJob_Type cPattern
        cCustomer_Name cCustomer_Code
      }
    }
    ''';
    final data = await _post(
      query: q,
      variables: {'idDispatch_Session': sessionId},
    );
    return jsonMapList(data['getDispatchSession'])
        .map((m) => DispatchSessionTyre.fromJson(m))
        .toList();
  }
}
