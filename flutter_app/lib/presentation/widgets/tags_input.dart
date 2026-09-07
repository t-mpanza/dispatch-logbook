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
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in widget.value)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: AppColors.dynamicAccent(
                      context,
                    ).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dynamicAccent(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeTag(tag),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: 120,
              height: 34,
              child: TextField(
                controller: _controller,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.dynamicTextPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: '+ Add tag',
                  hintStyle: TextStyle(
                    color: AppColors.dynamicTextMuted(context),
                    fontSize: 13,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: _addTag,
              ),
            ),
          ],
        ),
        if (unusedSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in unusedSuggestions)
                GestureDetector(
                  onTap: () => _addTag(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dynamicCardSurface(context),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: AppColors.dynamicBorderLight(context),
                      ),
                    ),
                    child: Text(
                      '+$s',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dynamicTextMuted(context),
                      ),
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
