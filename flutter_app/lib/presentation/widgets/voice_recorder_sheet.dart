import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/attachment.dart';
import '../../data/services/audio_service.dart';

class VoiceRecorderSheet extends StatefulWidget {
  final AudioService audioService;
  final Function(Attachment) onSave;

  const VoiceRecorderSheet({
    super.key,
    required this.audioService,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required AudioService audioService,
    required Function(Attachment) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceRecorderSheet(
        audioService: audioService,
        onSave: onSave,
      ),
    );
  }

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    await widget.audioService.startRecording();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  Future<void> _handleStopAndSave() async {
    _timer?.cancel();
    AppHaptics.success();
    final att = await widget.audioService.stopRecording();
    if (att != null && mounted) {
      widget.onSave(att);
      Navigator.pop(context);
    }
  }

  Future<void> _handleCancel() async {
    _timer?.cancel();
    AppHaptics.light();
    await widget.audioService.cancelRecording();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_seconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.presetNlh.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.presetNlh.withValues(alpha: 0.4), width: 2),
            ),
            child: const Center(
              child: Icon(Icons.mic_rounded, size: 36, color: AppColors.presetNlh),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$mins:$secs',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Recording voice note…',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _handleCancel,
                icon: const Icon(Icons.close_rounded, color: AppColors.error),
                label: const Text('Cancel', style: TextStyle(color: AppColors.error)),
              ),
              ElevatedButton.icon(
                onPressed: _handleStopAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                label: const Text(
                  'Save Voice Note',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
