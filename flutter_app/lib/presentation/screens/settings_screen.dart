import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/reminder.dart';
import '../../data/models/sync_state.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/database_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/report_service.dart';
import '../../data/services/update_service.dart';
import '../widgets/aws_auth_dialog.dart';
import '../widgets/ui_kit.dart';
import '../widgets/update_dialog.dart';
import '../widgets/welcome_sheet.dart';

/// One place for account, cloud and app care. Kept out of the working flow
/// so the main screens stay focused on the job.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '…';
  bool _checking = false;
  bool _sendingReport = false;

  static const String _dispatchPasscode = '72010604';
  int _versionTaps = 0;
  DateTime? _lastVersionTapAt;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final v = await UpdateService.getCurrentVersion();
    if (mounted) setState(() => _version = v);
  }

  /// Hidden Dispatch-tab ritual: tap the version label 7x, then enter the
  /// passcode. Unlock lasts only for this launch.
  void _onVersionTap() {
    final now = DateTime.now();
    if (_lastVersionTapAt != null &&
        now.difference(_lastVersionTapAt!) > const Duration(seconds: 3)) {
      _versionTaps = 0;
    }
    _lastVersionTapAt = now;
    _versionTaps++;

    if (_versionTaps >= 7) {
      _versionTaps = 0;
      _promptDispatchPasscode();
    } else {
      AppHaptics.light();
    }
  }

  Future<void> _promptDispatchPasscode() async {
    AppHaptics.medium();
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispatch access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the dispatch passcode to reveal the Dispatch tab '
              'for this launch.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 8,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                hintText: '••••••••',
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx, val.trim() == _dispatchPasscode);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.dynamicTextMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, controller.text.trim() == _dispatchPasscode);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final settings = context.read<SettingsRepository>();
      settings.unlockDispatch();
      AppHaptics.success();
      AppSnacks.success(context, 'Dispatch tab unlocked for this launch');
    } else if (mounted) {
      AppHaptics.error();
      AppSnacks.error(context, 'Wrong passcode');
    }
  }

  Future<void> _sendReportNow() async {
    if (_sendingReport) return;
    setState(() => _sendingReport = true);
    AppHaptics.medium();

    final result = await ReportService.sendNow();
    if (!mounted) return;
    setState(() => _sendingReport = false);

    switch (result) {
      case 'ok':
        AppHaptics.success();
        AppSnacks.success(
          context,
          'Report triggered — email on its way to '
          '${ReportService.defaultRecipient}',
        );
      case 'missing_token':
        AppHaptics.error();
        final configured = await _configureReportToken();
        if (configured && mounted) {
          await _sendReportNow();
        }
      default:
        AppHaptics.error();
        AppSnacks.error(context, 'Could not trigger report. Check your '
            'network and GitHub token, then try again.');
    }
  }

  Future<bool> _configureReportToken() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GitHub Actions token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a GitHub personal access token so this app can trigger '
              'the daily report on demand. The token only needs the '
              '"Actions" permission (Read and write) on the '
              't-mpanza/dispatch-logbook repository.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'GitHub token',
                hintText: 'ghp_… or github_pat_…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.dynamicTextMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () {
              ReportService.saveToken(controller.text);
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _checkForUpdates() async {
    if (_checking) return;
    setState(() => _checking = true);
    AppHaptics.light();
    final info = await UpdateService.checkForUpdates();
    if (!mounted) return;
    setState(() => _checking = false);
    UpdateDialog.show(context, info);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final isSun = settings.isSunlightMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            AppHaptics.light();
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _sectionLabel(context, 'DISPLAY'),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isSun ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    color: isSun
                        ? AppColors.warning
                        : AppColors.dynamicAccent(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sunlight mode',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bright screen theme for working in direct sun',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isSun,
                  onChanged: (_) {
                    AppHaptics.medium();
                    settings.toggleSunlightMode();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.nfc_rounded,
                    color: settings.nfcEnabled
                        ? AppColors.infoStrong(context)
                        : AppColors.dynamicTextDisabled(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NFC tyre scanning',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kill switch — tyre-tag reading in Dispatch',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.nfcEnabled,
                  onChanged: (val) {
                    AppHaptics.medium();
                    settings.setNfcEnabled(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionLabel(context, 'YOUR DETAILS'),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: AppColors.dynamicAccent(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Despatcher name',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settings.despatcherName,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.dynamicTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _editName(context, settings),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionLabel(context, 'CLOUD'),
          _SyncCard(repo: context.watch<EntryRepository>()),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => AwsAuthDialog.show(context),
            child: Row(
              children: [
                const Icon(
                  Icons.vpn_key_rounded,
                  color: AppColors.presetNlh,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AWS AppSync / Cognito login',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sign in to fetch IBT manifests from the cloud',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionLabel(context, 'REPORTS'),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily email report',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Weekday mornings 06:00 · '
                        '${ReportService.defaultRecipient}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _sendingReport ? null : _sendReportNow,
                  child: _sendingReport
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send now'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () async {
              AppHaptics.light();
              await _configureReportToken();
              if (context.mounted) {
                final has = await ReportService.hasToken();
                if (context.mounted) {
                  AppSnacks.success(
                    context,
                    has
                        ? 'Report trigger token saved'
                        : 'Report trigger token cleared',
                  );
                }
              }
            },
            child: Row(
              children: [
                Icon(
                  Icons.key_rounded,
                  color: AppColors.dynamicAccent(context),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Configure report trigger token',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dynamicTextPrimary(context),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionLabel(context, 'REMINDERS'),
          const _RemindersCard(),

          const SizedBox(height: 20),
          _sectionLabel(context, 'APP CARE'),
          AppCard(
            onTap: _checkForUpdates,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.presetStocks.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _checking
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.presetStocks,
                          ),
                        )
                      : const Icon(
                          Icons.system_update_rounded,
                          color: AppColors.presetStocks,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check for updates',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Look for a newer release on GitHub',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => WelcomeSheet.show(context),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.dynamicAccent(context),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'See the quick tour again',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dynamicTextPrimary(context),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  'Dispatch Diary',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onVersionTap,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Version $_version',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.dynamicTextDisabled(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Future<void> _editName(
    BuildContext context,
    SettingsRepository settings,
  ) async {
    final controller = TextEditingController(text: settings.despatcherName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This name appears on loading sheets and reports.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Despatcher name',
                hintText: 'e.g. Theolus',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.dynamicTextMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await settings.saveDespatcherName(result);
      if (context.mounted) {
        AppSnacks.success(context, 'Despatcher name saved');
      }
    }
  }
}

class _RemindersCard extends StatefulWidget {
  const _RemindersCard();

  @override
  State<_RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends State<_RemindersCard> {
  late Future<List<Reminder>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseService.getAllReminders();
  }

  void _reload() {
    setState(() {
      _future = DatabaseService.getAllReminders();
    });
  }

  Future<void> _addReminder() async {
    final granted = await NotificationService.requestPermissions();
    if (!granted && mounted) {
      AppSnacks.error(
        context,
        'Notifications are blocked. Enable them in system settings to '
        'receive reminders.',
      );
      return;
    }

    final textController = TextEditingController();
    var date = DateTime.now().add(const Duration(hours: 1));
    if (!mounted) return;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reminder text',
                hintText: 'e.g. Call branch about STOCKS 2',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      AppFormatters.dayKey(date),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                      );
                      if (d != null) {
                        date = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          date.hour,
                          date.minute,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(
                      '${date.hour.toString().padLeft(2, '0')}:'
                      '${date.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(date),
                      );
                      if (t != null) {
                        date = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          t.hour,
                          t.minute,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.dynamicTextMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, date);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (picked == null || !mounted) return;

    final text = textController.text.trim();
    if (text.isEmpty) return;

    final reminder = Reminder(
      id: IdGenerator.generate(),
      entryId: '',
      at: picked.millisecondsSinceEpoch,
      text: text,
    );

    AppHaptics.success();
    await DatabaseService.saveReminder(reminder);
    await NotificationService.scheduleReminder(reminder);
    _reload();
    if (mounted) {
      AppSnacks.success(context, 'Reminder scheduled');
    }
  }

  Future<void> _deleteReminder(Reminder r) async {
    AppHaptics.medium();
    await NotificationService.cancelReminder(r.id);
    await DatabaseService.deleteReminder(r.id);
    _reload();
  }

  Future<void> _toggleDone(Reminder r) async {
    AppHaptics.light();
    final updated = r.copyWith(done: !r.done);
    await DatabaseService.updateReminder(updated);
    if (updated.done) {
      await NotificationService.cancelReminder(updated.id);
    } else {
      await NotificationService.scheduleReminder(updated);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.alarm_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart reminders',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Notifications for anything you need to remember',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _addReminder,
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Reminder>>(
            future: _future,
            builder: (context, snapshot) {
              final reminders = snapshot.data ?? [];
              if (reminders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No reminders yet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.dynamicTextMuted(context),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final r in reminders)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dynamicCardSurface(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.dynamicBorder(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.text,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.dynamicTextPrimary(
                                      context,
                                    ),
                                    decoration: r.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${AppFormatters.formatDayLabel(r.at)} · '
                                  '${AppFormatters.formatTimeHHmm(r.at)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: r.done
                                        ? AppColors.dynamicTextDisabled(context)
                                        : AppColors.dynamicTextMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _toggleDone(r),
                            tooltip: r.done ? 'Mark pending' : 'Mark done',
                            icon: Icon(
                              r.done
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: r.done
                                  ? AppColors.success
                                  : AppColors.dynamicTextMuted(context),
                              size: 20,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteReminder(r),
                            tooltip: 'Delete reminder',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  final EntryRepository repo;
  const _SyncCard({required this.repo});

  @override
  Widget build(BuildContext context) {
    final state = repo.syncState;
    final healthy =
        state.status == SyncStatus.synced || state.status == SyncStatus.idle;
    final syncing = state.status == SyncStatus.syncing;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (healthy ? AppColors.success : AppColors.primary)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: syncing
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGlow,
                    ),
                  )
                : Icon(
                    healthy
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_sync_rounded,
                    color: healthy
                        ? AppColors.success
                        : AppColors.dynamicAccent(context),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  syncing
                      ? 'Syncing…'
                      : (healthy
                            ? 'All changes synced'
                            : '${state.pendingCount} change(s) waiting'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  healthy
                      ? 'Cloud database is up to date'
                      : 'Tap to sync with the cloud now',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              AppHaptics.medium();
              final ok = await repo.syncNow();
              if (context.mounted) {
                if (ok) {
                  AppSnacks.success(context, 'Cloud database synchronized');
                } else {
                  AppSnacks.error(
                    context,
                    state.errorMessage ?? 'Sync failed — check your network',
                  );
                }
              }
            },
            child: const Text('Sync now'),
          ),
        ],
      ),
    );
  }
}
