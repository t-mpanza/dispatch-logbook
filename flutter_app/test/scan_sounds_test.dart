import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/core/utils/scan_sounds.dart';

void main() {
  group('ScanSounds mute + test seams', () {
    test('disabled or muted never touches the audio plugin', () async {
      // With the test seam off, play must return without constructing the
      // player (no plugin, no exception).
      ScanSounds.enabled = false;
      ScanSounds.muted = false;
      await ScanSounds.success();
      await ScanSounds.error();

      // Muted with seam on must also no-op (plugin absent in tests).
      ScanSounds.enabled = true;
      ScanSounds.muted = true;
      await ScanSounds.success();
      await ScanSounds.error();

      // Restore for other tests.
      ScanSounds.enabled = false;
      ScanSounds.muted = false;
    });
  });
}
