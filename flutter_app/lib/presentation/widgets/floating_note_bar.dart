import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/attachment.dart';
import '../../data/services/camera_service.dart';

class FloatingNoteBar extends StatefulWidget {
  final Function(String) onAddNote;
  final Function(Attachment) onAttachment;
  final VoidCallback onStartVoice;

  const FloatingNoteBar({
    super.key,
    required this.onAddNote,
    required this.onAttachment,
    required this.onStartVoice,
  });

  @override
  State<FloatingNoteBar> createState() => _FloatingNoteBarState();
}

class _FloatingNoteBarState extends State<FloatingNoteBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    AppHaptics.success();
    widget.onAddNote(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  Future<void> _handleCamera() async {
    AppHaptics.light();
    final att = await CameraService.capturePhoto();
    if (att != null) {
      widget.onAttachment(att);
    }
  }

  Future<void> _handleGallery() async {
    AppHaptics.light();
    final att = await CameraService.pickImageFromGallery();
    if (att != null) {
      widget.onAttachment(att);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: GlassDecorations.glassDock(borderRadius: 24),
      child: Row(
        children: [
          // Camera Button
          IconButton(
            icon: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryGlow, size: 20),
            onPressed: _handleCamera,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          // Gallery Button
          IconButton(
            icon: const Icon(Icons.photo_library_rounded, color: AppColors.textSecondary, size: 20),
            onPressed: _handleGallery,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          // Mic Button
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: AppColors.presetNlh, size: 20),
            onPressed: () {
              AppHaptics.medium();
              widget.onStartVoice();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          const SizedBox(width: 4),

          // Text Field
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Add note…',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.glassBorderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryGlow),
                ),
              ),
              onChanged: (val) {
                setState(() => _hasText = val.trim().isNotEmpty);
              },
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),

          const SizedBox(width: 6),

          // Send / Add Button
          GestureDetector(
            onTap: _hasText ? _handleSubmit : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hasText ? AppColors.primary : AppColors.glassSurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: _hasText ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
