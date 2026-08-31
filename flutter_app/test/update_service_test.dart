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
        latestVersion: 'v2.1.1-rc1',
        releaseTitle: 'Dispatch Diary IBT v2.1.1-rc1',
        releaseNotes: '- IBT scanning enhancements\n- Multi-line fixes',
        apkDownloadUrl: 'https://github.com/t-mpanza/dispatch-logbook/releases/download/v2.1.1-rc1/DispatchDiary_IBT_v2.1.1-rc1.apk',
        releaseUrl: 'https://github.com/t-mpanza/dispatch-logbook/releases/tag/v2.1.1-rc1',
      );

      expect(info.hasUpdate, isTrue);
      expect(info.currentVersion, equals('v2.1.0-rc1'));
      expect(info.latestVersion, equals('v2.1.1-rc1'));
      expect(info.releaseChannel, equals('IBT Edition'));
      expect(info.apkDownloadUrl, contains('.apk'));
    });

    test('Filters out non-IBT mainline releases and stays on IBT track', () async {
      final mockHttpClient = MockClient((request) async {
        final mockReleases = [
          {
            "tag_name": "v2.0.44",
            "name": "Dispatch Diary Standard Mainline",
            "body": "Standard main branch release",
            "assets": [
              {
                "name": "app-release.apk",
                "browser_download_url": "https://github.com/t-mpanza/dispatch-logbook/releases/download/v2.0.44/app-release.apk"
              }
            ]
          }
        ];
        return http.Response(jsonEncode(mockReleases), 200);
      });

      final updateInfo = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(updateInfo.hasUpdate, isFalse);
      expect(updateInfo.releaseChannel, equals('IBT Edition'));
      expect(updateInfo.releaseNotes, contains('latest standalone IBT release candidate'));
    });

    test('Identifies and prompts when newer IBT candidate is released', () async {
      final mockHttpClient = MockClient((request) async {
        final mockReleases = [
          {
            "tag_name": "v2.2.0-ibt-rc2",
            "name": "Dispatch Diary IBT Edition v2.2.0-rc2",
            "body": "New IBT features and multi-truck performance",
            "assets": [
              {
                "name": "DispatchDiary_IBT_v2.2.0-rc2.apk",
                "browser_download_url": "https://github.com/t-mpanza/dispatch-logbook/releases/download/v2.2.0-ibt-rc2/DispatchDiary_IBT_v2.2.0-rc2.apk"
              }
            ]
          }
        ];
        return http.Response(jsonEncode(mockReleases), 200);
      });

      final updateInfo = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(updateInfo.hasUpdate, isTrue);
      expect(updateInfo.latestVersion, equals('v2.2.0-ibt-rc2'));
      expect(updateInfo.apkDownloadUrl, contains('DispatchDiary_IBT_v2.2.0-rc2.apk'));
    });
  });
}
