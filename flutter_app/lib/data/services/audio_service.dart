import 'dart:io';
import 'dart:typed_data';
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

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getTemporaryDirectory();
    final fileName = 'voice_${IdGenerator.generate()}.m4a';
    _currentRecordingPath = '${dir.path}/$fileName';
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

  Future<void> playAudio(String source) async {
    if (source.startsWith('http')) {
      await _player.play(UrlSource(source));
    } else {
      await _player.play(DeviceFileSource(source));
    }
  }

  Future<void> playBytes(Uint8List bytes) async {
    await _player.play(BytesSource(bytes));
  }

  Future<void> stopAudio() async {
    await _player.stop();
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
