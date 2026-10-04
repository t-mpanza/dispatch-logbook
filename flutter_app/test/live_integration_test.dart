import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/services/appsync_manifest_service.dart';
import 'package:dispatch_diary/data/services/aws_auto_login_service.dart';

/// Live end-to-end integration tests.
///
/// These hit the real Cognito pool and AppSync API, so they only run when
/// RUN_LIVE_TESTS=1 is set:
///   RUN_LIVE_TESTS=1 flutter test test/live_integration_test.dart
void main() {
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
  });
}
