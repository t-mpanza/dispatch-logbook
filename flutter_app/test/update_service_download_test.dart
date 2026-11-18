import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dispatch_diary/data/services/update_download_store.dart';
import 'package:dispatch_diary/data/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// A client that streams [chunks] with the given status; [onRequest]
/// inspects each request (Range assertions).
class _ChunkedClient extends http.BaseClient {
  _ChunkedClient(this.chunks, this.status, {this.onRequest, this.total});

  final List<List<int>> chunks;
  final int status;
  final void Function(http.BaseRequest)? onRequest;
  final int? total;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onRequest?.call(request);
    final computed = chunks.fold<int>(0, (s, c) => s + c.length);
    return http.StreamedResponse(
      Stream.fromIterable(chunks),
      status,
      contentLength: total ?? computed,
    );
  }
}

/// Attempt 1 drops the connection after the first 1000 bytes; later
/// attempts resume the remainder via Range (206).
class _FlakyClient extends http.BaseClient {
  _FlakyClient(this.payload, this.onSend);

  final List<int> payload;
  final void Function(http.BaseRequest)? onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onSend?.call(request);
    final range = request.headers['Range'];
    if (range == null) {
      // First attempt: deliver 1000 bytes, then the connection dies.
      final first = payload.sublist(0, 1000);
      Stream<List<int>> flakyStream() async* {
        yield first;
        throw Exception('Connection closed');
      }

      return http.StreamedResponse(
        flakyStream(),
        200,
        contentLength: payload.length,
      );
    }
    final offset = int.parse(range.split('=')[1].split('-')[0]);
    return http.StreamedResponse(
      Stream.fromIterable([payload.sublist(offset)]),
      206,
      contentLength: payload.length - offset,
    );
  }
}

/// The resumable download engine — interrupted downloads persist and
/// RESUME via HTTP Range; completed files are SHA-256 verified.
void main() {
  late Directory base;

  final payload = List<int>.generate(4096, (i) => i % 251);
  final payloadHex = sha256.convert(payload).toString();

  UpdateInfo info() => UpdateInfo(
        hasUpdate: true,
        currentVersion: 'v3.8.1',
        latestVersion: 'v3.9.1',
        apkDownloadUrl: 'https://example.com/app.apk',
        apkSizeBytes: payload.length,
        apkSha256: payloadHex,
      );

  setUp(() {
    base = Directory.systemTemp.createTempSync('update-dl-test');
  });

  tearDown(() {
    try {
      base.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('fresh download completes, verifies and lands the file', () async {
    final client = _ChunkedClient(
      [payload.sublist(0, 1000), payload.sublist(1000)],
      200,
      onRequest: (r) =>
          expect(r.url.toString(), 'https://example.com/app.apk'),
    );

    final outcome = await UpdateService.resumeDownload(
      info(),
      client: client,
      storageBase: base,
    );
    expect(outcome.error, isNull);
    expect(outcome.filePath, isNotNull);
    expect(await File(outcome.filePath!).readAsBytes(), payload);

    final state = await UpdateDownloadStore(base).load('v3.9.1');
    expect(state!.phase, 'verified');
  });

  test('interrupted download persists the partial and RESUMES via Range',
      () async {
    // First attempt: 1000 bytes arrive, then the operator cancels.
    var chunks = 0;
    final client1 = _ChunkedClient(
      [
        payload.sublist(0, 1000),
        payload.sublist(1000, 2000),
        payload.sublist(2000),
      ],
      200,
      total: payload.length,
    );

    final attempt1 = await UpdateService.resumeDownload(
      info(),
      client: client1,
      storageBase: base,
      isCancelled: () => ++chunks > 1, // cancel before the 2nd chunk
    );
    expect(attempt1.error, 'cancelled');
    expect(
      await UpdateDownloadStore(base).partFile('v3.9.1').exists(),
      isTrue,
    );
    final partialState = await UpdateDownloadStore(base).load('v3.9.1');
    expect(partialState!.received, greaterThan(0));

    // Second attempt: the server must see the Range header.
    final seenRange = <String?>[];
    final client2 = _ChunkedClient(
      [payload.sublist(1000)],
      206,
      onRequest: (r) => seenRange.add(r.headers['Range']),
      total: payload.length - 1000,
    );

    final attempt2 = await UpdateService.resumeDownload(
      info(),
      client: client2,
      storageBase: base,
    );
    expect(attempt2.error, isNull);
    expect(seenRange.single, startsWith('bytes=1000-'));
    expect(await File(attempt2.filePath!).readAsBytes(), payload);
    expect(
      await UpdateDownloadStore(base).partFile('v3.9.1').exists(),
      isFalse,
    );
  });

  test('checksum mismatch deletes the file and errors', () async {
    final client = _ChunkedClient([payload], 200);
    final bad = UpdateInfo(
      hasUpdate: true,
      currentVersion: 'v3.8.1',
      latestVersion: 'v3.9.1',
      apkDownloadUrl: 'https://example.com/app.apk',
      apkSha256: 'deadbeef',
    );
    final outcome = await UpdateService.resumeDownload(
      bad,
      client: client,
      storageBase: base,
    );
    expect(outcome.filePath, isNull);
    expect(outcome.error, contains('Checksum mismatch'));
    expect(await UpdateDownloadStore(base).apkFile('v3.9.1').exists(),
        isFalse);
  });

  test('connection drops mid-transfer AUTO-RESUME with backoff', () async {
    // Attempt 1: 1000 bytes then the connection dies. Attempts 2+:
    // Range-resume the remainder.
    var sends = 0;
    final seenRange = <String?>[];
    final flaky = _FlakyClient(payload, (request) {
      sends++;
      seenRange.add(request.headers['Range']);
    });

    final outcome = await UpdateService.resumeDownload(
      info(),
      client: flaky,
      storageBase: base,
    );
    expect(outcome.error, isNull);
    expect(sends, 2);
    expect(seenRange[1], startsWith('bytes=1000-'));
    expect(await File(outcome.filePath!).readAsBytes(), payload);
  });

  test('non-retryable errors fail fast (no backoff loop)', () async {
    final client = _ChunkedClient(const [], 404);
    final outcome = await UpdateService.resumeDownload(
      info(),
      client: client,
      storageBase: base,
    );
    expect(outcome.error, contains('Server error 404'));
  });

  test('a verified file from a previous run installs without re-downloading',
      () async {
    // First: complete a normal download.
    final client = _ChunkedClient([payload], 200);
    final first = await UpdateService.resumeDownload(
      info(),
      client: client,
      storageBase: base,
    );
    expect(first.filePath, isNotNull);

    // Second: no HTTP at all — the file is returned instantly.
    var hit = false;
    final client2 = _ChunkedClient(
      const [],
      500,
      onRequest: (_) => hit = true,
    );
    final second = await UpdateService.resumeDownload(
      info(),
      client: client2,
      storageBase: base,
    );
    expect(hit, isFalse);
    expect(second.error, isNull);
    expect(second.filePath, first.filePath);

    // And existingDownloadState reports verified.
    final state = await UpdateService.existingDownloadState(
      'v3.9.1',
      storageBase: base,
    );
    expect(state!.phase, 'verified');
  });
}
