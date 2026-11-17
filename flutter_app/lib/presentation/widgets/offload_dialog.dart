import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';

/// D5 — the offload window: the verdict already failed LOUD (sound +
/// haptic); this dialog is the yes/no. OFFLOAD commits loaded:0 — the
/// backend's only "removal" — CONTINUE keeps the scanner rolling.
Future<bool?> showOffloadDialog(
  BuildContext context, {
  required String label,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(
        'OFFLOAD?',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
      content: Text(
        'This tyre is already on this truck.\n\n$label\n\n'
        'Offload it (remove from the truck) or keep scanning?',
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () {
            AppHaptics.light();
            Navigator.pop(context, false);
          },
          child: Text(
            'CONTINUE SCANNING',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.dynamicTextMuted(context),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            AppHaptics.medium();
            Navigator.pop(context, true);
          },
          child: Text(
            'OFFLOAD',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.warningStrong(context),
            ),
          ),
        ),
      ],
    ),
  );
}
