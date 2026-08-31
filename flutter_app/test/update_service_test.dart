import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dispatch_diary/data/services/update_service.dart';

void main() {
  group('UpdateService Tests', () {
    test('UpdateInfo model initialization on IBT Edition channel', () {
      final info = UpdateInfo(
        hasUpdate: true,
        currentVersion: 'v2.1.0-rc1',
        latestVersion: 'v2.1.0-rc2',
        releaseTitle: 'Dispatch Diary IBT v2.1.0-rc2',
        releaseNotes: '- In-app AWS Web Sign-In\n- Automated OAuth credential storage',
        apkDownloadUrl: 'https://github.com/t-mpanza/dispatch-logbook/releases/download/v2.1.0-rc2-ibt/DispatchDiary_IBT_v2.1.0-rc2.apk',
        releaseUrl: 'https://github.com/t-mpanza/dispatch-logbook/releases/tag/v2.1.0-rc2-ibt',
      );

      expect(info.hasUpdate, isTrue);
      expect(info.currentVersion, equals('v2.1.0-rc1'));
      expect(info.latestVersion, equals('v2.1.0-rc2'));
      expect(info.releaseChannel, equals('IBT Edition'));
      expect(info.apkDownloadUrl, contains('.apk'));
    });

    test('isNewerVersion compares RC pre-release versions accurately', () {
      expect(UpdateService.isNewerVersion('v2.1.0-rc1', 'v2.1.0-rc2'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0-rc2', 'v2.1.0-rc1'), isFalse);
      expect(UpdateService.isNewerVersion('v2.1.0-rc2', 'v2.1.0-rc2'), isFalse);
      expect(UpdateService.isNewerVersion('v2.1.0-rc1', 'v2.1.1-rc1'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0-rc1', 'v2.0.55'), isFalse);
    });

    test('Filters out non-IBT mainline releases and stays on IBT track', () async {
      final mockHttpClient = MockClient((request) async {
        final mockReleases = [
          {
            "tag_name": "v2.0.55",
            "name": "Dispatch Diary Standard Mainline",
            "body": "Standard main branch release",
            "assets": [
              {
                "name": "app-release.apk",
                "browser_download_url": "https://github.com/t-mpanza/dispatch-logbook/releases/download/v2.0.55/app-release.apk"
              }
            ]
          }
        ];
        return http.Response(jsonEncode(mockReleases), 200);
      });

      final updateInfo = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(updateInfo.hasUpdate, isFalse);
      expect(updateInfo.releaseChannel, equals('IBT Edition'));
    });

    test('Identifies and prompts when newer IBT candidate is released', () async {
      final mockHttpClient = MockClient((request) async {
        final mockReleases = [
          {
            "tag_name": "v2.1.0-rc2-ibt",
            "name": "Dispatch Diary (IBT Edition) v2.1.0-rc2",
            "body": "New AWS Web Sign-In and automated credential storage",
            "assets": [
              {
                "name": "DispatchDiary_IBT_v2.1.0-rc2.apk",
                "browser_download_url": "https://github.com/t-mpanza/dispatch-logbook/releases/download/v2.1.0-rc2-ibt/DispatchDiary_IBT_v2.1.0-rc2.apk"
              }
            ]
          }
        ];
        return http.Response(jsonEncode(mockReleases), 200);
      });

      final updateInfo = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(updateInfo.latestVersion, equals('v2.1.0-rc2-ibt'));
      expect(updateInfo.apkDownloadUrl, contains('DispatchDiary_IBT_v2.1.0-rc2.apk'));
    });
  });
}
