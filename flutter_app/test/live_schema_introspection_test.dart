import 'dart:convert';
import 'dart:io';

import 'package:dispatch_diary/data/services/aws_auto_login_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// LIVE SCHEMA INTROSPECTION — ground truth for the CURRENT backend.
///
/// The pinned SDL snapshot (2026-09-26) may have drifted from the live
/// schema. This probe dumps the fields of the three types the scan flow
/// depends on: Slip_Tyre_Info (lookup), DispatchDeliveryLog (commit
/// response) and the createDispatchDeliveryINV_V2 mutation signature.
/// Read-only; no production writes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  const endpoint =
      'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql';

  test('introspect the live scan-flow types', () async {
    final idToken = await AwsAutoLoginService.login();
    expect(idToken, isNotNull, reason: 'live token required');

    const q = r'''
    query Introspect {
      slipType: __type(name: "Slip_Tyre_Info") {
        fields { name }
      }
      logType: __type(name: "DispatchDeliveryLog") {
        fields { name }
      }
      scanType: __type(name: "CreateDispatchDelivery_Input_INV_V2") {
        inputFields { name }
      }
      mutationType: __type(name: "Mutation") {
        fields(includeDeprecated: false) {
          name
        }
      }
    }
    ''';

    final res = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'query': q}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['errors'] != null) {
      // ignore: avoid_print
      print('INTROSPECTION ERRORS: ${jsonEncode(body['errors'])}');
    }
    final data = (body['data'] ?? const {}) as Map<String, dynamic>;
    // ignore: avoid_print
    print('LIVE Slip_Tyre_Info fields: '
        '${(data['slipType']?['fields'] as List<dynamic>?)?.map((f) => f['name']).join(', ')}');
    // ignore: avoid_print
    print('LIVE DispatchDeliveryLog fields: '
        '${(data['logType']?['fields'] as List<dynamic>?)?.map((f) => f['name']).join(', ')}');
    // ignore: avoid_print
    print('LIVE CreateDispatchDelivery input fields: '
        '${(data['scanType']?['inputFields'] as List<dynamic>?)?.map((f) => f['name']).join(', ')}');
    // ignore: avoid_print
    print('LIVE Mutation has createDispatchDeliveryINV_V2: '
        '${(data['mutationType']?['fields'] as List<dynamic>?)?.any((f) => f['name'] == 'createDispatchDeliveryINV_V2')}');
    expect(data['slipType'], isNotNull);
  });
}
