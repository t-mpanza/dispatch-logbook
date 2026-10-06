import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

/// Raw NFC tag reading — the tyre tag is the PRIMARY identifier in the bay:
/// every tyre carries an NFC chip. Emits normalized uppercase hex UIDs for
/// NXP ICODE SLIX (ISO 15693) and MIFARE Ultralight (ISO 14443) tags.
class NfcScanService {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  String? _lastUid;
  DateTime? _lastUidAt;
  static const Duration _debounceWindow = Duration(milliseconds: 1500);

  Stream<String> get scans => _controller.stream;

  Future<bool> get isAvailable async =>
      await NfcManager.instance.checkAvailability() == NfcAvailability.enabled;

  // NfcManager is a process-wide singleton: only one session can exist, so
  // track which service owns it.
  static NfcScanService? _owner;

  bool get isActive => identical(_owner, this);

  Future<void> start() async {
    if (isActive) return;
    try {
      // Take over from any other screen's session instead of colliding with it.
      await _owner?.stop();
      _owner = this;
      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        alertMessageIos: 'Hold the top of the phone near the tyre tag.',
        invalidateAfterFirstReadIos: false,
        onDiscovered: (tag) {
          final hex = _extractUid(tag);
          if (hex == null) return;
          final normalized = NfcTagUid.normalize(hex);
          if (normalized == null) return;
          final now = DateTime.now();
          if (normalized == _lastUid &&
              _lastUidAt != null &&
              now.difference(_lastUidAt!) < _debounceWindow) {
            return;
          }
          _lastUid = normalized;
          _lastUidAt = now;
          if (!_controller.isClosed) _controller.add(normalized);
        },
      );
    } catch (e) {
      if (identical(_owner, this)) _owner = null;
      debugPrint('Failed to start NFC session: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!isActive) return;
    _owner = null;
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      // The OS may already have ended the session (e.g. app backgrounded).
      debugPrint('Failed to stop NFC session: $e');
    }
  }

  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }
}

/// Pure normalization of raw NFC identifiers into uppercase hex strings.
class NfcTagUid {
  NfcTagUid._();

  /// Joins [bytes] into an uppercase hex string (two chars per byte).
  /// Returns null for empty sequences or non-byte values.
  static String? fromBytes(Iterable<int> bytes, {bool reverseBytes = false}) {
    final values = reverseBytes ? bytes.toList().reversed : bytes;
    final buffer = StringBuffer();
    for (final byte in values) {
      if (byte < 0 || byte > 0xFF) return null;
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    if (buffer.isEmpty) return null;
    return buffer.toString().toUpperCase();
  }

  /// Uppercases/trims raw scans; rejects non-hex (separators, junk).
  static String? normalize(String raw) {
    final candidate = raw.trim().toUpperCase();
    if (candidate.isEmpty) return null;
    for (final rune in candidate.runes) {
      final isHex =
          (rune >= 0x30 && rune <= 0x39) || (rune >= 0x41 && rune <= 0x46);
      if (!isHex) return null;
    }
    return candidate;
  }

  /// 14 hex chars = tyre tag. 8 = personnel badge. Anything else unsupported.
  static bool isTyreTag(String uid) => uid.length == 14;
  static bool isPersonnelBadge(String uid) => uid.length == 8;
}

/// Reads the raw identifier from a discovered tag per platform.
String? _extractUid(NfcTag tag) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      final miFare = MiFareIos.from(tag);
      if (miFare != null) return NfcTagUid.fromBytes(miFare.identifier);
      final iso15693 = Iso15693Ios.from(tag);
      if (iso15693 != null) {
        return NfcTagUid.fromBytes(iso15693.identifier, reverseBytes: true);
      }
      return null;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      final androidTag = NfcTagAndroid.from(tag);
      return androidTag == null ? null : NfcTagUid.fromBytes(androidTag.id);
  }
}
