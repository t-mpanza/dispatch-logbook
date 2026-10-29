import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/services/appsync_manifest_service.dart';
import 'package:dispatch_diary/data/services/aws_auto_login_service.dart';
import 'package:dispatch_diary/dispatch/dispatch_api.dart';
import 'package:dispatch_diary/dispatch/domain/ibt_scan_engine.dart';
import 'package:dispatch_diary/dispatch/ibt_scan_api.dart';

/// Live end-to-end integration tests.
///
/// These hit the real Cognito pool and AppSync API, so they only run when
/// RUN_LIVE_TESTS=1 is set:
///   RUN_LIVE_TESTS=1 flutter test test/live_integration_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test mocks HttpClient (400 for everything) once the binding is
  // initialized — live tests restore real networking.
  HttpOverrides.global = null;
  final live = Platform.environment['RUN_LIVE_TESTS'] == '1';

  group('live integration', () {
    test(
      'auto-login obtains a session and fetches a real IBT manifest',
      () async {
        final token = await AwsAutoLoginService.login();
        expect(token, isNotNull);
        expect(token!.split('.').length, 3);

        final doc = await AppSyncManifestService.fetchIbtDocument(
          '122773',
          explicitIdToken: token,
        );
        expect(doc.documentNo, 'IBT122773');
        expect(doc.lineItems, isNotEmpty);
        expect(doc.total, greaterThan(0));
      },
      skip: live ? false : 'set RUN_LIVE_TESTS=1 to hit the live backend',
    );

    test(
      'live manifest resolves the 12R line to 12R22.5 (not 315)',
      () async {
        final token = await AwsAutoLoginService.login();
        final doc = await AppSyncManifestService.fetchIbtDocument(
          '122773',
          explicitIdToken: token,
        );

        final twelveR = doc.lineItems.where(
          (l) => l.description.contains('12R'),
        );
        expect(twelveR, isNotEmpty);
        for (final line in twelveR) {
          expect(line.size, '12R22.5');
          expect(line.size, isNot(contains('315')));
        }
      },
      skip: live ? false : 'set RUN_LIVE_TESTS=1 to hit the live backend',
    );

    test(
      'live job gate: a customer tyre is rejected as not-stocks',
      () async {
        // Real customer document from the recon docs (INV2392908, EPS
        // COURIERS) — its slips are customer tyres, not Client Retread.
        final slips = await DispatchApi.fetchDeliverySlips(inv: 'INV2392908');
        expect(slips, isNotEmpty);
        final tyre = slips.first;
        expect(tyre.uid, isNotNull);

        final trip = LoadingSheetTrip(
          id: 'live-trip',
          reg: 'MN05XNGP',
          driverName: 'Neil',
          tripId: 'STOCKS 1',
          quantityLoaded: 0,
          createdAt: 0,
          ibtDocuments: [
            IbtDocument(
              documentNo: 'IBT122773',
              total: 113,
              lineItems: const [
                IbtLineItem(
                  id: 'l1',
                  description: '12R22.5 M38 STOCK RETREAD',
                  size: '12R22.5',
                  rubber: 'M38',
                  sizeId: 22,
                  rubberId: 49,
                  targetTotal: 7,
                ),
              ],
            ),
          ],
        );

        final verdict = IbtScanEngine.evaluate(
          trip: trip,
          tyre: tyre,
          sessionUids: const {},
          operatorId: 7,
        );
        expect(verdict.isSuccess, isFalse);
        expect(verdict.message, contains('Not a stocks tyre'));
      },
      skip: live ? false : 'set RUN_LIVE_TESTS=1 to hit the live backend',
    );

    test(
      'live fixed operator resolves to a personnel id',
      () async {
        final id = await IbtScanApi.resolveOperatorId();
        expect(id, isNotNull);
        expect(id, greaterThan(0));
      },
      skip: live ? false : 'set RUN_LIVE_TESTS=1 to hit the live backend',
    );
  });
}
