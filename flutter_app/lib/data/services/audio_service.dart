import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/utils/id_generator.dart';
import '../models/attachment.dart';

/// Voice recording & playback. The audio player is created LAZILY and every
/// operation is guarded: a plugin-init failure (or running in a test env)
/// must degrade to no-op, never crash the screen that embeds this service.
class AudioService {
  AudioRecorder? _recorder;
  AudioPlayer? _player;

  AudioRecorder? _safeRecorder() {
    if (_recorder != null) return _recorder;
    try {
      _recorder = AudioRecorder();
      return _recorder;
    } catch (e) {
      debugPrint('AudioRecorder init failed: $e');
      return null;
    }
  }

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  String? _currentlyPlayingId;
  String? get currentlyPlayingId => _currentlyPlayingId;

  /// Creates the player on demand; null when the plugin is unavailable.
  AudioPlayer? _safePlayer() {
    if (_player != null) return _player;
    try {
      _player = AudioPlayer();
      return _player;
    } catch (e) {
      debugPrint('AudioPlayer init failed: $e');
      return null;
    }
  }

  /// Public lazy accessor — callers that need stream subscriptions call
  /// this and tolerate null (no plugin = no playback UI).
  AudioPlayer? ensurePlayer() => _safePlayer();

  Future<void> startRecording() async {
    final recorder = _safeRecorder();
    if (recorder == null) return;
    try {
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) return;

      final docDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${docDir.path}/attachments');
      if (!attachmentsDir.existsSync()) {
        await attachmentsDir.create(recursive: true);
      }
      final fileName = 'voice_${IdGenerator.generate()}.m4a';
      _currentRecordingPath = '${attachmentsDir.path}/$fileName';
      _recordingStartTime = DateTime.now();

      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _currentRecordingPath!,
      );
      _isRecording = true;
    } catch (e) {
      debugPrint('startRecording failed: $e');
    }
  }

  Future<Attachment?> stopRecording() async {
    if (!_isRecording) return null;

    final recorder = _safeRecorder();
    if (recorder == null) {
      _isRecording = false;
      return null;
    }
    try {
      final path = await recorder.stop();
      _isRecording = false;

      if (path == null) return null;
      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      return Attachment(
        id: IdGenerator.generate(),
        kind: AttachmentKind.audio,
        bytes: bytes,
        mime: 'audio/mp4',
        name: file.uri.pathSegments.last,
        durationMs: durationMs,
        localFilePath: path,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('stopRecording failed: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _safeRecorder()?.cancel();
    } catch (e) {
      debugPrint('cancelRecording failed: $e');
    }
    _isRecording = false;
    _currentRecordingPath = null;
  }

  Future<void> playAttachment(Attachment attachment) async {
    final player = _safePlayer();
    if (player == null) return;
    _currentlyPlayingId = attachment.id;
    try {
      if (attachment.bytes != null && attachment.bytes!.isNotEmpty) {
        await player.play(BytesSource(attachment.bytes!));
        return;
      }

      if (attachment.localFilePath != null &&
          File(attachment.localFilePath!).existsSync()) {
        await player.play(DeviceFileSource(attachment.localFilePath!));
        return;
      }

      // Check app documents directory
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final localFile = File('${docDir.path}/attachments/${attachment.name}');
        if (localFile.existsSync()) {
          await player.play(DeviceFileSource(localFile.path));
          return;
        }
      } catch (_) {}

      if (attachment.downloadUrl != null && attachment.downloadUrl!.isNotEmpty) {
        await player.play(UrlSource(attachment.downloadUrl!));
      }
    } catch (e) {
      debugPrint('playAttachment failed: $e');
    }
  }

  Future<void> pauseAudio() async {
    final player = _safePlayer();
    if (player == null) return;
    try {
      await player.pause();
    } catch (e) {
      debugPrint('pauseAudio failed: $e');
    }
  }

  Future<void> resumeAudio() async {
    final player = _safePlayer();
    if (player == null) return;
    try {
      await player.resume();
    } catch (e) {
      debugPrint('resumeAudio failed: $e');
    }
  }

  Future<void> seekAudio(Duration position) async {
    final player = _safePlayer();
    if (player == null) return;
    try {
      await player.seek(position);
    } catch (e) {
      debugPrint('seekAudio failed: $e');
    }
  }

  Future<void> setPlaybackRate(double rate) async {
    final player = _safePlayer();
    if (player == null) return;
    try {
      await player.setPlaybackRate(rate);
    } catch (e) {
      debugPrint('setPlaybackRate failed: $e');
    }
  }

  Future<void> stopAudio() async {
    _currentlyPlayingId = null;
    final player = _safePlayer();
    if (player == null) return;
    try {
      await player.stop();
    } catch (e) {
      debugPrint('stopAudio failed: $e');
    }
  }

  void dispose() {
    _recorder?.dispose();
    _player?.dispose();
  }
}
