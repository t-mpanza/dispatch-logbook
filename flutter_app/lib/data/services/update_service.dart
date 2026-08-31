import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
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

  UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.releaseTitle,
    this.releaseNotes,
    this.apkDownloadUrl,
    this.releaseUrl,
    this.publishedAt,
  });
}

class UpdateService {
  static const String repoOwner = 't-mpanza';
  static const String repoName = 'dispatch-logbook';
  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const String releasesPageUrl =
      'https://github.com/$repoOwner/$repoName/releases';

  /// Get current app version (e.g., '1.0.0' or 'v1.0.0')
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version}';
    } catch (_) {
      return 'v2.0.0';
    }
  }

  /// Check GitHub releases for a newer version
  static Future<UpdateInfo> checkForUpdates() async {
    final currentVer = await getCurrentVersion();

    try {
      final response = await http.get(
        Uri.parse(latestReleaseApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'DispatchDiary-App',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('GitHub API returned ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestTag = data['tag_name'] as String? ?? '';
      final title = data['name'] as String? ?? latestTag;
      final body = data['body'] as String? ?? '';
      final releaseHtmlUrl = data['html_url'] as String? ?? releasesPageUrl;
      final publishedAt = data['published_at'] as String?;

      // Find APK asset in release assets
      String? apkUrl;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      final hasUpdate = _isNewerVersion(currentVer, latestTag);

      return UpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVer,
        latestVersion: latestTag.isNotEmpty ? latestTag : currentVer,
        releaseTitle: title,
        releaseNotes: body,
        apkDownloadUrl: apkUrl ?? releaseHtmlUrl,
        releaseUrl: releaseHtmlUrl,
        publishedAt: publishedAt,
      );
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return UpdateInfo(
        hasUpdate: false,
        currentVersion: currentVer,
        latestVersion: currentVer,
        releaseNotes: 'Could not fetch updates ($e)',
        releaseUrl: releasesPageUrl,
      );
    }
  }

  /// Direct in-app stream download and system package installer launch
  static Future<bool> downloadAndInstallApk(
    String apkUrl, {
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      request.headers['User-Agent'] = 'DispatchDiary-App';

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Download failed with HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/dispatch-diary-update.apk');

      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(progress, receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      // Launch the Android package installer directly
      final result = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );

      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Error downloading and installing APK: $e');
      return false;
    }
  }

  /// Launch APK download or release page in browser/installer fallback
  static Future<bool> openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Helper to compare semver versions (e.g. 'v2.0.44' vs 'v2.0.0')
  static bool _isNewerVersion(String current, String latest) {
    if (latest.isEmpty) return false;
    final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '');
    final cleanLatest = latest.replaceAll(RegExp(r'[^0-9.]'), '');

    if (cleanCurrent == cleanLatest) return false;

    final currParts =
        cleanCurrent.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final latestParts =
        cleanLatest.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLen = currParts.length > latestParts.length
        ? currParts.length
        : latestParts.length;

    while (currParts.length < maxLen) {
      currParts.add(0);
    }
    while (latestParts.length < maxLen) {
      latestParts.add(0);
    }

    for (var i = 0; i < maxLen; i++) {
      if (latestParts[i] > currParts[i]) return true;
      if (latestParts[i] < currParts[i]) return false;
    }

    return false;
  }
}
