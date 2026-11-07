import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/services/appsync_manifest_service.dart';
import '../data/services/aws_auto_login_service.dart';
import 'models/dump_customer.dart';
import 'models/json_helpers.dart';

/// Dump / scrap-analysis customer registry plus slip dump marking.
///
/// The write counterpart of [DispatchApi]: same self-healing token pipeline
/// (silent auto-login + one retry) and the same typed-error convention as
/// [IbtScanApi] — nothing ever surfaces a login wall, and a well-formed
/// backend rejection is never mistaken for a connection failure.
class DumpApiException implements Exception {
  const DumpApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DumpApi {
  DumpApi._();

  static const String _endpoint =
      'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql';

  // ── Registry reads ──────────────────────────────────────────────────────

  static Future<List<DumpCustomer>> listDumpCustomers() async {
    const q = r'''
    query MyQuery {
      listDumpCustomer {
        idDump_Customer customer_lookup_id CustomerName CustomerCode
      }
    }
    ''';
    final data = await _post(query: q);
    return jsonMapList(data['listDumpCustomer'])
        .map(DumpCustomer.fromJson)
        .toList();
  }

  static Future<List<ScrapAnalysisCustomer>> listScrapAnalysisCustomers() async {
    const q = r'''
    query MyQuery {
      listAnalysisCustomer {
        idScrap_Analysis_Customer customer_lookup_id CustomerName CustomerCode
      }
    }
    ''';
    final data = await _post(query: q);
    return jsonMapList(data['listAnalysisCustomer'])
        .map(ScrapAnalysisCustomer.fromJson)
        .toList();
  }

  /// The master customer directory (client-side search source).
  static Future<List<CustomerLookupEntry>> listCustomerLookup() async {
    const q = r'''
    query MyQuery {
      listCustomerLookup {
        idCustomer_Lookup CustomerName CustomerCode
      }
    }
    ''';
    final data = await _post(query: q);
    return jsonMapList(data['listCustomerLookup'])
        .map(CustomerLookupEntry.fromJson)
        .toList();
  }

  // ── Pure payload builders (the mutation can never be sent malformed) ──

  static Map<String, dynamic> buildDumpMarkPayload(int slipId, {bool dumped = true}) {
    return {'idSlip': slipId, 'dump': dumped ? 1 : 0};
  }

  static Map<String, dynamic> buildDumpCustomerValidPayload(int id, bool valid) {
    return {'idDump_Customer': id, 'valid': valid ? 1 : 0};
  }

  static Map<String, dynamic> buildScrapAnalysisCustomerValidPayload(
    int id,
    bool valid,
  ) {
    return {'idScrap_Analysis_Customer': id, 'valid': valid ? 1 : 0};
  }

  static Map<String, dynamic> buildAddCustomerPayload(int customerLookupId) {
    return {'customer_lookup_id': customerLookupId};
  }

  // ── Registry writes ─────────────────────────────────────────────────────

  static Future<void> addDumpCustomer(int customerLookupId) async {
    const m = r'''
    mutation MyMutation($customer_lookup_id: Int) {
      createDumpCustomer(createDumpCustomer: {customer_lookup_id: $customer_lookup_id}) {
        idDump_Customer
      }
    }
    ''';
    await _post(query: m, variables: buildAddCustomerPayload(customerLookupId));
  }

  static Future<void> setDumpCustomerValid(int id, bool valid) async {
    const m = r'''
    mutation MyMutation($idDump_Customer: Int, $valid: Int) {
      updateDumpCustomer(updateDumpCustomer: {idDump_Customer: $idDump_Customer, valid: $valid}) {
        idDump_Customer
      }
    }
    ''';
    await _post(query: m, variables: buildDumpCustomerValidPayload(id, valid));
  }

  static Future<void> addScrapAnalysisCustomer(int customerLookupId) async {
    const m = r'''
    mutation MyMutation($customer_lookup_id: Int) {
      createAnalysisCustomer(createAnalysisCustomer: {customer_lookup_id: $customer_lookup_id}) {
        idScrap_Analysis_Customer
      }
    }
    ''';
    await _post(query: m, variables: buildAddCustomerPayload(customerLookupId));
  }

  static Future<void> setScrapAnalysisCustomerValid(int id, bool valid) async {
    const m = r'''
    mutation MyMutation($idScrap_Analysis_Customer: Int, $valid: Int) {
      updateAnalysisCustomer(updateAnalysisCustomer: {idScrap_Analysis_Customer: $idScrap_Analysis_Customer, valid: $valid}) {
        idScrap_Analysis_Customer
      }
    }
    ''';
    await _post(
      query: m,
      variables: buildScrapAnalysisCustomerValidPayload(id, valid),
    );
  }

  // ── Slip dump marking ───────────────────────────────────────────────────

  /// Sets the slip's `dump` flag (1 = dumped, 0 = not dumped).
  static Future<void> markDumped(int slipId, {bool dumped = true}) async {
    const m = r'''
    mutation MyMutation($idSlip: Int!, $dump: Int) {
      updateSlip(updateSlip: {idSlip: $idSlip, dump: $dump}) {
        idSlip
      }
    }
    ''';
    await _post(query: m, variables: buildDumpMarkPayload(slipId, dumped: dumped));
  }

  // ── Transport ───────────────────────────────────────────────────────────

  /// POST with a self-healing session: on auth-flavoured failures the app
  /// silently re-authenticates once and retries.
  static Future<Map<String, dynamic>> _post({
    required String query,
    Map<String, dynamic> variables = const {},
    String? explicitToken,
  }) async {
    try {
      return await _postOnce(
        query: query,
        variables: variables,
        explicitToken: explicitToken,
      );
    } on DumpApiException catch (e) {
      final isAuth = e.message.contains('401') ||
          e.message.contains('Unauthorized') ||
          e.message.contains('token');
      if (!isAuth || explicitToken != null) rethrow;

      final fresh = await AwsAutoLoginService.login();
      if (fresh == null || fresh.isEmpty) rethrow;
      return await _postOnce(
        query: query,
        variables: variables,
        explicitToken: fresh,
      );
    }
  }

  static Future<Map<String, dynamic>> _postOnce({
    required String query,
    Map<String, dynamic> variables = const {},
    String? explicitToken,
  }) async {
    final idToken =
        explicitToken ?? await AppSyncManifestService.getValidIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const DumpApiException('No session');
    }

    final http.Client client = http.Client();
    try {
      final res = await client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'query': query, 'variables': variables}),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        throw DumpApiException(
          'AppSync error (${res.statusCode}): ${res.body}',
        );
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['errors'] != null && (body['errors'] as List).isNotEmpty) {
        throw DumpApiException(
          'AppSync GraphQL Error: ${body['errors'][0]['message']}',
        );
      }
      return body['data'] as Map<String, dynamic>? ?? const {};
    } on DumpApiException {
      rethrow;
    } catch (e) {
      throw DumpApiException('Connection failed: $e');
    } finally {
      client.close();
    }
  }
}
