import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_download_store.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String? releaseTitle;
  final String? releaseNotes;
  final String? apkDownloadUrl;
  final int? apkSizeBytes;
  final String? apkSha256;
  final String? releaseUrl;
  final String? publishedAt;
  final String releaseChannel;

  UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.releaseTitle,
    this.releaseNotes,
    this.apkDownloadUrl,
    this.apkSizeBytes,
    this.apkSha256,
    this.releaseUrl,
    this.publishedAt,
    this.releaseChannel = 'Dispatch Diary',
  });
}
/// One published GitHub release — drives the in-app version/rollback
/// picker.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.name,
    this.notes,
    this.publishedAt,
    this.apkUrl,
    this.apkSizeBytes,
    this.apkSha256,
  });

  final String tag;
  final String name;
  final String? notes;
  final String? publishedAt;
  final String? apkUrl;
  final int? apkSizeBytes;
  final String? apkSha256;

  UpdateInfo asUpdateInfo(String currentVersion) => UpdateInfo(
        hasUpdate: tag != currentVersion,
        currentVersion: currentVersion,
        latestVersion: tag,
        releaseTitle: name,
        releaseNotes: notes,
        apkDownloadUrl: apkUrl,
        apkSizeBytes: apkSizeBytes,
        apkSha256: apkSha256,
        releaseUrl: UpdateService.releasesPageUrl,
        publishedAt: publishedAt,
        releaseChannel: UpdateService.releaseChannel,
      );
}




class UpdateService {
  static const String repoOwner = 't-mpanza';
  static const String repoName = 'dispatch-logbook';
  static const String releasesApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases';
  static const String releasesPageUrl =
      'https://github.com/$repoOwner/$repoName/releases';

  static const String releaseChannel = 'Dispatch Diary';

  /// Get current app version (e.g., 'v3.9.7')
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version}';
    } catch (_) {
      return 'v3.9.7';
    }
  }

  /// Every published release, newest first — including OLDER ones, for
  /// rollback. Drafts and junk tags are skipped.
  static Future<List<ReleaseInfo>> listReleases({
    http.Client? client,
    int limit = 10,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final releases = await _fetchReleases(httpClient);
      if (releases == null) return const [];
      final out = <ReleaseInfo>[];
      for (final rel in releases) {
        final map = rel as Map<String, dynamic>;
        if (map['draft'] == true) continue;
        final tag = map['tag_name'] as String? ?? '';
        if (!_looksLikeVersion(tag) && tag.toLowerCase() != 'main') continue;
        final apk = _apkAsset(map);
        out.add(ReleaseInfo(
          tag: tag,
          name: (map['name'] as String?) ?? tag,
          notes: map['body'] as String?,
          publishedAt: map['published_at'] as String?,
          apkUrl: apk?.$1,
          apkSizeBytes: apk?.$2,
          apkSha256: apk?.$3,
        ));
        if (out.length >= limit) break;
      }
      return out;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// The first APK asset on a release: (url, size, sha256).
  static (String?, int?, String?)? _apkAsset(Map<String, dynamic> release) {
    final assets = release['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      final aName = (asset['name'] as String? ?? '').toLowerCase();
      if (!aName.endsWith('.apk')) continue;
      String? sha256;
      final digest = asset['digest'] as String?;
      if (digest != null && digest.startsWith('sha256:')) {
        sha256 = digest.substring('sha256:'.length).toLowerCase();
      }
      return (
        asset['browser_download_url'] as String?,
        (asset['size'] as num?)?.toInt(),
        sha256,
      );
    }
    return null;
  }

  /// Hand the verified APK to the system installer (MainActivity channel).
  static Future<void> installApk(String path) async {
    await installChannel.invokeMethod('installApk', {'path': path});
  }

  static const MethodChannel installChannel = MethodChannel(
    'com.dispatchdiary.dispatch_diary/install',
  );

  /// Check GitHub releases for any newer published release with an APK asset.
  ///
  /// Strengthened for v3: only releases that are genuinely NEWER than the
  /// installed version are considered, candidates are compared by semantic
  /// version (not GitHub publish order), and bogus tags (e.g. "main") are
  /// ignored — so the updater can never point at an older APK.
  static Future<UpdateInfo> checkForUpdates({http.Client? client}) async {
    final currentVer = await getCurrentVersion();
    final httpClient = client ?? http.Client();

    try {
      final releases = await _fetchReleases(httpClient);
      if (releases == null) {
        return UpdateInfo(
          hasUpdate: false,
          currentVersion: currentVer,
          latestVersion: currentVer,
          releaseNotes: 'Could not reach the update server.',
          releaseUrl: releasesPageUrl,
          releaseChannel: releaseChannel,
        );
      }

      // Collect eligible candidates: published, stable, APK-carrying, and
      // tagged with a real semantic version newer than what is installed.
      Map<String, dynamic>? bestRelease;
      String bestTag = '';
      for (final rel in releases) {
        final map = rel as Map<String, dynamic>;
        if (map['draft'] == true || map['prerelease'] == true) continue;

        final tagName = map['tag_name'] as String? ?? '';
        if (tagName.toLowerCase().contains('-rc')) continue;
        if (!_looksLikeVersion(tagName)) continue;
        if (!isNewerVersion(currentVer, tagName)) continue;

        final assets = map['assets'] as List<dynamic>? ?? [];
        final hasApk = assets.any(
          (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
        );
        if (!hasApk) continue;

        if (bestRelease == null ||
            compareVersions(tagName, bestTag) > 0) {
          bestRelease = map;
          bestTag = tagName;
        }
      }

      if (bestRelease == null) {
        return UpdateInfo(
          hasUpdate: false,
          currentVersion: currentVer,
          latestVersion: currentVer,
          releaseTitle: 'Dispatch Diary',
          releaseNotes: 'You are on the latest release ($currentVer).',
          releaseUrl: releasesPageUrl,
          releaseChannel: releaseChannel,
        );
      }

      final latestTag = bestRelease['tag_name'] as String? ?? '';
      final title = bestRelease['name'] as String? ?? latestTag;
      final body = bestRelease['body'] as String? ?? '';
      final releaseHtmlUrl =
          bestRelease['html_url'] as String? ?? releasesPageUrl;
      final publishedAt = bestRelease['published_at'] as String?;

      // Find APK asset (prefer one named after the tag, fall back to first .apk)
      String? apkUrl;
      int? apkSize;
      String? apkSha256;
      final assets = bestRelease['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final aName = (asset['name'] as String? ?? '').toLowerCase();
        if (aName.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          apkSize = (asset['size'] as num?)?.toInt();
          // GitHub exposes asset digests as 'sha256:<hex>' when the
          // upload had a checksum; absent otherwise.
          final digest = asset['digest'] as String?;
          if (digest != null && digest.startsWith('sha256:')) {
            apkSha256 = digest.substring('sha256:'.length).toLowerCase();
          }
          break;
        }
      }

      return UpdateInfo(
        hasUpdate: true,
        currentVersion: currentVer,
        latestVersion: latestTag.isNotEmpty ? latestTag : currentVer,
        releaseTitle: title,
        releaseNotes: body,
        apkDownloadUrl: apkUrl,
        apkSizeBytes: apkSize,
        apkSha256: apkSha256,
        releaseUrl: releaseHtmlUrl,
        publishedAt: publishedAt,
        releaseChannel: releaseChannel,
      );
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return UpdateInfo(
        hasUpdate: false,
        currentVersion: currentVer,
        latestVersion: currentVer,
        releaseNotes: 'Could not fetch updates: $e',
        releaseUrl: releasesPageUrl,
        releaseChannel: releaseChannel,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Fetch release pages (newest first) until an empty page or a page cap.
  static Future<List<dynamic>?> _fetchReleases(http.Client httpClient) async {
    final all = <dynamic>[];
    for (var page = 1; page <= 5; page++) {
      final uri = Uri.parse('$releasesApiUrl?per_page=100&page=$page');
      final response = await httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'DispatchDiary-App',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('GitHub API returned ${response.statusCode}');
      }

      final pageList = jsonDecode(response.body) as List<dynamic>;
      if (pageList.isEmpty) break;
      all.addAll(pageList);
    }
    return all;
  }

  /// A release tag is only a valid target when it parses as a version.
  static bool _looksLikeVersion(String tag) {
    final cleaned = tag
        .replaceAll(RegExp(r'-ibt$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\+\d+$'), '')
        .replaceFirst('v', '');
    return RegExp(r'^\d+\.\d+\.\d+').hasMatch(cleaned);
  }

  /// Three-way version comparison. Returns -1, 0, or 1.
  static int compareVersions(String a, String b) {
    if (isNewerVersion(a, b)) return 1;
    if (isNewerVersion(b, a)) return -1;
    return 0;
  }

  /// Resumable APK download with persistence + SHA-256 verification.
  ///
  /// - A COMPLETE, checksum-verified file → instant (filePath, no error).
  /// - A partial file from a previous attempt → HTTP Range resume.
  /// - No state → fresh download to `<support>/updates/<version>.apk.part`.
  /// - Progress is persisted so kills/dismissals never lose work.
  /// - [isCancelled] turns true when the operator pauses — the partial
  ///   file and its byte count are kept for the next resume.
  /// Resumable download with AUTO-RETRY: connection drops mid-transfer
  /// (GitHub CDN / flaky Wi-Fi) resume automatically with backoff — the
  /// operator sees the percentage keep climbing, never a hard error.
  static Future<({String? filePath, String? error})> resumeDownload(
    UpdateInfo info, {
    http.Client? client,
    Directory? storageBase,
    void Function(double progress, int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    const maxAttempts = 5;
    var attempt = 0;
    while (true) {
      attempt++;
      final outcome = await _resumeAttempt(
        info,
        client: client,
        storageBase: storageBase,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      if (outcome.error == null || outcome.error == 'cancelled') {
        return outcome;
      }
      final message = outcome.error!.toLowerCase();
      final retryable = message.contains('connection') ||
          message.contains('closed') ||
          message.contains('socket') ||
          message.contains('reset') ||
          message.contains('stream') ||
          message.contains('server error 5');
      if (!retryable || attempt >= maxAttempts) return outcome;
      // Backoff, then resume from the persisted byte count.
      await Future<void>.delayed(Duration(seconds: attempt));
    }
  }

  static Future<({String? filePath, String? error})> _resumeAttempt(
    UpdateInfo info, {
    http.Client? client,
    Directory? storageBase,
    void Function(double progress, int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final url = info.apkDownloadUrl;
    if (url == null) {
      return (filePath: null, error: 'No APK asset on this release');
    }
    final version = info.latestVersion;
    final store = UpdateDownloadStore(
      storageBase ?? Directory((await getApplicationSupportDirectory()).path),
    );
    await store.ensureDir();
    final own = client ?? http.Client();
    try {
      var state = await store.load(version);
      final complete = store.apkFile(version);

      // 1. Already complete? Verify (or delete corrupt) and ship it.
      if (await complete.exists()) {
        if (await _verifySha256(complete, info.apkSha256)) {
          await store.save(
            UpdateDownloadState(
              version: version,
              received: await complete.length(),
              total: await complete.length(),
              url: url,
              sha256: info.apkSha256,
              phase: 'verified',
            ),
          );
          return (filePath: complete.path, error: null);
        }
        await complete.delete();
        state = null;
      }

      final part = store.partFile(version);
      var received = 0;
      if (state != null &&
          state.url == url &&
          state.phase == 'downloading' &&
          await part.exists()) {
        final onDisk = await part.length();
        // Trust the persisted count only when it matches the file;
        // a corrupt partial restarts from zero.
        received = onDisk == state.received ? onDisk : 0;
      }
      if (received == 0) {
        await part.create(recursive: true);
        await part.writeAsBytes(const []);
      }

      // 2. Range-resume (or fresh GET when nothing exists).
      final request = http.Request('GET', Uri.parse(url));
      if (received > 0) {
        request.headers['Range'] = 'bytes=$received-';
      }
      final response = await own.send(request);

      if (response.statusCode == 200) {
        // Server ignored the Range — start over.
        received = 0;
        await part.writeAsBytes(const []);
      } else if (response.statusCode != 206) {
        return (
          filePath: null,
          error: 'Server error ${response.statusCode}',
        );
      }

      final total = response.contentLength != null
          ? received + response.contentLength!
          : 0;
      final sink = part.openWrite(mode: FileMode.append);
      var lastPersist = received;
      try {
        await for (final chunk in response.stream) {
          if (isCancelled?.call() ?? false) {
            await sink.flush();
            await sink.close();
            await store.save(
              UpdateDownloadState(
                version: version,
                received: received,
                total: total,
                url: url,
                sha256: info.apkSha256,
              ),
            );
            return (
              filePath: null,
              error: 'cancelled',
            );
          }
          sink.add(chunk);
          received += chunk.length;
          final progress = total > 0 ? received / total : -1.0;
          onProgress?.call(progress.clamp(0.0, 1.0), received, total);
          if (received - lastPersist >= 1024 * 1024) {
            await sink.flush();
            await store.save(
              UpdateDownloadState(
                version: version,
                received: received,
                total: total,
                url: url,
                sha256: info.apkSha256,
              ),
            );
            lastPersist = received;
          }
        }
        await sink.flush();
        await sink.close();
      } catch (e) {
        await sink.flush();
        await sink.close();
        await store.save(
          UpdateDownloadState(
            version: version,
            received: received,
            total: total,
            url: url,
            sha256: info.apkSha256,
          ),
        );
        return (filePath: null, error: e.toString());
      }

      // 3. Complete → move to .apk, verify, keep only this version.
      await part.rename(complete.path);
      if (!await _verifySha256(complete, info.apkSha256)) {
        await store.clear(version);
        return (filePath: null, error: 'Checksum mismatch — redownloading');
      }
      await store.save(
        UpdateDownloadState(
          version: version,
          received: received,
          total: total,
          url: url,
          sha256: info.apkSha256,
          phase: 'verified',
        ),
      );
      await store.pruneExcept(version);
      return (filePath: complete.path, error: null);
    } finally {
      if (client == null) own.close();
    }
  }

  /// Best-effort checksum verification; no expected digest = pass.
  static Future<bool> _verifySha256(File file, String? expectedHex) async {
    if (expectedHex == null || expectedHex.isEmpty) return true;
    try {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString().toLowerCase() == expectedHex.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  /// What a previous attempt left behind — drives RESUME (n%) vs UPDATE
  /// NOW in the dialog.
  static Future<UpdateDownloadState?> existingDownloadState(
    String version, {
    Directory? storageBase,
  }) async {
    try {
      final store = UpdateDownloadStore(
        storageBase ??
            Directory((await getApplicationSupportDirectory()).path),
      );
      final state = await store.load(version);
      if (state == null) return null;
      final complete = await store.apkFile(version).exists();
      if (complete) {
        return state.copyWith(phase: 'verified');
      }
      return state;
    } catch (_) {
      return null;
    }
  }

  /// Open the release page in browser as a fallback
  static Future<bool> openReleasePage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Compare two version strings, returning true if [latest] > [current].
  /// Handles formats: v2.1.0, v2.1.0-rc5, v2.1.0-rc5-ibt
  static bool isNewerVersion(String current, String latest) {
    if (latest.isEmpty) return false;

    // Strip any build metadata (+N) and known suffixes (-ibt)
    String clean(String s) => s
        .replaceAll(RegExp(r'-ibt$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\+\d+$'), '')
        .replaceFirst('v', '');

    final c = clean(current);
    final l = clean(latest);

    if (c == l) return false;

    // Split into base (e.g. "2.1.0") and pre-release (e.g. "rc5")
    String base(String s) => s.split('-').first;
    String? pre(String s) => s.contains('-') ? s.split('-').last : null;

    final cBase = base(c).split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final lBase = base(l).split('.').map((p) => int.tryParse(p) ?? 0).toList();

    while (cBase.length < 3) {
      cBase.add(0);
    }
    while (lBase.length < 3) {
      lBase.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (lBase[i] > cBase[i]) return true;
      if (lBase[i] < cBase[i]) return false;
    }

    // Same base version — compare RC numbers
    int rcNum(String? p) {
      if (p == null) return 999999; // stable > any RC
      final m = RegExp(r'rc(\d+)', caseSensitive: false).firstMatch(p);
      return m != null ? (int.tryParse(m.group(1)!) ?? 0) : 0;
    }

    return rcNum(pre(l)) > rcNum(pre(c));
  }
}
