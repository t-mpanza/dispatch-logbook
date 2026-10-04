import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/services/appsync_manifest_service.dart';

void main() {
  group('AppSync size resolution — 12R must stay 12R', () {
    test('description wins over size_id master map', () {
      // A 12R tyre line: backend size_id 22 would map to the metric
      // 315/80R22.5, but the manifest description says 12R22.5.
      final size = AppSyncManifestService.resolveSize(
        sizeId: 22,
        description: '12R22.5 RD2+',
      );
      expect(size, '12R22.5');
    });

    test('metric sizes still resolve from description', () {
      expect(
        AppSyncManifestService.resolveSize(
          sizeId: 22,
          description: '315/80R22.5 RD2+',
        ),
        '315/80R22.5',
      );
    });

    test('imperial 11R resolves correctly', () {
      expect(
        AppSyncManifestService.resolveSize(
          sizeId: 45,
          description: '11R22.5 MM84',
        ),
        '11R22.5',
      );
    });

    test('10.00R20 style imperial sizes are matched', () {
      expect(
        AppSyncManifestService.extractSize('10.00R20 K-Max S'),
        '10.00R20',
      );
    });

    test('falls back to the master map when description has no size', () {
      expect(
        AppSyncManifestService.resolveSize(
          sizeId: 45,
          description: 'TYRE ITEM',
        ),
        '11R22.5',
      );
    });

    test('returns null when neither source has a size', () {
      expect(
        AppSyncManifestService.resolveSize(
          sizeId: 99,
          description: 'UNKNOWN ITEM',
        ),
        isNull,
      );
    });

    test('imperial is preferred even inside mixed descriptions', () {
      expect(
        AppSyncManifestService.resolveSize(
          sizeId: 22,
          description: '315/80R22.5 (12R22.5)',
        ),
        '12R22.5',
      );
    });

    test('metric strings never false-match the imperial regex', () {
      // Regression: "80R22.5" inside "315/80R22.5" must not be extracted.
      expect(AppSyncManifestService.extractImperialSize('315/80R22.5'), isNull);
      expect(AppSyncManifestService.extractSize('315/80R22.5 RD2+'), '315/80R22.5');
    });

    group('live IBT 122773 ground truth', () {
      test('12R line resolves to 12R22.5 despite size_id 22', () {
        expect(
          AppSyncManifestService.resolveSize(
            sizeId: 22,
            description: '12R22.5 M38 STOCK RETREAD',
          ),
          '12R22.5',
        );
      });

      test('rubber pattern comes from description when master lacks the id', () {
        expect(
          AppSyncManifestService.resolveRubber(
            rubberId: 49,
            description: '12R22.5 M38 STOCK RETREAD',
          ),
          'M38',
        );
      });

      test('modern rubber codes all extract correctly', () {
        expect(AppSyncManifestService.extractRubber('315/80R22.5 M100 STOCK RETREAD'), 'M100');
        expect(AppSyncManifestService.extractRubber('315/80R22.5 M43 STOCK RETREAD'), 'M43');
        expect(AppSyncManifestService.extractRubber('315/80R22.5 M90L STOCK RETREAD'), 'M90L');
        expect(AppSyncManifestService.extractRubber('315/80R22.5 MM65 STOCK RETREAD'), 'MM65');
        expect(AppSyncManifestService.extractRubber('11R22.5 MM84 STOCK RETREAD'), 'MM84');
      });

      test('315 lines still resolve via description', () {
        expect(
          AppSyncManifestService.resolveSize(
            sizeId: 70,
            description: '315/80R22.5 M90L STOCK RETREAD',
          ),
          '315/80R22.5',
        );
      });
    });
  });
}
