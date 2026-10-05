import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../screens/new_entry_screen.dart';
import 'ui_kit.dart';

/// The capture menu — the jobs a despatch worker does all day, with the
/// STOCKS run front and centre.
///
/// [hostContext] is the context of the screen that opened the sheet; all
/// navigation after the sheet is dismissed goes through it.
class CaptureActionSheet extends StatelessWidget {
  final BuildContext hostContext;

  const CaptureActionSheet({super.key, required this.hostContext});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CaptureActionSheet(hostContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you doing?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.dynamicTextPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One entry flow for everything — truck loads, stocks runs, '
            'counts and notes.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.dynamicTextMuted(context),
            ),
          ),
          const SizedBox(height: 16),

          // ONE entry point: all kinds live inside NewEntryScreen
          _PrimaryAction(
            icon: Icons.add_rounded,
            color: AppColors.presetStocks,
            title: 'New Entry',
            subtitle: 'Truck load · stocks run · count · note',
            onTap: () {
              AppHaptics.medium();
              Navigator.pop(context);
              Navigator.push(
                hostContext,
                MaterialPageRoute(builder: (_) => const NewEntryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.medium();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30, color: AppColors.onAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STOCKS RUN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.presetStocks,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.dynamicTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.dynamicTextMuted(context),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
