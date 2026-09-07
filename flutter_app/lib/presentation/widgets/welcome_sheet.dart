import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/repositories/settings_repository.dart';
import 'ui_kit.dart';

/// First-run welcome: three plain-language slides explaining what the app
/// does, shown once until dismissed.
class WelcomeSheet extends StatefulWidget {
  const WelcomeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAppSheet(context, child: const WelcomeSheet());
  }

  @override
  State<WelcomeSheet> createState() => _WelcomeSheetState();
}

class _WelcomeSheetState extends State<WelcomeSheet> {
  int _page = 0;

  static const _pages = [
    (
      icon: Icons.speed_rounded,
      color: AppColors.primaryGlow,
      title: 'Everything for your day, on one screen',
      body:
          'Home shows what is happening today. Log truck loads, start count '
          'sessions and capture trips from the big + button.',
    ),
    (
      icon: Icons.article_rounded,
      color: AppColors.presetNlh,
      title: 'Your loading sheet, always ready',
      body:
          'Every truck you log lands on the daily Loading Sheet. End the day '
          'by sending it to WhatsApp or printing the PDF.',
    ),
    (
      icon: Icons.cloud_done_rounded,
      color: AppColors.success,
      title: 'Works offline, syncs when you can',
      body:
          'No signal? No problem. Everything saves on this device and syncs '
          'to the cloud automatically when you are back online.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _finish,
            child: Text(
              'Skip',
              style: TextStyle(color: AppColors.dynamicTextMuted(context)),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(
            key: ValueKey(_page),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: page.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: page.color.withValues(alpha: 0.4)),
                ),
                child: Icon(page.icon, size: 40, color: page.color),
              ),
              const SizedBox(height: 20),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dynamicTextPrimary(context),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                page.body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.dynamicTextSecondary(context),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _page ? 22 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppColors.primary
                      : AppColors.dynamicTextDisabled(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _page < _pages.length - 1 ? _next : _finish,
            child: Text(_page < _pages.length - 1 ? 'Next' : 'Start working'),
          ),
        ),
      ],
    );
  }

  void _next() {
    AppHaptics.light();
    setState(() => _page++);
  }

  void _finish() {
    AppHaptics.success();
    context.read<SettingsRepository>().markWelcomeSeen();
    Navigator.pop(context);
  }
}
