import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/services/update_service.dart';

void main() {
  group('UpdateService Tests', () {
    test('UpdateInfo model initialization', () {
      final info = UpdateInfo(
        hasUpdate: true,
        currentVersion: 'v1.0.0',
        latestVersion: 'v1.0.5',
        releaseTitle: 'Dispatch Diary v1.0.5',
        releaseNotes: '- Performance fixes\n- Offline sync updates',
        apkDownloadUrl: 'https://github.com/t-mpanza/dispatch-logbook/releases/download/v1.0.5/dispatch-diary-v1.0.5.apk',
        releaseUrl: 'https://github.com/t-mpanza/dispatch-logbook/releases/tag/v1.0.5',
      );

      expect(info.hasUpdate, isTrue);
      expect(info.currentVersion, equals('v1.0.0'));
      expect(info.latestVersion, equals('v1.0.5'));
      expect(info.apkDownloadUrl, contains('.apk'));
    });
  });
}
