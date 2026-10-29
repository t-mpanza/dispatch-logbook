import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The two scanner sounds — binary by design: one for correct (eyes stay
/// on the bay), one for everything wrong. Never throws, never blocks; the
/// player is created inside the guard so a missing plugin can't leak an
/// uncaught init error.
class ScanSounds {
  ScanSounds._();

  /// Test seam: widget/unit tests disable audio (the plugin is absent and
  /// its event stream would throw uncaught). Production always enabled.
  static bool enabled = true;

  static AudioPlayer? _player;

  static Future<void> success() => _play('sounds/scan_success.wav');

  static Future<void> error() => _play('sounds/scan_error.wav');

  static Future<void> _play(String asset) async {
    if (!enabled) return;
    try {
      _player ??= AudioPlayer();
      final player = _player!;
      await player.stop();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Scan sound failed: $e');
    }
  }
}
