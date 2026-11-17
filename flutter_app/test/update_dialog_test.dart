import 'dart:io';

import 'package:dispatch_diary/data/services/update_download_store.dart';
import 'package:dispatch_diary/data/services/update_service.dart';
import 'package:dispatch_diary/presentation/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The modern updater sheet — update-available and up-to-date states.
void main() {
  UpdateInfo withUpdate() => UpdateInfo(
        hasUpdate: true,
        currentVersion: 'v3.8.1',
        latestVersion: 'v3.9.0',
        releaseNotes: '- The truck hub\n- Head-down scanning',
        apkDownloadUrl: 'https://example.com/app.apk',
        apkSizeBytes: 73924608,
        apkSha256: 'b14acf51212532717a51c9cf268f5cb990a6a90f99e610f0b52b7cca07825f83',
        releaseUrl: 'https://example.com/releases',
        publishedAt: '2026-11-17T04:06:49Z',
      );

  UpdateInfo upToDate() => UpdateInfo(
        hasUpdate: false,
        currentVersion: 'v3.9.0',
        latestVersion: 'v3.9.0',
      );

  testWidgets('update available: pill, changelog, single CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: UpdateDialog(updateInfo: withUpdate()))),
    );
    expect(find.text('Dispatch Diary'), findsOneWidget);
    expect(find.text('A new version is ready'), findsOneWidget);
    expect(find.text('v3.8.1'), findsOneWidget);
    expect(find.text('v3.9.0'), findsOneWidget);
    expect(find.text('UPDATE NOW — v3.9.0 · 70.5 MB'), findsOneWidget);
    expect(find.textContaining('The truck hub'), findsOneWidget);
    expect(find.text("WHAT'S NEW IN V3.9.0"), findsOneWidget);
    // Enterprise metadata: size + checksum + release date.
    expect(find.textContaining('70.5 MB'), findsWidgets);
    expect(find.textContaining('SHA-256 verified'), findsOneWidget);
    expect(find.textContaining('Released Nov 17'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a persisted partial shows RESUME, never re-download',
      (tester) async {
    await tester.runAsync(() async {
      final base = Directory.systemTemp.createTempSync('update-dialog-test');
      addTearDown(() {
        try {
          base.deleteSync(recursive: true);
        } catch (_) {}
      });
      final store = UpdateDownloadStore(base);
      await store.save(UpdateDownloadState(
        version: 'v3.9.0',
        received: 36962304, // exactly half of 73924608
        total: 73924608,
        url: 'https://example.com/app.apk',
        sha256: withUpdate().apkSha256,
      ));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UpdateDialog(updateInfo: withUpdate(), storageBase: base),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('RESUME — 50%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('up to date: no CTA, just the check', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: UpdateDialog(updateInfo: upToDate()))),
    );
    expect(find.text("You're up to date"), findsOneWidget);
    expect(find.textContaining('UPDATE NOW'), findsNothing);
    expect(find.textContaining('WHAT\'S NEW'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
