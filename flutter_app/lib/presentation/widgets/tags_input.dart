import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';

class TagsInput extends StatefulWidget {
  final List<String> value;
  final Function(List<String>) onChange;
  final List<String> suggestions;

  const TagsInput({
    super.key,
    required this.value,
    required this.onChange,
    this.suggestions = const [],
  });

  @override
  State<TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<TagsInput> {
  final TextEditingController _controller = TextEditingController();

  void _addTag(String raw) {
    final clean = raw.trim().replaceAll('#', '').toLowerCase();
    if (clean.isEmpty) return;
    if (!widget.value.contains(clean)) {
      AppHaptics.light();
      widget.onChange([...widget.value, clean]);
    }
    _controller.clear();
  }

  void _removeTag(String tag) {
    AppHaptics.light();
    widget.onChange(widget.value.where((t) => t != tag).toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unusedSuggestions = widget.suggestions
        .where((s) => !widget.value.contains(s.toLowerCase()))
        .take(6)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in widget.value)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGlow,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeTag(tag),
                      child: const Icon(Icons.close_rounded, size: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

            // Input tag
            SizedBox(
              width: 100,
              height: 28,
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: '+ Add tag',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: InputBorder.none,
                ),
                onSubmitted: _addTag,
              ),
            ),
          ],
        ),

        if (unusedSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final s in unusedSuggestions)
                GestureDetector(
                  onTap: () => _addTag(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.glassBorderLight),
                    ),
                    child: Text(
                      '+$s',
                      style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
