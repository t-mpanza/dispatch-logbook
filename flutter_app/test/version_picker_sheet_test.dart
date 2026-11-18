import 'dart:convert';
import 'dart:io';

import 'package:dispatch_diary/data/services/update_service.dart';
import 'package:dispatch_diary/presentation/widgets/version_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The in-app rollback: every release is listed, the current one is
/// badged, older ones offer INSTALL — same verified pipeline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final releasesJson = jsonEncode([
    {
      'tag_name': 'v3.9.4',
      'name': 'Dispatch Diary v3.9.4',
      'body': 'latest',
      'published_at': '2026-11-18T04:00:00Z',
      'draft': false,
      'assets': [
        {
          'name': 'DispatchDiary-v3.9.4.apk',
          'browser_download_url': 'https://example.com/v3.9.4.apk',
          'size': 73924608,
          'digest': 'sha256:aaa111',
        },
      ],
    },
    {
      'tag_name': 'v3.9.3',
      'name': 'Dispatch Diary v3.9.3',
      'published_at': '2026-11-17T04:00:00Z',
      'assets': [
        {
          'name': 'DispatchDiary-v3.9.3.apk',
          'browser_download_url': 'https://example.com/v3.9.3.apk',
          'size': 70000000,
        },
      ],
    },
    {
      'tag_name': 'v3.9.2-draft',
      'draft': true,
      'assets': const [],
    },
    {'tag_name': 'junk-tag', 'assets': const []},
  ]);

  MockClient client() => MockClient((request) async {
        expect(request.url.toString(), contains('/releases'));
        final page = request.url.queryParameters['page'] ?? '1';
        if (page != '1') return http.Response('[]', 200);
        return http.Response(releasesJson, 200);
      });

  test('listReleases parses releases, skips drafts and junk tags', () async {
    final releases = await UpdateService.listReleases(client: client());
    expect(releases.length, 2);
    expect(releases.first.tag, 'v3.9.4');
    expect(releases.first.apkSizeBytes, 73924608);
    expect(releases.first.apkSha256, 'aaa111');
    expect(releases[1].tag, 'v3.9.3');
    expect(releases[1].apkSha256, isNull);
  });

  testWidgets('version picker lists releases with INSTALLED badge',
      (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final base = Directory.systemTemp.createTempSync('picker-test');
      addTearDown(() {
        try {
          base.deleteSync(recursive: true);
        } catch (_) {}
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: VersionPickerSheet(
            client: client(),
            storageBase: base,
            currentVersionOverride: 'v3.9.4',
          ),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('APP VERSIONS'), findsOneWidget);
      expect(find.text('v3.9.4'), findsOneWidget);
      expect(find.text('v3.9.3'), findsOneWidget);
      // getCurrentVersion is overridden — no PackageInfo dependency.
      expect(find.text('INSTALLED'), findsOneWidget);
      // The older release offers rollback.
      expect(find.text('INSTALL'), findsOneWidget);
      expect(find.text('junk-tag'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
