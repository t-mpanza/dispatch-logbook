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
    this.releaseChannel = 'Dispatch Diary',
  });
}

class UpdateService {
  static const String repoOwner = 't-mpanza';
  static const String repoName = 'dispatch-logbook';
  static const String releasesApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases';
  static const String releasesPageUrl =
      'https://github.com/$repoOwner/$repoName/releases';

  static const String releaseChannel = 'Dispatch Diary';

  /// Get current app version (e.g., 'v3.4.0')
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version}';
    } catch (_) {
      return 'v3.4.0';
    }
  }

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
      final assets = bestRelease['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final aName = (asset['name'] as String? ?? '').toLowerCase();
        if (aName.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
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

  /// Download the APK in-app, streaming progress (0.0 – 1.0) via the returned stream.
  /// Completes with the path to the downloaded file when finished.
  static Stream<({double progress, String? filePath, String? error})>
  downloadApk(String apkUrl) async* {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        yield (
          progress: 0.0,
          filePath: null,
          error: 'Server error ${response.statusCode}',
        );
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
