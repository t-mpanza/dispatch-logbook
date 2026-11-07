import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/scan_sounds.dart';
import '../../data/models/entry.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/models/trip.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../dispatch/dispatch_api.dart';
import '../../dispatch/hardware/nfc_scan_service.dart';
import '../../dispatch/ibt_scan_api.dart';
import '../../dispatch/models/slip_tyre.dart';
import '../widgets/ui_kit.dart';

/// THE scrap run-out screen — dedicated, not the generic counter.
///
/// No target exists. Whatever valid scrap scans, counts; wrong scans are
/// removed. Fixed truck KH58XD / driver RICHMORE (still editable). The
/// same hardened NFC pipeline as stocks: continuous session, typed-UID
/// fallback, binary sounds, precise banners.
class ScrapsScreen extends StatefulWidget {
  final String entryId;

  const ScrapsScreen({super.key, required this.entryId});

  @override
  State<ScrapsScreen> createState() => _ScrapsScreenState();
}

class _ScrapsScreenState extends State<ScrapsScreen>
    with WidgetsBindingObserver {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _regController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();

  final NfcScanService _nfc = NfcScanService();
  StreamSubscription<String>? _scanSub;
  bool _scanArmed = false;
  bool _scanBusy = false;

  /// Re-arm silently when the app returns to the foreground after being
  /// backgrounded mid-session (another NFC app may have taken the reader).
  bool _autoRearm = false;

  /// A tag read while a commit was still in flight — processed next,
  /// never dropped (production pace is ~5s per tyre).
  String? _pendingUid;

  String? _scanBanner;
  bool _scanBannerOk = false;
  Timer? _bannerTimer;
  final Set<String> _sessionUids = {};
  int? _operatorId;

  Entry? _cachedEntry;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanSub = _nfc.scans.listen(_handleScan);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_armScan(announceFailure: false));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _scanArmed) {
      _autoRearm = true;
      _disarmScan();
    } else if (state == AppLifecycleState.resumed && _autoRearm) {
      _autoRearm = false;
      if (mounted) unawaited(_armScan(announceFailure: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _scanSub?.cancel();
    _nfc.stop();
    _nfc.dispose();
    _titleController.dispose();
    _regController.dispose();
    _driverController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<EntryRepository>();
    final entry = await repo.getEntryById(widget.entryId);
    if (!mounted) return;
    setState(() {
      _cachedEntry = entry;
      _loaded = true;
    });
    _syncControllersFromEntry(entry);
  }

  void _syncControllersFromEntry(Entry? entry) {
    if (entry == null) return;
    final trip = _primaryTrip(entry);
    if (_titleController.text.isEmpty) {
      _titleController.text = entry.title;
    }
    if (_regController.text.isEmpty) {
      _regController.text = trip?.reg ?? 'KH58XD';
    }
    if (_driverController.text.isEmpty) {
      _driverController.text = trip?.driverName ?? 'RICHMORE';
    }
  }

  LoadingSheetTrip? _primaryTrip(Entry entry) {
    for (final t in entry.loadingSheetTrips ?? const <LoadingSheetTrip>[]) {
      if (!t.isManual) return t;
    }
    return null;
  }

  /// Every counter change is mirrored onto the SCRAPS sheet row so the
  /// Sheet/Today totals and the reg/driver stay truthful.
  Entry _withSyncedSheetTrip(Entry entry, List<Trip> trips) {
    final total = trips.fold<int>(0, (s, t) => s + t.count + (t.rejected ?? 0));
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = [...?entry.loadingSheetTrips];
    final idx = current.indexWhere((t) => !t.isManual);
    final trip = (idx >= 0 ? current[idx] : null) ??
        LoadingSheetTrip(
          id: IdGenerator.generate(),
          entryId: entry.id,
          reg: _regController.text.trim().toUpperCase(),
          driverName: _driverController.text.trim(),
          tripId: 'SCRAPS',
          quantityLoaded: 0,
          startTime: now,
          createdAt: now,
        );

    final updated = trip.copyWith(
      entryId: entry.id,
      reg: _regController.text.trim().toUpperCase(),
      driverName: _driverController.text.trim(),
      tripId: 'SCRAPS',
      quantityLoaded: total,
      startTime: trip.startTime ?? now,
      finishTime: total > 0 ? now : trip.finishTime,
    );

    if (idx >= 0) {
      current[idx] = updated;
    } else {
      current.add(updated);
    }
    return entry.copyWith(trips: trips, loadingSheetTrips: current);
  }

  Future<void> _saveEntry(Entry entry) async {
    final repo = context.read<EntryRepository>();
    await repo.saveEntry(entry);
    if (mounted) setState(() => _cachedEntry = entry);
  }

  void _showBanner(String message, bool ok) {
    _bannerTimer?.cancel();
    setState(() {
      _scanBanner = message;
      _scanBannerOk = ok;
    });
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _scanBanner = null);
    });
  }

  Future<void> _armScan({bool announceFailure = true}) async {
    final settings = context.read<SettingsRepository>();
    if (!settings.nfcEnabled) {
      if (announceFailure) {
        ScanSounds.error();
        AppHaptics.error();
        _showBanner('NFC scanning is turned off in Settings', false);
      }
      return;
    }
    try {
      await _nfc.start();
      if (mounted) setState(() => _scanArmed = true);
    } catch (_) {
      if (mounted && announceFailure) {
        ScanSounds.error();
        AppHaptics.error();
        _showBanner('NFC not available on this device', false);
      }
    }
  }

  Future<void> _disarmScan() async {
    await _nfc.stop();
    if (mounted) setState(() => _scanArmed = false);
  }

  Future<int?> _resolveOperator() async {
    if (_operatorId != null) return _operatorId;
    try {
      final id = await IbtScanApi.resolveOperatorId();
      _operatorId = id;
      return id;
    } on ScanCommitException {
      return null;
    }
  }

  /// The scrap scan pipeline: look up → commit → count +1.
  ///
  /// This screen is the MANUAL scan-out fallback (used when invoice
  /// numbers don't work), NOT a scrap gate: any tyre on the system passes.
  /// Dedupe per session only; the backend decides everything else.
  Future<void> _handleScan(String uid) async {
    if (_scanBusy || !mounted) {
      if (mounted) _pendingUid = uid;
      return;
    }

    setState(() {
      _scanBusy = true;
      _scanBanner = null;
    });

    try {
      final repo = context.read<EntryRepository>();
      final entry = _cachedEntry ?? await repo.getEntryById(widget.entryId);
      if (entry == null) return;

      final operatorId = await _resolveOperator();
      if (operatorId == null) {
        ScanSounds.error();
        AppHaptics.error();
        _showBanner('Operator Theolus Mpanza not found', false);
        return;
      }

      SlipTyre? tyre;
      try {
        tyre = await DispatchApi.fetchTyreByUid(uid);
      } catch (_) {
        ScanSounds.error();
        AppHaptics.error();
        _showBanner('Connection failed — try again', false);
        return;
      }
      if (tyre == null || tyre.uid == null) {
        ScanSounds.error();
        AppHaptics.error();
        _showBanner('Tyre Not Found', false);
        return;
      }

      final reg = _regController.text.trim().toUpperCase();
      if (reg.isEmpty) {
        ScanSounds.error();
        AppHaptics.error();
        _showBanner('Set the truck REG first', false);
        return;
      }
      if (_sessionUids.contains(tyre.uid!)) {
        ScanSounds.error();
        AppHaptics.error();
        _showBanner('Already counted this session', false);
        return;
      }

      final ScanCommitResult result;
      try {
        result = await IbtScanApi.commitScan(
          uid: tyre.uid!,
          registration: reg,
          personnelId: operatorId,
          documentNo: 'SCRAPS',
        );
      } on ScanCommitException catch (e) {
        // Ambiguous: the backend may have committed while the app saw an
        // error. Ask the backend for the truth before reporting failure.
        final recorded = await DispatchApi.verifyTyreOnTruck(tyre.uid!, reg);
        if (recorded) {
          await _countScan(entry, tyre.uid!);
          return;
        }
        ScanSounds.error();
        AppHaptics.error();
        final message = e.message.toLowerCase();
        _showBanner(
          message.contains('no slip found') || message.contains('not found')
              ? 'Tyre Not Found'
              : 'Connection failed — try again',
          false,
        );
        return;
      }

      if (result is ScanCommitRejected) {
        final recorded = await DispatchApi.verifyTyreOnTruck(tyre.uid!, reg);
        if (recorded) {
          await _countScan(entry, tyre.uid!);
          return;
        }
        ScanSounds.error();
        AppHaptics.error();
        _showBanner('Scan rejected by system', false);
        return;
      }

      switch (result) {
        case ScanCommitSuccess():
          await _countScan(entry, tyre.uid!);
        case ScanCommitDuplicate(:final name, :final scanTime):
          ScanSounds.error();
          AppHaptics.error();
          _showBanner(
            'Previously loaded by ${name ?? 'someone'}'
            '${scanTime != null ? ' on $scanTime' : ''}',
            false,
          );
        case ScanCommitRejected():
          // Unreachable (handled above).
          ScanSounds.error();
          AppHaptics.error();
          _showBanner('Scan rejected by system', false);
      }
    } finally {
      if (mounted) {
        setState(() => _scanBusy = false);
        final pending = _pendingUid;
        _pendingUid = null;
        if (pending != null) {
          unawaited(_handleScan(pending));
        }
      }
    }
  }

  /// Count one confirmed scan (commit response or read-back).
  Future<void> _countScan(Entry entry, String uid) async {
    _sessionUids.add(uid);
    final now = DateTime.now().millisecondsSinceEpoch;
    final trips = [
      ...?entry.trips,
      Trip(id: IdGenerator.generate(), count: 1, createdAt: now),
    ];
    await _saveEntry(_withSyncedSheetTrip(entry, trips));
    ScanSounds.success();
    AppHaptics.success();
    _showBanner('LOADED — SCRAPS · ${_total(trips)} so far', true);
  }

  Future<void> _submitTypedUid() async {
    final uid = _uidController.text.trim().toUpperCase();
    if (uid.isEmpty || uid.length != 14) {
      ScanSounds.error();
      AppHaptics.error();
      _showBanner('UID must be 14 hex characters', false);
      return;
    }
    await _handleScan(uid);
    _uidController.clear();
  }

  int _total(List<Trip>? trips) =>
      (trips ?? const []).fold<int>(0, (s, t) => s + t.count + (t.rejected ?? 0));

  Future<void> _removeOne() async {
    final repo = context.read<EntryRepository>();
    final entry = _cachedEntry ?? await repo.getEntryById(widget.entryId);
    final trips = [...?entry?.trips];
    if (trips.isEmpty) {
      AppHaptics.error();
      _showBanner('Nothing to remove', false);
      return;
    }
    AppHaptics.medium();
    trips.removeLast();
    await _saveEntry(_withSyncedSheetTrip(entry!, trips));
    _showBanner('Removed one — ${_total(trips)} so far', true);
  }

  @override
  Widget build(BuildContext context) {
    final entry = _cachedEntry;
    final total = _total(entry?.trips);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          decoration: const InputDecoration(border: InputBorder.none),
          onSubmitted: (val) async {
            if (val.trim().isNotEmpty && entry != null) {
              await _saveEntry(entry.copyWith(title: val.trim()));
            }
          },
        ),
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
                // ── HERO: the count. No target — none exists. ──
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: GlassDecorations.glassCard(
                    context: context,
                    borderRadius: 22,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SCRAP RUN-OUT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$total',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          height: 1,
                          color: AppColors.errorStrong(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'NO TARGET — WHATEVER SCANS, COUNTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Truck ──
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _regController,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: AppColors.dynamicTextPrimary(context),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'REG NUMBER',
                            isDense: true,
                          ),
                          onChanged: (val) {
                            if (entry != null) {
                              _saveEntry(
                                _withSyncedSheetTrip(entry, entry.trips ?? []),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _driverController,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dynamicTextPrimary(context),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'DRIVER',
                            isDense: true,
                          ),
                          onChanged: (val) {
                            if (entry != null) {
                              _saveEntry(
                                _withSyncedSheetTrip(entry, entry.trips ?? []),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── SCAN (continuous + typed fallback) ──
                _scanCard(context),
                if (_scanBanner != null) ...[
                  const SizedBox(height: 10),
                  _ScanBanner(message: _scanBanner!, ok: _scanBannerOk),
                ],
                const SizedBox(height: 12),

                // ── Remove one ──
                GestureDetector(
                  onTap: _removeOne,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.warningStrong(
                        context,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warningStrong(
                          context,
                        ).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 20,
                          color: AppColors.warningStrong(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'REMOVE ONE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: AppColors.warningStrong(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Log ──
                Text(
                  'SCAN LOG · ${(entry?.trips ?? const []).length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
                const SizedBox(height: 8),
                if ((entry?.trips ?? const []).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No scraps counted yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                  )
                else
                  for (final t in (entry!.trips ?? const []).reversed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '+${t.count + (t.rejected ?? 0)} · '
                              '${DateTime.fromMillisecondsSinceEpoch(t.createdAt).hour.toString().padLeft(2, '0')}:'
                              '${DateTime.fromMillisecondsSinceEpoch(t.createdAt).minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: AppColors.dynamicTextPrimary(context),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              AppHaptics.medium();
                              final trips = [...?entry.trips]
                                ..remove(t);
                              await _saveEntry(
                                _withSyncedSheetTrip(entry, trips),
                              );
                            },
                            child: const Icon(
                              Icons.undo_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }

  Widget _scanCard(BuildContext context) {
    final color = _scanArmed
        ? AppColors.successStrong(context)
        : AppColors.errorStrong(context);

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: _scanArmed ? color.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.nfc_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCAN SCRAP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _scanArmed
                          ? 'WAITING FOR TAG — hold the tyre tag to the reader'
                          : 'Scan the tag — every valid scrap counts',
                      style: TextStyle(
                        fontSize: 11,
                        color: _scanArmed
                            ? AppColors.successStrong(context)
                            : AppColors.dynamicTextMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (_scanBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: _scanArmed
                      ? () {
                          _autoRearm = false;
                          _disarmScan();
                        }
                      : () => _armScan(),
                  child: Text(_scanArmed ? 'Stop' : 'Arm'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _uidController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9A-Fa-f]')),
                    LengthLimitingTextInputFormatter(14),
                  ],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'TYPE UID (14-HEX) — NO NFC?',
                    hintStyle: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.dynamicTextMuted(context),
                      letterSpacing: 1,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _submitTypedUid(),
                ),
              ),
              TextButton(
                onPressed: _scanBusy ? null : _submitTypedUid,
                child: const Text('Scan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanBanner extends StatelessWidget {
  final String message;
  final bool ok;

  const _ScanBanner({required this.message, required this.ok});

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
