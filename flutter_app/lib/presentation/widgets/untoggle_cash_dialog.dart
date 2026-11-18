import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';

/// The cash-mode untoggle decision (audit #5).
///
/// KEEP CASH is the SAFE action and sits on the RIGHT — where the thumb
/// naturally lands. UNTOGGLE is the disruptive one and stays on the left.
Future<bool?> showUntoggleCashDialog(
  BuildContext context, {
  required String documentNo,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(
        'CASH MODE',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Text('This tyre is on $documentNo — untoggle cash?'),
      actions: [
        TextButton(
          onPressed: () {
            AppHaptics.light();
            Navigator.pop(context, true);
          },
          child: Text(
            'UNTOGGLE',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.warningStrong(context),
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            AppHaptics.medium();
            Navigator.pop(context, false);
          },
          child: const Text(
            'KEEP CASH',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}
