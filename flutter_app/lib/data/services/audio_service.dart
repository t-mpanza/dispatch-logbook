import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/utils/id_generator.dart';
import '../models/attachment.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  String? _currentlyPlayingId;
  String? get currentlyPlayingId => _currentlyPlayingId;

  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final docDir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory('${docDir.path}/attachments');
    if (!attachmentsDir.existsSync()) {
      await attachmentsDir.create(recursive: true);
    }
    final fileName = 'voice_${IdGenerator.generate()}.m4a';
    _currentRecordingPath = '${attachmentsDir.path}/$fileName';
    _recordingStartTime = DateTime.now();

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _currentRecordingPath!,
    );
    _isRecording = true;
  }

  Future<Attachment?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
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
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    await _recorder.cancel();
    _isRecording = false;
    _currentRecordingPath = null;
  }

  Future<void> playAttachment(Attachment attachment) async {
    _currentlyPlayingId = attachment.id;
    if (attachment.bytes != null && attachment.bytes!.isNotEmpty) {
      await _player.play(BytesSource(attachment.bytes!));
      return;
    }

    if (attachment.localFilePath != null && File(attachment.localFilePath!).existsSync()) {
      await _player.play(DeviceFileSource(attachment.localFilePath!));
      return;
    }

    // Check app documents directory
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final localFile = File('${docDir.path}/attachments/${attachment.name}');
      if (localFile.existsSync()) {
        await _player.play(DeviceFileSource(localFile.path));
        return;
      }
    } catch (_) {}

    if (attachment.downloadUrl != null && attachment.downloadUrl!.isNotEmpty) {
      await _player.play(UrlSource(attachment.downloadUrl!));
    }
  }

  Future<void> pauseAudio() async {
    await _player.pause();
  }

  Future<void> resumeAudio() async {
    await _player.resume();
  }

  Future<void> seekAudio(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setPlaybackRate(double rate) async {
    await _player.setPlaybackRate(rate);
  }

  Future<void> stopAudio() async {
    _currentlyPlayingId = null;
    await _player.stop();
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
