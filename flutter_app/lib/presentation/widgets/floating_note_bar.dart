import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/attachment.dart';
import '../../data/services/camera_service.dart';

/// Bottom action bar for notes, photos and voice. Big round buttons for
/// gloved hands, note field front and centre.
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
    if (att != null) widget.onAttachment(att);
  }

  Future<void> _handleGallery() async {
    AppHaptics.light();
    final att = await CameraService.pickImageFromGallery();
    if (att != null) widget.onAttachment(att);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: GlassDecorations.glassDock(
        context: context,
        borderRadius: 26,
      ),
      child: Row(
        children: [
          _roundButton(
            context,
            icon: Icons.camera_alt_rounded,
            color: AppColors.dynamicAccent(context),
            onTap: _handleCamera,
            tooltip: 'Take photo',
          ),
          const SizedBox(width: 6),
          _roundButton(
            context,
            icon: Icons.photo_library_rounded,
            color: AppColors.dynamicTextSecondary(context),
            onTap: _handleGallery,
            tooltip: 'From gallery',
          ),
          const SizedBox(width: 6),
          _roundButton(
            context,
            icon: Icons.mic_rounded,
            color: AppColors.presetNlh,
            onTap: () {
              AppHaptics.medium();
              widget.onStartVoice();
            },
            tooltip: 'Voice note',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _controller,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.dynamicTextPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Add a note…',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  filled: true,
                  fillColor: AppColors.dynamicSurfaceSunk(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: AppColors.dynamicBorderLight(context),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: AppColors.dynamicBorderLight(context),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                onChanged: (val) =>
                    setState(() => _hasText = val.trim().isNotEmpty),
                onSubmitted: (_) => _handleSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _hasText ? _handleSubmit : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _hasText
                    ? AppColors.primary
                    : AppColors.dynamicCardSurface(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 22,
                color: _hasText
                    ? Colors.white
                    : AppColors.dynamicTextMuted(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return IconButton(
      onPressed: () {
        AppHaptics.light();
        onTap();
      },
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}
