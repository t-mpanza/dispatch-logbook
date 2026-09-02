import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';

/// Precise in-app numeric keypad.
///
/// Returns the confirmed value, or null when cancelled.
/// When [maxValue] is set the keypad hard-clamps entry to the limit and fires
/// a heavy haptic so the operator physically feels the overshoot cap.
class NumberPad {
  static Future<int?> show(
    BuildContext context, {
    required int initial,
    int? maxValue,
    String? title,
    String? unit,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NumberPadSheet(
        initial: initial,
        maxValue: maxValue,
        title: title,
        unit: unit,
      ),
    );
  }
}

class _NumberPadSheet extends StatefulWidget {
  final int initial;
  final int? maxValue;
  final String? title;
  final String? unit;

  const _NumberPadSheet({
    required this.initial,
    this.maxValue,
    this.title,
    this.unit,
  });

  @override
  State<_NumberPadSheet> createState() => _NumberPadSheetState();
}

class _NumberPadSheetState extends State<_NumberPadSheet> {
  String _buffer = '';
  bool _clamped = false;

  @override
  void initState() {
    super.initState();
    _buffer = widget.initial > 0 ? '${widget.initial}' : '';
  }

  int get _value => int.tryParse(_buffer) ?? 0;

  bool get _hasMax => widget.maxValue != null && widget.maxValue! > 0;

  void _press(String digit) {
    AppHaptics.light();
    final candidate = _buffer + digit;
    final v = int.tryParse(candidate) ?? 0;

    if (_hasMax && v > widget.maxValue!) {
      // Strict overshoot clamp — snap straight to the manifest target.
      AppHaptics.error();
      setState(() {
        _buffer = '${widget.maxValue}';
        _clamped = true;
      });
      return;
    }

    setState(() {
      _buffer = candidate.length > 6 ? _buffer : candidate;
      _clamped = false;
    });
  }

  void _backspace() {
    AppHaptics.light();
    setState(() {
      if (_buffer.isNotEmpty) {
        _buffer = _buffer.substring(0, _buffer.length - 1);
      }
      _clamped = false;
    });
  }

  void _clear() {
    AppHaptics.medium();
    setState(() {
      _buffer = '';
      _clamped = false;
    });
  }

  void _confirm() {
    AppHaptics.success();
    Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);
    final accent = isLight ? AppColors.primary : AppColors.primaryGlow;
    final displayText = _buffer.isEmpty ? '0' : _buffer;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : AppColors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight
                      ? const Color(0xFFCBD5E1)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title ?? 'ENTER QUANTITY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
                if (_hasMax)
                  Text(
                    _clamped ? 'CAPPED AT ${widget.maxValue}' : 'MAX: ${widget.maxValue}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: _clamped ? AppColors.warning : AppColors.dynamicTextMuted(context),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFF1F5F9) : Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _clamped
                      ? AppColors.warning
                      : (isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder),
                  width: _clamped ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      displayText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: _clamped ? AppColors.warning : accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.unit ?? 'tyres',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dynamicTextMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Keypad Grid
            _buildKeyRow(['1', '2', '3']),
            _buildKeyRow(['4', '5', '6']),
            _buildKeyRow(['7', '8', '9']),
            Row(
              children: [
                Expanded(child: _buildKey('C', onTap: _clear, isSpecial: true)),
                Expanded(child: _buildKey('0')),
                Expanded(
                  child: _buildKey('⌫', onTap: _backspace, isSpecial: true),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Confirm
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'CONFIRM — $displayText',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> labels) {
    return Row(
      children: [
        for (final label in labels)
          Expanded(child: _buildKey(label)),
      ],
    );
  }

  Widget _buildKey(String label, {VoidCallback? onTap, bool isSpecial = false}) {
    final isLight = AppColors.isLight(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: onTap ?? () => _press(label),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isSpecial
                ? (isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.06))
                : GlassDecorations.glassCard(context: context, borderRadius: 14).color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorderLight,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSpecial ? 16 : 20,
                fontWeight: FontWeight.w900,
                color: AppColors.dynamicTextPrimary(context),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
