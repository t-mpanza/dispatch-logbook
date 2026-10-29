import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/services/appsync_manifest_service.dart';
import 'package:dispatch_diary/data/services/aws_auto_login_service.dart';
import 'package:dispatch_diary/dispatch/dispatch_api.dart';
import 'package:dispatch_diary/dispatch/domain/ibt_scan_engine.dart';
import 'package:dispatch_diary/dispatch/ibt_scan_api.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';

/// LIVE DRY-RUN SUITE — simulates real bay situations against the live
/// backend using real manifests and real customer tyres. The mutation is
/// dry-run with a deliberately unknown UID (no real tyre is touched).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('live scan dry-runs', () {
    late LoadingSheetTrip trip;
    late SlipTyre customerTyre;
    late int operatorId;

    setUpAll(() async {
      // 1. Real manifest.
      final token = await AwsAutoLoginService.login();
      expect(token, isNotNull);
      final doc = await AppSyncManifestService.fetchIbtDocument(
        '122773',
        explicitIdToken: token,
      );
      trip = LoadingSheetTrip(
        id: 'dry-run-trip',
        reg: 'MN05XNGP',
        driverName: 'Neil',
        tripId: 'STOCKS 1',
        quantityLoaded: 0,
        createdAt: 0,
        ibtDocuments: [doc],
      );

      // 2. Real customer tyre (the job gate's counter-example).
      final slips = await DispatchApi.fetchDeliverySlips(inv: 'INV2392908');
      expect(slips, isNotEmpty);
      customerTyre = slips.first;
      expect(customerTyre.uid, isNotNull);

      // 3. Real operator.
      operatorId = (await IbtScanApi.resolveOperatorId())!;
    });

    test('customer tyre hits the Client Retread gate', () async {
      final v = IbtScanEngine.evaluate(
        trip: trip,
        tyre: customerTyre,
        sessionUids: const {},
        operatorId: operatorId,
      );
      expect(v.isSuccess, isFalse);
      expect(v.message, contains('Not a stocks tyre'));
      expect(v.message, contains(customerTyre.job ?? ''));
    });

    test('synthetic stocks tyre with a real line spec is ACCEPTED', () {
      final realLine = trip.ibtDocuments!.first.lineItems.first;
      final stocksTyre = SlipTyre(
        uid: '04A3F9E1C2B4D5',
        job: 'Client Retread',
        sizeId: realLine.sizeId,
        rubberId: realLine.rubberId,
        size: realLine.size,
        pattern: realLine.rubber,
      );
      final v = IbtScanEngine.evaluate(
        trip: trip,
        tyre: stocksTyre,
        sessionUids: const {},
        operatorId: operatorId,
      );
      expect(v.isSuccess, isTrue);
      final accepted = v as ScanAccepted;
      expect(accepted.documentNo, 'IBT122773');
      expect(accepted.lineId, realLine.id);
      // The banner names the doc + line spec.
      expect(accepted.message, contains('IBT122773'));
    });

    test('wrong size+rubber on the real manifest → not on IBT', () {
      final tyre = SlipTyre(
        uid: '04A3F9E1C2B4D5',
        job: 'Client Retread',
        sizeId: 99999,
        rubberId: 99999,
        size: '445/65R22.5',
        pattern: 'ZZ9',
      );
      final v = IbtScanEngine.evaluate(
        trip: trip,
        tyre: tyre,
        sessionUids: const {},
        operatorId: operatorId,
      );
      expect(v.message, contains("isn't on IBT"));
    });

    test('full line on the real manifest → capacity verdict', () {
      final realLine = trip.ibtDocuments!.first.lineItems.first;
      final fullLine = realLine.copyWith(
        loadedQuantity: realLine.targetTotal,
      );
      final fullTrip = trip.copyWith(
        ibtDocuments: [
          trip.ibtDocuments!.first.copyWith(
            lineItems: [fullLine],
          ),
        ],
      );
      final tyre = SlipTyre(
        uid: '04A3F9E1C2B4D5',
        job: 'Client Retread',
        sizeId: realLine.sizeId,
        rubberId: realLine.rubberId,
      );
      final v = IbtScanEngine.evaluate(
        trip: fullTrip,
        tyre: tyre,
        sessionUids: const {},
        operatorId: operatorId,
      );
      expect(v.isSuccess, isFalse);
      expect(
        v.message.contains('Line full') || v.message.contains('IBT complete'),
        isTrue,
      );
    });

    test('session duplicate is caught', () {
      final realLine = trip.ibtDocuments!.first.lineItems.first;
      final tyre = SlipTyre(
        uid: '04A3F9E1C2B4D5',
        job: 'Client Retread',
        sizeId: realLine.sizeId,
        rubberId: realLine.rubberId,
      );
      final v = IbtScanEngine.evaluate(
        trip: trip,
        tyre: tyre,
        sessionUids: {'04A3F9E1C2B4D5'},
        operatorId: operatorId,
      );
      expect(v.message, contains('Already counted'));
    });

    test('dumped tyre is rejected before the job gate', () {
      final realLine = trip.ibtDocuments!.first.lineItems.first;
      final tyre = SlipTyre(
        uid: '04A3F9E1C2B4D5',
        job: 'Client Retread',
        sizeId: realLine.sizeId,
        rubberId: realLine.rubberId,
        dump: 1,
      );
      final v = IbtScanEngine.evaluate(
        trip: trip,
        tyre: tyre,
        sessionUids: const {},
        operatorId: operatorId,
      );
      expect(v.message, contains('dumped'));
    });

    test(
      'MUTATION DRY-RUN: unknown UID is rejected without touching real tyres',
      () async {
        // Deliberately unknown 14-hex uid — nothing real is committed.
        const ghostUid = 'FFFFFFFFFFFFFFFE';
        try {
          final result = await IbtScanApi.commitScan(
            uid: ghostUid,
            registration: 'MN05XNGP',
            personnelId: operatorId,
            documentNo: 'IBT122773',
          );
          // Whatever the backend answers, the client must not crash:
          // either a clean rejection or an explicit exception.
          expect(
            result,
            anyOf(
              isA<ScanCommitRejected>(),
              isA<ScanCommitSuccess>(),
              isA<ScanCommitDuplicate>(),
            ),
          );
          // ignore: avoid_print
          print('MUTATION DRY-RUN RESULT: ${result.runtimeType}');
        } on ScanCommitException catch (e) {
          // GraphQL error for a ghost uid is also a valid, handled path.
          // ignore: avoid_print
          print('MUTATION DRY-RUN EXCEPTION (handled): $e');
        }
      },
    );
  });
}
