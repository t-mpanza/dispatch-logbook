import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/scan_sounds.dart';
import '../../dispatch/dump_api.dart';
import '../../dispatch/models/dump_customer.dart';
import '../widgets/ui_kit.dart';

/// Scrap & dump customer registry — the Manage Customer Lists counterpart.
///
/// Two lists, one screen: DUMP customers and SCRAP ANALYSIS customers.
/// Operators search the master customer directory and add a customer to
/// either list; the ACTIVE switch enables/disables (`valid`) a registered
/// customer without deleting it.
class DumpRegistryScreen extends StatefulWidget {
  const DumpRegistryScreen({super.key});

  @override
  State<DumpRegistryScreen> createState() => _DumpRegistryScreenState();
}

enum _Segment { dump, scrap }

class _DumpRegistryScreenState extends State<DumpRegistryScreen> {
  final TextEditingController _search = TextEditingController();
  _Segment _segment = _Segment.dump;

  bool _loaded = false;
  bool _busy = false;
  List<DumpCustomer> _dump = const [];
  List<ScrapAnalysisCustomer> _scrap = const [];
  List<CustomerLookupEntry> _directory = const [];
  List<CustomerLookupEntry> _candidates = const [];
  String? _banner;
  bool _bannerOk = false;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        DumpApi.listDumpCustomers(),
        DumpApi.listScrapAnalysisCustomers(),
        DumpApi.listCustomerLookup(),
      ]);
      if (!mounted) return;
      setState(() {
        _dump = results[0] as List<DumpCustomer>;
        _scrap = results[1] as List<ScrapAnalysisCustomer>;
        _directory = results[2] as List<CustomerLookupEntry>;
        _loaded = true;
        _busy = false;
      });
    } on DumpApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _loaded = true;
      });
      _bannerOf(e.message, false);
    }
  }

  void _bannerOf(String message, bool ok) {
    _bannerTimer?.cancel();
    setState(() {
      _banner = message;
      _bannerOk = ok;
    });
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  void _onSearchChanged(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _candidates = q.isEmpty
          ? const []
          : _directory
                .where((c) =>
                    (c.name ?? '').toLowerCase().contains(q) ||
                    (c.code ?? '').toLowerCase().contains(q))
                .take(8)
                .toList();
    });
  }

  bool _isRegistered(CustomerLookupEntry candidate) {
    final id = candidate.id;
    if (_segment == _Segment.dump) {
      return _dump.any((c) => c.customerLookupId == id);
    }
    return _scrap.any((c) => c.customerLookupId == id);
  }

  Future<void> _add(CustomerLookupEntry candidate) async {
    if (_busy) return;
    AppHaptics.medium();
    setState(() => _busy = true);
    try {
      if (_segment == _Segment.dump) {
        await DumpApi.addDumpCustomer(candidate.id!);
      } else {
        await DumpApi.addScrapAnalysisCustomer(candidate.id!);
      }
      ScanSounds.success();
      AppHaptics.success();
      await _load();
      _bannerOf('${candidate.displayLabel} added', true);
    } on DumpApiException catch (e) {
      ScanSounds.error();
      AppHaptics.error();
      _bannerOf(e.message, false);
    }
  }

  Future<void> _toggleDump(DumpCustomer customer, bool active) async {
    await _setValid(
      () => DumpApi.setDumpCustomerValid(customer.id!, active),
      '${customer.displayName} ${active ? 'enabled' : 'disabled'}',
    );
  }

  Future<void> _toggleScrap(ScrapAnalysisCustomer customer, bool active) async {
    await _setValid(
      () => DumpApi.setScrapAnalysisCustomerValid(customer.id!, active),
      '${customer.displayName} ${active ? 'enabled' : 'disabled'}',
    );
  }

  Future<void> _setValid(
    Future<void> Function() write,
    String successMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await write();
      ScanSounds.success();
      AppHaptics.success();
      await _load();
      _bannerOf(successMessage, true);
    } on DumpApiException catch (e) {
      ScanSounds.error();
      AppHaptics.error();
      _bannerOf(e.message, false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCRAP & DUMP CUSTOMERS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            AppHaptics.light();
            Navigator.pop(context);
          },
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              children: [
                _segmentSwitch(),
                const SizedBox(height: 12),
                if (_banner != null) ...[
                  _Banner(message: _banner!, ok: _bannerOk),
                  const SizedBox(height: 10),
                ],
                _searchCard(),
                const SizedBox(height: 12),
                if (_candidates.isNotEmpty) ...[
                  _SectionLabel('ADD CUSTOMER — MATCHES'),
                  const SizedBox(height: 8),
                  for (final candidate in _candidates)
                    _candidateTile(candidate),
                  const SizedBox(height: 12),
                ],
                _SectionLabel(
                  _segment == _Segment.dump
                      ? 'DUMP CUSTOMERS · ${_dump.length}'
                      : 'SCRAP ANALYSIS · ${_scrap.length}',
                ),
                const SizedBox(height: 8),
                if (_segment == _Segment.dump)
                  if (_dump.isEmpty)
                    const _EmptyList('No dump customers registered yet.')
                  else
                    for (final customer in _dump) _dumpTile(customer)
                else if (_scrap.isEmpty)
                  const _EmptyList('No scrap-analysis customers registered yet.')
                else
                  for (final customer in _scrap) _scrapTile(customer),
              ],
            ),
    );
  }

  Widget _segmentSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: GlassDecorations.glassCard(context: context, borderRadius: 16),
      child: Row(
        children: [
          Expanded(child: _segmentChip(_Segment.dump, 'DUMP')),
          Expanded(child: _segmentChip(_Segment.scrap, 'SCRAP ANALYSIS')),
        ],
      ),
    );
  }

  Widget _segmentChip(_Segment segment, String label) {
    final active = _segment == segment;
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        setState(() => _segment = segment);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.info.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            letterSpacing: 1,
            color: active
                ? AppColors.infoStrong(context)
                : AppColors.dynamicTextMuted(context),
          ),
        ),
      ),
    );
  }

  Widget _searchCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: _search,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: 0.8,
          color: AppColors.dynamicTextPrimary(context),
        ),
        decoration: InputDecoration(
          hintText: 'SEARCH CUSTOMER TO ADD',
          hintStyle: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            color: AppColors.dynamicTextMuted(context),
          ),
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _candidateTile(CustomerLookupEntry candidate) {
    final registered = _isRegistered(candidate);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dynamicBorder(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            size: 16,
            color: registered
                ? AppColors.dynamicTextMuted(context)
                : AppColors.successStrong(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              candidate.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: registered
                    ? AppColors.dynamicTextMuted(context)
                    : AppColors.dynamicTextPrimary(context),
              ),
            ),
          ),
          if (registered)
            Text(
              'REGISTERED',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: AppColors.dynamicTextMuted(context),
              ),
            )
          else
            TextButton(
              onPressed: _busy ? null : () => _add(candidate),
              child: const Text('ADD'),
            ),
        ],
      ),
    );
  }

  Widget _dumpTile(DumpCustomer customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.delete_outline_rounded,
            size: 16,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              customer.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.dynamicTextPrimary(context),
              ),
            ),
          ),
          Switch(
            value: true,
            onChanged: _busy ? null : (active) => _toggleDump(customer, active),
            activeTrackColor: AppColors.successStrong(context),
          ),
        ],
      ),
    );
  }

  Widget _scrapTile(ScrapAnalysisCustomer customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.analytics_outlined,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              customer.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.dynamicTextPrimary(context),
              ),
            ),
          ),
          Switch(
            value: true,
            onChanged: _busy ? null : (active) => _toggleScrap(customer, active),
            activeTrackColor: AppColors.successStrong(context),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: AppColors.dynamicTextMuted(context),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.dynamicTextMuted(context),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.ok});

  final String message;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? AppColors.successStrong(context)
        : AppColors.errorStrong(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
