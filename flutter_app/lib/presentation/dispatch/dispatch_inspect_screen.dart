import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/services/database_service.dart';
import '../../dispatch/domain/tyre_story.dart';

/// The inspection HUD — lite (text-input) mode: type the tyre's slip
/// number (cab number) or serial, resolve it live, then APPROVE or SCRAP.
/// UIDs are invisible to operators, so the lite flow keys on the two
/// identifiers actually printed on the tyre. Decisions persist locally.
class DispatchInspectScreen extends StatefulWidget {
  const DispatchInspectScreen({super.key});

  @override
  State<DispatchInspectScreen> createState() => _DispatchInspectScreenState();
}

class _FeedEntry {
  const _FeedEntry(this.identifier, this.label, this.color);

  final String identifier;
  final String label;
  final Color color;
}

class _DispatchInspectScreenState extends State<DispatchInspectScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_FeedEntry> _feed = [];
  bool _busy = false;
  TyreStory? _last;
  String? _banner;

  @override
  void initState() {
    super.initState();
    _restoreDecisions();
  }

  Future<void> _restoreDecisions() async {
    final decisions = await DatabaseService.getDispatchDecisions();
    if (!mounted) return;
    setState(() {
      for (final entry in decisions.entries) {
        _feed.insert(
          0,
          _FeedEntry(
            entry.key,
            entry.value == 'APPROVE' ? 'APPROVED' : 'SCRAPPED',
            entry.value == 'APPROVE'
                ? AppColors.successStrong(context)
                : AppColors.errorStrong(context),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _identifierFor(TyreStory story) {
    final slip = story.tyre.slipNumber;
    if (slip != null) return 'SLIP $slip';
    final serial = story.tyre.serial;
    if (serial != null && serial.isNotEmpty) return serial;
    return _controller.text.trim().toUpperCase();
  }

  Future<void> _scan() async {
    final input = _controller.text.trim().toUpperCase();
    if (input.isEmpty) return;
    AppHaptics.medium();
    setState(() {
      _busy = true;
      _banner = null;
      _last = null;
    });

    try {
      const usecase = TyreStoryUsecase();
      final asNumber = int.tryParse(input);
      final story = asNumber != null
          ? await usecase.bySlipOrJobNumber(asNumber)
          : await usecase.bySerial(input);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _last = story;
        if (story == null) {
          _banner = 'No tyre found for "$input".';
          AppHaptics.error();
        } else {
          AppHaptics.light();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = 'Lookup failed: $e';
      });
      AppHaptics.error();
    }
  }

  Future<void> _decide(String decision) async {
    final story = _last;
    if (story == null) return;
    final identifier = _identifierFor(story);
    AppHaptics.success();
    await DatabaseService.saveDispatchDecision(
      uid: identifier,
      decision: decision,
    );
    if (!mounted) return;
    setState(() {
      _feed.insert(
        0,
        _FeedEntry(
          identifier,
          decision == 'APPROVE' ? 'APPROVED' : 'SCRAPPED',
          decision == 'APPROVE'
              ? AppColors.successStrong(context)
              : AppColors.errorStrong(context),
        ),
      );
      _last = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = _last;
    final scrap = story?.isScrapWithHistory ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        Container(
          decoration: GlassDecorations.glassCard(context: context, borderRadius: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 1.4,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'SLIP NUMBER OR SERIAL',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.dynamicTextMuted(context),
                      letterSpacing: 1,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _scan(),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _scan,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_scanner_rounded,
                        color: AppColors.info),
                tooltip: 'Resolve tyre',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_banner != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _banner!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),

        if (story != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: GlassDecorations.glassCard(
              context: context,
              borderRadius: 18,
              borderColor: (scrap
                      ? AppColors.errorStrong(context)
                      : AppColors.successStrong(context))
                  .withValues(alpha: 0.5),
            ),
            child: Column(
              children: [
                Text(
                  story.tyre.displayLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${story.tyre.customerName ?? 'Unknown customer'} · '
                  'CS ${story.tyre.csNumber ?? '—'} · '
                  'slip ${story.tyre.slipNumber ?? '—'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DecisionButton(
                        label: 'APPROVE',
                        icon: Icons.check_rounded,
                        color: AppColors.successStrong(context),
                        onTap: () => _decide('APPROVE'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DecisionButton(
                        label: 'SCRAP',
                        icon: Icons.close_rounded,
                        color: AppColors.errorStrong(context),
                        onTap: () => _decide('SCRAP'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        Text(
          'DECISION FEED · ${_feed.length}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.dynamicTextMuted(context),
          ),
        ),
        const SizedBox(height: 8),
        if (_feed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Decisions land here as you approve or scrap tyres.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
          )
        else
          for (final entry in _feed.take(50)) _feedTile(entry),
      ],
    );
  }

  Widget _feedTile(_FeedEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: entry.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: entry.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.identifier,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
                color: AppColors.dynamicTextPrimary(context),
              ),
            ),
          ),
          Text(
            entry.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: entry.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
