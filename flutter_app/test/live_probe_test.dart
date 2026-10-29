import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:dispatch_diary/data/services/aws_auto_login_service.dart';

/// Live backend probes for the fixed-operator resolution. Gated on
/// RUN_LIVE_TESTS=1 — prints the raw backend answers so the resolution
/// logic can be built on ground truth instead of guesses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test mocks HttpClient (400 for everything) once the binding is
  // initialized — live tests restore real networking.
  HttpOverrides.global = null;
  final live = Platform.environment['RUN_LIVE_TESTS'] == '1';

  const endpoint =
      'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql';

  Future<Map<String, dynamic>> gql(
    String query,
    Map<String, dynamic> variables,
  ) async {
    final token = await AwsAutoLoginService.login();
    expect(token, isNotNull);
    final res = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  test(
    'probe: getUserPoolPersonnel variants + listFactoryPersonnel for Theolus',
    () async {
      const q1 = r'''
      query MyQuery($first_name: String, $last_name: String, $email: String) {
        getUserPoolPersonnel(getUserPoolPersonnel: {first_name: $first_name, last_name: $last_name, email: $email}) {
          idFactory_Personnel
          first_name
          last_name
        }
      }
      ''';

      for (final probe in [
        ('email=null', {'first_name': 'Theolus', 'last_name': 'Mpanza', 'email': null}),
        ('email=empty', {'first_name': 'Theolus', 'last_name': 'Mpanza', 'email': ''}),
        ('first-only', {'first_name': 'Theolus', 'last_name': '', 'email': ''}),
        ('all-empty', {'first_name': '', 'last_name': '', 'email': ''}),
      ]) {
        try {
          final r = await gql(q1, probe.$2);
          // ignore: avoid_print
          print('PROBE ${probe.$1}: ${jsonEncode(r)}');
        } catch (e) {
          // ignore: avoid_print
          print('PROBE ${probe.$1} ERROR: $e');
        }
      }

      const q2 = r'''
      query MyQuery {
        listFactoryPersonnel {
          idFactory_Personnel
          first_name
          last_name
          uid
          active
        }
      }
      ''';
      final r2 = await gql(q2, const {});
      final rows = (r2['data']?['listFactoryPersonnel'] as List?) ?? [];
      // ignore: avoid_print
      print('PROBE listFactoryPersonnel: ${rows.length} rows');
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final full =
            '${row['first_name']} ${row['last_name']}'.toLowerCase();
        if (full.contains('theolus') || full.contains('mpanza')) {
          // ignore: avoid_print
          print('PROBE match: ${jsonEncode(row)}');
        }
      }
    },
    skip: live ? false : 'set RUN_LIVE_TESTS=1',
  );
}
