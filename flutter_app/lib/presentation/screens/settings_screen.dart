import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/sync_state.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final v = await UpdateService.getCurrentVersion();
    if (mounted) setState(() => _version = v);
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
                  'Dispatch Diary · IBT Edition',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Version $_version',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.dynamicTextDisabled(context),
                    fontFamily: 'monospace',
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
