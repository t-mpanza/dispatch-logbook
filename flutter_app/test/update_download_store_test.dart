import 'dart:io';

import 'package:dispatch_diary/data/services/update_download_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory base;
  late UpdateDownloadStore store;

  setUp(() {
    base = Directory.systemTemp.createTempSync('update-store-test');
    store = UpdateDownloadStore(base);
  });

  tearDown(() {
    try {
      base.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('state round-trips through JSON', () async {
    await store.save(const UpdateDownloadState(
      version: 'v3.9.1',
      received: 1024,
      total: 4096,
      url: 'https://example.com/a.apk',
      sha256: 'abc123',
    ));
    final loaded = await store.load('v3.9.1');
    expect(loaded, isNotNull);
    expect(loaded!.received, 1024);
    expect(loaded.total, 4096);
    expect(loaded.progress, closeTo(0.25, 0.001));
    expect(loaded.phase, 'downloading');
  });

  test('missing state loads null; corrupt json loads null', () async {
    expect(await store.load('v9.9.9'), isNull);
    await store.ensureDir();
    await File('${base.path}/updates/v9.9.9.json').writeAsString('{not json');
    expect(await store.load('v9.9.9'), isNull);
  });

  test('pruneExcept keeps only the named version', () async {
    await store.ensureDir();
    for (final v in ['v3.8.1', 'v3.9.0', 'v3.9.1']) {
      await store.partFile(v).writeAsString('x');
      await store.save(UpdateDownloadState(
        version: v,
        received: 1,
        total: 2,
        url: 'u',
      ));
    }
    await store.pruneExcept('v3.9.1');
    expect(await store.partFile('v3.9.1').exists(), isTrue);
    expect(await store.partFile('v3.9.0').exists(), isFalse);
    expect(await store.stateFile('v3.8.1').exists(), isFalse);
  });

  test('clear removes state, partial and complete files', () async {
    await store.ensureDir();
    await store.partFile('v3.9.1').writeAsString('partial');
    await store.apkFile('v3.9.1').writeAsString('full');
    await store.save(const UpdateDownloadState(
      version: 'v3.9.1',
      received: 1,
      total: 2,
      url: 'u',
    ));
    await store.clear('v3.9.1');
    expect(await store.partFile('v3.9.1').exists(), isFalse);
    expect(await store.apkFile('v3.9.1').exists(), isFalse);
    expect(await store.stateFile('v3.9.1').exists(), isFalse);
  });
}
