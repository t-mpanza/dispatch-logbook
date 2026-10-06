import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';

/// Smart time entry — type digits only ("1110" becomes 11:10, the colon
/// inserts itself), or tap NOW / +15m / +30m / +1h. No more typing "11"
/// then ":" then "10".
class TimeEntryField extends StatelessWidget {
  final String label;
  final int? value; // epoch ms; null = empty
  final ValueChanged<int?> onChanged;

  const TimeEntryField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppFormatters.formatTimeHHmm(value);
    return GestureDetector(
      onTap: () async {
        AppHaptics.light();
        final picked = await TimeEntrySheet.show(context, initial: value);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: 'HH:mm',
          suffixIcon: const Icon(Icons.schedule_rounded, size: 18),
        ),
        child: Text(
          text.isEmpty ? '—' : text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            letterSpacing: 1.2,
            color: text.isEmpty
                ? AppColors.dynamicTextDisabled(context)
                : AppColors.dynamicTextPrimary(context),
          ),
        ),
      ),
    );
  }
}

class TimeEntrySheet {
  /// Returns an epoch-ms timestamp for today at the chosen time, or null.
  static Future<int?> show(BuildContext context, {int? initial}) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TimeEntrySheet(initial: initial),
    );
  }
}

class _TimeEntrySheet extends StatefulWidget {
  final int? initial;

  const _TimeEntrySheet({this.initial});

  @override
  State<_TimeEntrySheet> createState() => _TimeEntrySheetState();
}

class _TimeEntrySheetState extends State<_TimeEntrySheet> {
  String _buffer = '';

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null && t > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t);
      _buffer =
          '${dt.hour.toString().padLeft(2, '0')}'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  /// "1110" → "11:10". Digits-only input; colon auto-inserted.
  String get _formatted {
    if (_buffer.length <= 2) return _buffer.padRight(2, '0').padLeft(2, '0');
    return '${_buffer.substring(0, 2)}:${_buffer.substring(2).padRight(2, '0')}';
  }

  int? get _value {
    if (_buffer.isEmpty) return null;
    final hh = int.tryParse(_buffer.substring(0, 2));
    final mm = int.tryParse(
      _buffer.substring(2).padRight(2, '0').substring(0, 2),
    );
    if (hh == null || mm == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hh, mm)
        .millisecondsSinceEpoch;
  }

  void _press(String digit) {
    AppHaptics.light();
    final candidate = _buffer + digit;
    final hh = int.tryParse(candidate.substring(0, 2)) ?? 0;
    final mm = int.tryParse(candidate.substring(2)) ?? 0;
    if (hh > 23 || mm > 59) {
      AppHaptics.error();
      return;
    }
    if (candidate.length > 4) return;
    setState(() => _buffer = candidate);
  }

  void _backspace() {
    AppHaptics.light();
    if (_buffer.isNotEmpty) {
      setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
    }
  }

  void _quick(int offsetMinutes) {
    AppHaptics.medium();
    final dt = DateTime.now().add(Duration(minutes: offsetMinutes));
    Navigator.pop(
      context,
      DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute)
          .millisecondsSinceEpoch,
    );
  }

  void _confirm() {
    final value = _value;
    if (value == null) {
      AppHaptics.error();
      return;
    }
    AppHaptics.success();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);
    final accent = isLight ? AppColors.primary : AppColors.primaryGlow;

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
              children: [
                const Text(
                  'SET TIME',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  _buffer.isEmpty ? 'tap digits — colon inserts itself' : 'READY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: _buffer.isEmpty
                        ? AppColors.dynamicTextMuted(context)
                        : AppColors.success,
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
                color: isLight
                    ? const Color(0xFFF1F5F9)
                    : Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLight
                      ? const Color(0xFFCBD5E1)
                      : AppColors.glassBorder,
                ),
              ),
              child: Text(
                _formatted,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                  color: _buffer.isEmpty
                      ? AppColors.dynamicTextDisabled(context)
                      : accent,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quick chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final (label, mins) in const [
                  ('NOW', 0),
                  ('+15m', 15),
                  ('+30m', 30),
                  ('+1h', 60),
                ])
                  GestureDetector(
                    onTap: () => _quick(mins),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppColors.infoStrong(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Digit grid (4 columns)
            for (final row in const [
              ['1', '2', '3', '4'],
              ['5', '6', '7', '8'],
              ['9', '0', '⌫', 'OK'],
            ])
              Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: _key(context, key, accent),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _key(BuildContext context, String label, Color accent) {
    final isLight = AppColors.isLight(context);
    final isSpecial = label == '⌫' || label == 'OK';
    return GestureDetector(
      onTap: () {
        if (label == '⌫') {
          _backspace();
        } else if (label == 'OK') {
          _confirm();
        } else {
          _press(label);
        }
      },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: label == 'OK'
              ? accent
              : (isSpecial
                    ? (isLight
                          ? const Color(0xFFE2E8F0)
                          : Colors.white.withValues(alpha: 0.06))
                    : GlassDecorations.glassCard(
                        context: context,
                        borderRadius: 14,
                      ).color),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLight
                ? const Color(0xFFCBD5E1)
                : AppColors.glassBorderLight,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: label == 'OK' ? 13 : 18,
              fontWeight: FontWeight.w900,
              letterSpacing: label == 'OK' ? 1.2 : 0,
              color: label == 'OK'
                  ? Colors.white
                  : AppColors.dynamicTextPrimary(context),
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
