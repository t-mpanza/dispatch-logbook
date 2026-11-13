import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/services/appsync_manifest_service.dart';
import '../data/services/aws_auto_login_service.dart';
import '../data/services/scan_log_service.dart';
import 'models/json_helpers.dart';

/// The `createDispatchDeliveryINV_V2` commit — the scan becomes the system
/// of record the moment the backend answers `successful == 1`.
sealed class ScanCommitResult {
  const ScanCommitResult();
}

final class ScanCommitSuccess extends ScanCommitResult {
  const ScanCommitSuccess({this.name, this.scanTime});
  final String? name;
  final String? scanTime;
}

final class ScanCommitDuplicate extends ScanCommitResult {
  const ScanCommitDuplicate({this.name, this.scanTime});
  final String? name;
  final String? scanTime;
}

final class ScanCommitRejected extends ScanCommitResult {
  const ScanCommitRejected();
}

class ScanCommitException implements Exception {
  const ScanCommitException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The fixed operator for IBT scans (no badge flow).
class IbtScanApi {
  IbtScanApi._();

  static const String fixedOperator = 'Theolus Mpanza';
  static const int locationId = 12;

  static const String _endpoint =
      'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql';

  static int? _cachedOperatorId;

  /// Resolve the fixed operator's idFactory_Personnel once per process.
  ///
  /// Path 1: `listFactoryPersonnel` (read-only — `getUserPoolPersonnel` has
  /// a live side effect: every call shape creates a new personnel row).
  /// Prefers the ACTIVE row with a real badge uid (the 30000000-uid rows
  /// are auto-generated duplicates).
  /// Path 2 (fallback): `getUserPoolPersonnel` with FIXED args (email '')
  /// so repeated calls can never proliferate more rows.
  ///
  /// Network/auth failures PROPAGATE as ScanCommitException so the UI can
  /// say "connection failed" — null means the operator truly was not found.
  static Future<int?> resolveOperatorId() async {
    if (_cachedOperatorId != null) return _cachedOperatorId;

    const firstName = 'Theolus';
    const lastName = 'Mpanza';

    const listQuery = r'''
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

    bool nameMatches(Map<String, dynamic> row) {
      final fn = jsonString(row['first_name'] ?? '') ?? '';
      final ln = jsonString(row['last_name'] ?? '') ?? '';
      return fn.trim().toLowerCase() == firstName.toLowerCase() &&
          ln.trim().toLowerCase() == lastName.toLowerCase();
    }

    // Path 1: read-only list (network failures propagate).
    final data = await _post(query: listQuery);
    final rows = jsonMapList(data['listFactoryPersonnel']);

    int? best;
    for (final row in rows) {
      if (!nameMatches(row)) continue;
      if (jsonInt(row['active']) != 1) continue;
      final uid = jsonString(row['uid']) ?? '';
      final id = jsonInt(row['idFactory_Personnel']);
      if (id == null) continue;
      // A real badge (not the shared 30000000 placeholder) wins.
      if (uid.isNotEmpty && uid != '30000000') {
        _cachedOperatorId = id;
        return id;
      }
      best ??= id;
    }

    if (best != null) {
      _cachedOperatorId = best;
      return best;
    }

    // Path 2: user-pool fallback (best-effort; never throws).
    try {
      const poolQuery = r'''
      query MyQuery($first_name: String, $last_name: String, $email: String) {
        getUserPoolPersonnel(getUserPoolPersonnel: {first_name: $first_name, last_name: $last_name, email: $email}) {
          idFactory_Personnel
        }
      }
      ''';
      final poolData = await _post(
        query: poolQuery,
        variables: {'first_name': firstName, 'last_name': lastName, 'email': ''},
      );
      final poolRows = jsonMapList(poolData['getUserPoolPersonnel']);
      final id = poolRows.isEmpty
          ? null
          : jsonInt(poolRows.first['idFactory_Personnel']);
      if (id != null) {
        _cachedOperatorId = id;
        return id;
      }
    } catch (_) {
      // Best-effort fallback only.
    }

    return null;
  }

  /// Pure payload builder — the mutation can never be sent malformed.
  static Map<String, dynamic> buildScanPayload({
    required String uid,
    required String registration,
    required int personnelId,
    required String documentNo,
    int loaded = 1,
    int location = locationId,
  }) {
    return {
      'uid': uid,
      'registration': registration,
      'personnel_id': personnelId,
      'document_no': documentNo,
      'loaded': loaded,
      'location_id': location,
    };
  }

  /// Parse the mutation response defensively (Ints, not bools).
  ///
  /// LIVE-VERIFIED SHAPE + SENTINEL (2026-11-07):
  /// - The resolver returns `createDispatchDeliveryINV_V2` as a SINGLE
  ///   OBJECT (`DispatchDeliveryLog` is object-typed in the SDL). Reading it
  ///   through [jsonMapList] silently produced an empty row on every scan →
  ///   `successful=0, duplicate=0` → "Scan rejected by system" while the
  ///   backend recorded the tyre. [jsonMapField] accepts the object shape
  ///   AND the legacy single-element list shape.
  /// - The backend uses the factory-wide sentinel convention — `0` = no,
  ///   ANY non-zero = yes. A real duplicate scan returned
  ///   `duplicate_scan: 2` (not 1); truthy `!= 0` covers both sentinels.
  static ScanCommitResult parseCommitResponse(Map<String, dynamic> data) {
    final row = jsonMapField(data['createDispatchDeliveryINV_V2']);

    final successful = jsonInt(row['successful']) ?? 0;
    final duplicate = jsonInt(row['duplicate_scan']) ?? 0;
    final name = jsonString(row['name']);
    final scanTime = jsonString(row['scan_time']);

    if (successful != 0) {
      return ScanCommitSuccess(name: name, scanTime: scanTime);
    }
    if (duplicate != 0) {
      return ScanCommitDuplicate(name: name, scanTime: scanTime);
    }
    return const ScanCommitRejected();
  }

  /// Commit the scan. Never throws for a well-formed rejection.
  static Future<ScanCommitResult> commitScan({
    required String uid,
    required String registration,
    required int personnelId,
    required String documentNo,
    String screen = 'unknown',
  }) async {
    const mutation = r'''
    mutation MyMutation($uid: String, $registration: String, $personnel_id: Int, $document_no: String, $loaded: Int, $location_id: Int) {
      createDispatchDeliveryINV_V2(createDispatchDeliveryINV_V2: {uid: $uid, registration: $registration, personnel_id: $personnel_id, document_no: $document_no, loaded: $loaded, location_id: $location_id}) {
        successful
        duplicate_scan
        previous_reg
        scan_time
        name
      }
    }
    ''';

    final variables = buildScanPayload(
      uid: uid,
      registration: registration,
      personnelId: personnelId,
      documentNo: documentNo,
    );

    unawaited(
      ScanLogService.log(
        screen: screen,
        event: 'commit_request',
        uid: uid,
        registration: registration,
        documentNo: documentNo,
        detail: variables,
      ),
    );

    final Map<String, dynamic> data;
    try {
      data = await _post(query: mutation, variables: variables);
    } on ScanCommitException catch (e) {
      unawaited(
        ScanLogService.log(
          screen: screen,
          event: 'commit_exception',
          uid: uid,
          registration: registration,
          documentNo: documentNo,
          detail: e.message,
        ),
      );
      rethrow;
    }

    final result = parseCommitResponse(data);
    unawaited(
      ScanLogService.log(
        screen: screen,
        event: 'commit_response',
        uid: uid,
        registration: registration,
        documentNo: documentNo,
        detail: {
          'raw': data,
          'verdict': result.runtimeType.toString(),
        },
      ),
    );
    return result;
  }

  /// POST with a self-healing session: on auth-flavoured failures the app
  /// silently re-authenticates once and retries — every query and mutation
  /// goes through this, so nothing ever surfaces a login wall.
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
    } on ScanCommitException catch (e) {
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
      throw const ScanCommitException('No session');
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
        throw ScanCommitException(
          'AppSync error (${res.statusCode}): ${res.body}',
        );
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['errors'] != null && (body['errors'] as List).isNotEmpty) {
        throw ScanCommitException(
          'AppSync GraphQL Error: ${body['errors'][0]['message']}',
        );
      }
      return body['data'] as Map<String, dynamic>? ?? const {};
    } on ScanCommitException {
      rethrow;
    } catch (e) {
      throw ScanCommitException('Connection failed: $e');
    } finally {
      client.close();
    }
  }
}
