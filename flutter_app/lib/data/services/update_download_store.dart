import 'dart:convert';
import 'dart:io';

/// One update download's persisted state — survives app kills, network
/// drops and dialog dismissals. This is what makes the updater RESUME
/// instead of re-downloading (enterprise behaviour).
class UpdateDownloadState {
  const UpdateDownloadState({
    required this.version,
    required this.received,
    required this.total,
    required this.url,
    this.sha256,
    this.phase = 'downloading',
  });

  final String version;
  final int received;
  final int total;
  final String url;
  final String? sha256;

  /// downloading → downloaded → verified
  final String phase;

  double get progress =>
      total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

  UpdateDownloadState copyWith({
    int? received,
    int? total,
    String? phase,
  }) {
    return UpdateDownloadState(
      version: version,
      received: received ?? this.received,
      total: total ?? this.total,
      url: url,
      sha256: sha256,
      phase: phase ?? this.phase,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'received': received,
    'total': total,
    'url': url,
    'sha256': sha256,
    'phase': phase,
  };

  static UpdateDownloadState? fromJson(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return UpdateDownloadState(
        version: m['version'] as String? ?? '',
        received: (m['received'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        url: m['url'] as String? ?? '',
        sha256: m['sha256'] as String?,
        phase: m['phase'] as String? ?? 'downloading',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Files live in the app-support directory (persistent — NOT the temp
/// dir that Android clears). Layout:
///
/// ```
/// updates/<version>.apk.part  — partial download
/// updates/<version>.apk       — complete download
/// updates/<version>.json      — state
/// ```
class UpdateDownloadStore {
  UpdateDownloadStore(this.baseDir);

  final Directory baseDir;

  Directory get updatesDir => Directory('${baseDir.path}/updates');

  File partFile(String version) => File('${updatesDir.path}/$version.apk.part');
  File apkFile(String version) => File('${updatesDir.path}/$version.apk');
  File stateFile(String version) => File('${updatesDir.path}/$version.json');

  Future<void> ensureDir() async {
    await updatesDir.create(recursive: true);
  }

  Future<UpdateDownloadState?> load(String version) async {
    final f = stateFile(version);
    if (!await f.exists()) return null;
    return UpdateDownloadState.fromJson(await f.readAsString());
  }

  Future<void> save(UpdateDownloadState state) async {
    await ensureDir();
    await stateFile(state.version).writeAsString(jsonEncode(state.toJson()));
  }

  Future<void> clear(String version) async {
    for (final f in [stateFile(version), partFile(version), apkFile(version)]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Drop every other version's files — keep the disk clean.
  Future<void> pruneExcept(String version) async {
    try {
      final entries = await updatesDir.list().toList();
      for (final e in entries) {
        try {
          final name = e.uri.pathSegments.last;
          if (!name.startsWith(version)) {
            await e.delete(recursive: false);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}
