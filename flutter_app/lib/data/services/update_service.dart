import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String? releaseTitle;
  final String? releaseNotes;
  final String? apkDownloadUrl;
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
    this.releaseUrl,
    this.publishedAt,
    this.releaseChannel = 'IBT Edition',
  });
}

class UpdateService {
  static const String repoOwner = 't-mpanza';
  static const String repoName = 'dispatch-logbook';
  static const String releasesApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases';
  static const String releasesPageUrl =
      'https://github.com/$repoOwner/$repoName/releases';

  /// Release channel identifier for this standalone edition
  static const String releaseChannel = 'IBT Edition';

  /// Get current app version (e.g., 'v2.1.0-rc5')
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version}';
    } catch (_) {
      return 'v2.1.0-rc5';
    }
  }

  /// Check GitHub releases specifically for newer IBT Edition candidates
  static Future<UpdateInfo> checkForUpdates({http.Client? client}) async {
    final currentVer = await getCurrentVersion();
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient.get(
        Uri.parse(releasesApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'DispatchDiary-IBT-Edition',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('GitHub API returned ${response.statusCode}');
      }

      final releases = jsonDecode(response.body) as List<dynamic>;

      // Filter specifically for IBT-tagged releases, pick the newest one
      Map<String, dynamic>? bestIbtRelease;

      for (final rel in releases) {
        final map = rel as Map<String, dynamic>;
        final tag = (map['tag_name'] as String? ?? '').toLowerCase();
        final name = (map['name'] as String? ?? '').toLowerCase();
        final body = (map['body'] as String? ?? '').toLowerCase();

        final isIbtRelease =
            tag.contains('ibt') || name.contains('ibt') || body.contains('ibt edition');
        if (!isIbtRelease) continue;

        // Pick the first matching (GitHub API returns newest first)
        bestIbtRelease ??= map;
        break;
      }

      if (bestIbtRelease == null) {
        return UpdateInfo(
          hasUpdate: false,
          currentVersion: currentVer,
          latestVersion: currentVer,
          releaseTitle: 'Dispatch Diary (IBT Edition)',
          releaseNotes: 'You are on the latest IBT release candidate ($currentVer).',
          releaseUrl: releasesPageUrl,
          releaseChannel: releaseChannel,
        );
      }

      final latestTag = bestIbtRelease['tag_name'] as String? ?? '';
      final title = bestIbtRelease['name'] as String? ?? latestTag;
      final body = bestIbtRelease['body'] as String? ?? '';
      final releaseHtmlUrl = bestIbtRelease['html_url'] as String? ?? releasesPageUrl;
      final publishedAt = bestIbtRelease['published_at'] as String?;

      // Find the IBT APK asset
      String? apkUrl;
      final assets = bestIbtRelease['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final aName = (asset['name'] as String? ?? '').toLowerCase();
        if (aName.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          if (aName.contains('ibt')) break;
        }
      }

      // Extract a clean version tag for comparison, stripping the -ibt suffix
      // e.g. "v2.1.0-rc5-ibt" → "v2.1.0-rc5"
      final cleanLatestTag = latestTag.replaceAll(RegExp(r'-ibt$', caseSensitive: false), '');
      final cleanCurrentVer = currentVer.replaceAll(RegExp(r'-ibt$', caseSensitive: false), '');

      final hasUpdate = isNewerVersion(cleanCurrentVer, cleanLatestTag);

      return UpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVer,
        latestVersion: latestTag.isNotEmpty ? latestTag : currentVer,
        releaseTitle: title,
        releaseNotes: body,
        apkDownloadUrl: apkUrl,
        releaseUrl: releaseHtmlUrl,
        publishedAt: publishedAt,
        releaseChannel: releaseChannel,
      );
    } catch (e) {
      debugPrint('Error checking for IBT release channel updates: $e');
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

  /// Download the APK in-app, streaming progress (0.0 – 1.0) via the returned stream.
  /// Completes with the path to the downloaded file when finished.
  static Stream<({double progress, String? filePath, String? error})> downloadApk(
    String apkUrl,
  ) async* {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        yield (progress: 0.0, filePath: null, error: 'Server error ${response.statusCode}');
        return;
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final fileName = apkUrl.split('/').last.split('?').first;
      final file = File('${tempDir.path}/$fileName');

      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        final progress = contentLength > 0 ? received / contentLength : -1.0;
        yield (progress: progress.clamp(0.0, 1.0), filePath: null, error: null);
      }

      await sink.flush();
      await sink.close();

      yield (progress: 1.0, filePath: file.path, error: null);
    } catch (e) {
      yield (progress: 0.0, filePath: null, error: e.toString());
    } finally {
      client.close();
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

    // Strip -ibt suffix and any build metadata (+N)
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

    while (cBase.length < 3) { cBase.add(0); }
    while (lBase.length < 3) { lBase.add(0); }

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
