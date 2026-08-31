import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
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

  /// Get current app version (e.g., 'v2.1.0-rc1')
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version}';
    } catch (_) {
      return 'v2.1.0-rc1';
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
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('GitHub API returned ${response.statusCode}');
      }

      final releases = jsonDecode(response.body) as List<dynamic>;

      // Filter specifically for releases on the IBT channel
      Map<String, dynamic>? matchingIbtRelease;

      for (final rel in releases) {
        final map = rel as Map<String, dynamic>;
        final tag = (map['tag_name'] as String? ?? '').toLowerCase();
        final name = (map['name'] as String? ?? '').toLowerCase();
        final body = (map['body'] as String? ?? '').toLowerCase();

        final isIbtTag = tag.contains('ibt') || name.contains('ibt') || body.contains('ibt');
        final assets = map['assets'] as List<dynamic>? ?? [];
        final hasIbtApk = assets.any((a) => (a['name'] as String? ?? '').toLowerCase().contains('ibt'));

        if (isIbtTag || hasIbtApk) {
          matchingIbtRelease = map;
          break;
        }
      }

      if (matchingIbtRelease == null) {
        // No separate IBT remote release published yet; app is at latest RC
        return UpdateInfo(
          hasUpdate: false,
          currentVersion: currentVer,
          latestVersion: currentVer,
          releaseTitle: 'Dispatch Diary (IBT Edition)',
          releaseNotes: 'You are on the latest standalone IBT release candidate ($currentVer).',
          releaseUrl: releasesPageUrl,
          releaseChannel: releaseChannel,
        );
      }

      final latestTag = matchingIbtRelease['tag_name'] as String? ?? '';
      final title = matchingIbtRelease['name'] as String? ?? latestTag;
      final body = matchingIbtRelease['body'] as String? ?? '';
      final releaseHtmlUrl = matchingIbtRelease['html_url'] as String? ?? releasesPageUrl;
      final publishedAt = matchingIbtRelease['published_at'] as String?;

      // Find APK asset in release assets
      String? apkUrl;
      final assets = matchingIbtRelease['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final aName = (asset['name'] as String? ?? '').toLowerCase();
        if (aName.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          if (aName.contains('ibt')) break;
        }
      }

      final hasUpdate = isNewerVersion(currentVer, latestTag);

      return UpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVer,
        latestVersion: latestTag.isNotEmpty ? latestTag : currentVer,
        releaseTitle: title,
        releaseNotes: body,
        apkDownloadUrl: apkUrl ?? releaseHtmlUrl,
        releaseUrl: releaseHtmlUrl,
        publishedAt: publishedAt,
        releaseChannel: releaseChannel,
      );
    } catch (e) {
      debugPrint('Error checking for updates on IBT release channel: $e');
      return UpdateInfo(
        hasUpdate: false,
        currentVersion: currentVer,
        latestVersion: currentVer,
        releaseNotes: 'Could not fetch updates ($e)',
        releaseUrl: releasesPageUrl,
        releaseChannel: releaseChannel,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Launch APK download or release page in browser/installer
  static Future<bool> openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Helper to compare semver versions (e.g. 'v2.1.0-rc2' vs 'v2.1.0-rc1')
  static bool isNewerVersion(String current, String latest) {
    if (latest.isEmpty || current == latest) return false;

    int extractRc(String str) {
      final match = RegExp(r'rc[-_.]?(\d+)', caseSensitive: false).firstMatch(str);
      return match != null ? (int.tryParse(match.group(1)!) ?? 0) : 999999;
    }

    String cleanMainSemver(String str) {
      final match = RegExp(r'(\d+)\.(\d+)\.?(\d*)').firstMatch(str);
      return match != null ? match.group(0)! : '0.0.0';
    }

    final currMain = cleanMainSemver(current).split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final latestMain = cleanMainSemver(latest).split('.').map((p) => int.tryParse(p) ?? 0).toList();

    while (currMain.length < 3) {
      currMain.add(0);
    }
    while (latestMain.length < 3) {
      latestMain.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (latestMain[i] > currMain[i]) return true;
      if (latestMain[i] < currMain[i]) return false;
    }

    // Main semver is identical, compare RC candidate numbers
    final currRc = extractRc(current);
    final latestRc = extractRc(latest);
    return latestRc > currRc;
  }
}
