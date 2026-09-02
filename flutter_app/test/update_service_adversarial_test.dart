import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dispatch_diary/data/services/update_service.dart';

void main() {
  group('UpdateService Adversarial Semver & isNewerVersion Tests', () {
    test('Stable vs Release Candidates comparison', () {
      // Upgrading from RC to final stable
      expect(UpdateService.isNewerVersion('v2.1.0-rc6', 'v2.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0-rc1', 'v2.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('2.1.0-rc99', '2.1.0'), isTrue);

      // Stable should not downgrade to RC of same base version
      expect(UpdateService.isNewerVersion('v2.1.0', 'v2.1.0-rc6'), isFalse);
      expect(UpdateService.isNewerVersion('v2.1.0', 'v2.1.0-rc1'), isFalse);

      // RC sequence progression
      expect(UpdateService.isNewerVersion('v2.1.0-rc1', 'v2.1.0-rc2'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0-rc2', 'v2.1.0-rc10'), isTrue); // multi-digit RC
      expect(UpdateService.isNewerVersion('v2.1.0-rc10', 'v2.1.0-rc2'), isFalse);
      expect(UpdateService.isNewerVersion('v2.1.0-rc5', 'v2.1.0-rc5'), isFalse);

      // RC to newer base version
      expect(UpdateService.isNewerVersion('v2.0.0', 'v2.1.0-rc1'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0-rc1', 'v2.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('v2.0.55', 'v2.1.0-rc1'), isTrue);
    });

    test('Pre-release tag stripping (-ibt, +build, v prefixes)', () {
      // Suffix -ibt stripping
      expect(UpdateService.isNewerVersion('v2.1.0-ibt', 'v2.1.0'), isFalse); // same base version
      expect(UpdateService.isNewerVersion('v2.1.0-rc5-ibt', 'v2.1.0'), isTrue); // rc to stable
      expect(UpdateService.isNewerVersion('v2.1.0-rc5-ibt', 'v2.1.0-rc6'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0-rc5-ibt', 'v2.1.0-rc5'), isFalse);
      expect(UpdateService.isNewerVersion('v2.1.0-rc5-IBT', 'v2.1.0-rc6'), isTrue); // case insensitivity

      // Build metadata (+N) stripping
      expect(UpdateService.isNewerVersion('v2.1.0+10', 'v2.1.0+11'), isFalse); // build metadata alone != newer
      expect(UpdateService.isNewerVersion('v2.1.0+10', 'v2.1.1+1'), isTrue); // patch bump with build meta
      expect(UpdateService.isNewerVersion('v2.1.0+100', 'v2.2.0'), isTrue);

      // 'v' prefix variation
      expect(UpdateService.isNewerVersion('2.1.0', 'v2.1.1'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0', '2.1.1'), isTrue);
      expect(UpdateService.isNewerVersion('2.1.0', '2.1.0'), isFalse);
    });

    test('Fallback versions and malformed version strings', () {
      // Branch fallback versions (e.g., 'main', 'master', 'dev-build')
      expect(UpdateService.isNewerVersion('main', 'v2.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('master', 'v2.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('dev-build', 'v1.0.0'), isTrue);

      // Latest being fallback/unparseable should not trigger update from valid version
      expect(UpdateService.isNewerVersion('v2.1.0', 'main'), isFalse);
      expect(UpdateService.isNewerVersion('v2.1.0', 'master'), isFalse);
      expect(UpdateService.isNewerVersion('v2.1.0', 'invalid-tag'), isFalse);

      // Empty strings
      expect(UpdateService.isNewerVersion('', 'v2.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0', ''), isFalse);
      expect(UpdateService.isNewerVersion('', ''), isFalse);

      // Partial semver strings
      expect(UpdateService.isNewerVersion('v2', 'v2.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1', 'v2.1.0'), isFalse);
      expect(UpdateService.isNewerVersion('v2.1', 'v2.2.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0', 'v2.2'), isTrue);

      // Non-RC pre-releases
      expect(UpdateService.isNewerVersion('v2.1.0-alpha', 'v2.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0-beta1', 'v2.1.0'), isTrue);
    });

    test('Major, Minor, Patch Semver matrix transitions', () {
      // Major
      expect(UpdateService.isNewerVersion('v1.9.9', 'v2.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.0.0', 'v1.9.9'), isFalse);

      // Minor
      expect(UpdateService.isNewerVersion('v2.0.9', 'v2.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0', 'v2.0.9'), isFalse);

      // Patch
      expect(UpdateService.isNewerVersion('v2.1.0', 'v2.1.1'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.1', 'v2.1.0'), isFalse);

      // High component values
      expect(UpdateService.isNewerVersion('v2.99.100', 'v2.100.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.100.0', 'v2.99.100'), isFalse);
    });
  });

  group('UpdateService Asset Discovery & API Robustness Tests', () {
    test('Filters out draft releases and selects newest published release with APK', () async {
      final mockHttpClient = MockClient((request) async {
        final mockReleases = [
          {
            "tag_name": "v2.3.0",
            "name": "Draft release",
            "draft": true,
            "assets": [
              {
                "name": "DispatchDiary-v2.3.0.apk",
                "browser_download_url": "https://example.com/draft.apk"
              }
            ]
          },
          {
            "tag_name": "v2.2.0",
            "name": "Published release v2.2.0",
            "draft": false,
            "assets": [
              {
                "name": "DispatchDiary-v2.2.0.apk",
                "browser_download_url": "https://example.com/v2.2.0.apk"
              }
            ]
          }
        ];
        return http.Response(jsonEncode(mockReleases), 200);
      });

      final info = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(info.latestVersion, equals('v2.2.0'));
      expect(info.apkDownloadUrl, equals('https://example.com/v2.2.0.apk'));
      expect(info.releaseTitle, equals('Published release v2.2.0'));
    });

    test('Skips release candidates in checkForUpdates() to target stable releases', () async {
      final mockHttpClient = MockClient((request) async {
        final mockReleases = [
          {
            "tag_name": "v2.2.0-rc1",
            "name": "RC Candidate",
            "draft": false,
            "assets": [
              {
                "name": "DispatchDiary-v2.2.0-rc1.apk",
                "browser_download_url": "https://example.com/rc1.apk"
              }
            ]
          },
          {
            "tag_name": "v2.1.5",
            "name": "Stable Release v2.1.5",
            "draft": false,
            "assets": [
              {
                "name": "DispatchDiary-v2.1.5.apk",
                "browser_download_url": "https://example.com/v2.1.5.apk"
              }
            ]
          }
        ];
        return http.Response(jsonEncode(mockReleases), 200);
      });

      final info = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(info.latestVersion, equals('v2.1.5'));
      expect(info.apkDownloadUrl, equals('https://example.com/v2.1.5.apk'));
    });

    test('Handles multiple assets and correctly identifies the .apk asset', () async {
      final mockHttpClient = MockClient((request) async {
        final mockReleases = [
          {
            "tag_name": "v2.2.0",
            "name": "Multi-asset Release",
            "draft": false,
            "assets": [
              {
                "name": "source.tar.gz",
                "browser_download_url": "https://example.com/source.tar.gz"
              },
              {
                "name": "app-release.aab",
                "browser_download_url": "https://example.com/app.aab"
              },
              {
                "name": "DispatchDiary-v2.2.0.apk",
                "browser_download_url": "https://example.com/valid.apk"
              },
              {
                "name": "checksums.txt",
                "browser_download_url": "https://example.com/checksums.txt"
              }
            ]
          }
        ];
        return http.Response(jsonEncode(mockReleases), 200);
      });

      final info = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(info.latestVersion, equals('v2.2.0'));
      expect(info.apkDownloadUrl, equals('https://example.com/valid.apk'));
    });

    test('Skips releases missing an APK asset and finds previous release with APK', () async {
      final mockHttpClient = MockClient((request) async {
        final mockReleases = [
          {
            "tag_name": "v2.3.0",
            "name": "Source only release",
            "draft": false,
            "assets": [
              {
                "name": "source.zip",
                "browser_download_url": "https://example.com/source.zip"
              }
            ]
          },
          {
            "tag_name": "v2.2.0",
            "name": "Release with APK",
            "draft": false,
            "assets": [
              {
                "name": "app.apk",
                "browser_download_url": "https://example.com/app.apk"
              }
            ]
          }
        ];
        return http.Response(jsonEncode(mockReleases), 200);
      });

      final info = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(info.latestVersion, equals('v2.2.0'));
      expect(info.apkDownloadUrl, equals('https://example.com/app.apk'));
    });

    test('Handles empty releases gracefully without exception', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });

      final info = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(info.hasUpdate, isFalse);
      expect(info.apkDownloadUrl, isNull);
    });

    test('Handles HTTP error codes gracefully (e.g. 404 / 500)', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final info = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(info.hasUpdate, isFalse);
      expect(info.releaseNotes, contains('404'));
    });

    test('Handles JSON decode or network exceptions gracefully', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response('Invalid Non-JSON response', 200);
      });

      final info = await UpdateService.checkForUpdates(client: mockHttpClient);
      expect(info.hasUpdate, isFalse);
      expect(info.releaseNotes, contains('Could not fetch updates'));
    });
  });
}
