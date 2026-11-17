import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/entry.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/models/staged_document.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/staged_document_repository.dart';
import '../../data/services/database_service.dart';
import '../../data/services/dibt_progress_reminder.dart';
import '../../data/services/document_resolver.dart';
import '../../data/services/notification_service.dart';
import '../../dispatch/dispatch_api.dart';
import '../../dispatch/domain/document_number.dart';
import '../../dispatch/domain/multi_doc_scan_engine.dart';
import '../../dispatch/domain/scan_feedback.dart';
import '../../dispatch/hardware/nfc_scan_service.dart';
import '../../dispatch/ibt_scan_api.dart';
import '../../dispatch/models/slip_tyre.dart';
import '../widgets/offload_dialog.dart';
import '../widgets/tyre_block.dart';

/// THE truck hub — one entry, every staged document, one head-down
/// scanner (P4/D1-D17).
///
/// Documents stage in parallel from one paste (DocumentResolver), render
/// as accordion sections (closed by default) with the CUSTOMER on the
/// header, tyre blocks inside (D11), and every scan routes through
/// MultiDocScanEngine → ScanFeedback (haptics included) with the offload
/// window (D5), cash arm toggle (D7) and DIBT 90/100% reminders (D13).
class TruckHubScreen extends StatefulWidget {
  const TruckHubScreen({super.key, required this.entryId, this.resolver});

  final String entryId;
  final DocumentResolver? resolver;

  @override
  State<TruckHubScreen> createState() => _TruckHubScreenState();
}

class _TruckHubScreenState extends State<TruckHubScreen>
    with WidgetsBindingObserver {
  final TextEditingController _slipController = TextEditingController();
  final NfcScanService _nfc = NfcScanService();
  StreamSubscription<String>? _scanSub;

  /// CC/BCC-style document rows — each row is a TYPE + digits.
  final List<_DocRow> _docRows = [_DocRow()];

  List<StagedDocument> _docs = [];
  List<String> _recents = [];
  final Map<String, DocumentResolveResult> _results = {};
  final Set<String> _openSections = {};
  final Map<String, String> _filters = {};
  final Set<String> _sessionUids = {};
  final Map<String, String> _sessionDocByUid = {};
  final Map<String, (String, String)> _sessionLineByUid = {};
  int _cashCount = 0;

  bool _resolving = false;
  bool _cashArmed = false;
  bool _scanArmed = false;
  bool _scanBusy = false;
  String? _banner;
  bool _bannerOk = false;
  Timer? _bannerTimer;
  String _reg = '';
  String _driver = '';
  String _tripId = '';
  int? _operatorId;

  late final Future<Database> _dbFuture = DatabaseService.database;
  StagedDocumentRepository _resolvedRepo(Database db) =>
      StagedDocumentRepository(db);

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
      _disarmScan();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _scanSub?.cancel();
    _nfc.stop();
    _nfc.dispose();
    _slipController.dispose();
    for (final row in _docRows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final db = await _dbFuture;
    final docs = await _resolvedRepo(db).listForEntry(widget.entryId);
    final recents = await _resolvedRepo(db).recentDocumentNos();
    final entry = await EntryRepository().getEntryById(widget.entryId);
    final trip = _primaryTrip(entry);
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _recents = recents;
      _reg = (trip?.reg ?? '').trim().toUpperCase();
      _driver = (trip?.driverName ?? '').trim();
      _tripId = (trip?.tripId ?? '').trim().toUpperCase();
    });
    // D13 reminders can only land with notification permission — request
    // it the moment a DIBT is staged (Android 13+ shows the prompt once).
    // Best-effort: notification plumbing must never break the hub.
    if (docs.any((d) => d.stream == DocumentStream.dibt)) {
      unawaited(_requestReminderPermission());
    }
  }

  Future<void> _requestReminderPermission() async {
    try {
      await NotificationService.requestPermissions();
    } catch (_) {}
  }

  LoadingSheetTrip? _primaryTrip(Entry? entry) {
    for (final t in entry?.loadingSheetTrips ?? const <LoadingSheetTrip>[]) {
      if (!t.isManual) return t;
    }
    return null;
  }

  void _showBanner(String message, bool ok) {
    _bannerTimer?.cancel();
    setState(() {
      _banner = message;
      _bannerOk = ok;
    });
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  // ── Document staging (D16 parallel, D8 duplicates) ─────────────────

  /// Stage every filled row (type + digits) in parallel. Each document's
  /// type is EXPLICIT — no guessing, no fat-finger prefixes.
  Future<void> _stageDocuments({String? preset}) async {
    final tokens = <String>[];
    if (preset != null) {
      tokens.add(preset);
    } else {
      for (final row in _docRows) {
        final digits = row.controller.text.trim();
        if (digits.isEmpty) continue;
        tokens.add('${row.type.code}$digits');
      }
    }
    if (tokens.isEmpty || _resolving) return;
    setState(() => _resolving = true);
    final db = await _dbFuture;
    final repo = _resolvedRepo(db);
    final resolver = widget.resolver ?? DocumentResolver();
    final results = await resolver.resolveBatch(
      entryId: widget.entryId,
      input: tokens.join(','),
    );
    final docs = await repo.listForEntry(widget.entryId);
    final recents = await repo.recentDocumentNos();
    if (!mounted) return;
    setState(() {
      for (final r in results) {
        _results[r.input] = r;
      }
      _docs = docs;
      _recents = recents;
      for (final r in results.where((r) => r.isOk)) {
        _openSections.add(r.document!.documentNo);
      }
      _resolving = false;
      if (preset == null) {
        for (final row in _docRows) {
          row.controller.clear();
        }
      }
    });
    final ok = results.where((r) => r.isOk).length;
    final failed = results.length - ok;
    _showBanner(
      failed == 0
          ? 'Staged ${results.length} document${results.length == 1 ? '' : 's'}'
          : 'Staged $ok · $failed failed — check the chips',
      failed == 0,
    );
  }

  // ── Scanning ───────────────────────────────────────────────────────

  Future<void> _armScan({bool announceFailure = true}) async {
    final settings = SettingsRepository();
    await settings.loadSettings();
    if (!settings.nfcEnabled) {
      if (announceFailure) {
        ScanFeedback.wrong();
        _showBanner('NFC scanning is turned off in Settings', false);
      }
      return;
    }
    try {
      await _nfc.start();
      if (mounted) setState(() => _scanArmed = true);
    } catch (_) {
      if (mounted && announceFailure) {
        ScanFeedback.wrong();
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
    } on Exception {
      return null;
    }
  }

  Future<void> _handleScan(String uid) async {
    if (_scanBusy || !mounted) return;
    setState(() {
      _scanBusy = true;
      _banner = null;
    });

    try {
      SlipTyre? tyre;
      try {
        tyre = await DispatchApi.fetchTyreByUid(uid);
      } catch (_) {
        ScanFeedback.wrong();
        _showBanner('Connection failed — try again', false);
        return;
      }
      if (tyre == null || tyre.uid == null) {
        ScanFeedback.wrong();
        _showBanner('Tyre Not Found', false);
        return;
      }
      await _processTyre(tyre);
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  /// Manual entry (D9): type the SLIP number — the tag's chip uid is
  /// never shown or typed. Same pipeline as an NFC scan.
  Future<void> _submitManualSlip() async {
    final slip = int.tryParse(_slipController.text.trim());
    if (slip == null || _scanBusy) return;
    setState(() {
      _scanBusy = true;
      _banner = null;
    });
    try {
      SlipTyre? tyre;
      try {
        tyre = await DispatchApi.fetchTyreBySlipNumber(slip);
      } catch (_) {
        ScanFeedback.wrong();
        _showBanner('Connection failed — try again', false);
        return;
      }
      if (tyre == null) {
        ScanFeedback.wrong();
        _showBanner('Tyre Not Found', false);
        return;
      }
      await _processTyre(tyre);
    } finally {
      if (mounted) setState(() => _scanBusy = false);
      _slipController.clear();
    }
  }

  /// The shared verdict pipeline — NFC and manual scans converge here.
  Future<void> _processTyre(SlipTyre tyre) async {
    final uid = tyre.uid!;
    final operatorId = await _resolveOperator();
    if (operatorId == null) {
      ScanFeedback.wrong();
      _showBanner('Operator Theolus Mpanza not found', false);
      return;
    }

    final verdict = MultiDocScanEngine.evaluate(
      stagedDocs: _docs,
      tyre: tyre,
      sessionUids: _sessionUids,
      cashArmed: _cashArmed,
      operatorId: operatorId,
      registration: _reg,
    );

    switch (verdict) {
      case AcceptedIntoDocument(:final documentNo, :final lineId, :final line):
        await _commitLoad(
          uid: uid,
          documentNo: documentNo,
          operatorId: operatorId,
          onLocal: () => _markLoaded(
            uid: uid,
            documentNo: documentNo,
            lineId: lineId,
            line: line,
          ),
          tyre: tyre,
        );
      case AcceptedAsCash():
        await _commitCash(uid: uid, operatorId: operatorId, tyre: tyre);
      case AmbiguousDocument(:final documentNos):
        ScanFeedback.wrong();
        await _promptApplyToBoth(uid, tyre, documentNos, operatorId);
      case OffloadPrompt():
        ScanFeedback.wrong();
        await _promptOffload(uid, tyre, operatorId);
      case Collision(:final previousReg):
        ScanFeedback.wrong();
        _showBanner('On another truck — $previousReg', false);
      case DumpedTyre():
        ScanFeedback.wrong();
        _showBanner('This tyre is dumped', false);
      case UntoggleCashPrompt(:final documentNo):
        ScanFeedback.wrong();
        await _promptUntoggleCash(documentNo);
      case Rejected(:final message):
        ScanFeedback.wrong();
        _showBanner(message, false);
    }
  }

  Future<void> _commitLoad({
    required String uid,
    required String documentNo,
    required int operatorId,
    required VoidCallback onLocal,
    required SlipTyre tyre,
  }) async {
    final ScanCommitResult result;
    try {
      result = await IbtScanApi.commitScan(
        uid: uid,
        registration: _reg,
        personnelId: operatorId,
        documentNo: documentNo,
        loaded: 1,
        screen: 'truck_hub',
      );
    } on ScanCommitException catch (e) {
      ScanFeedback.wrong();
      final m = e.message.toLowerCase();
      _showBanner(
        m.contains('no slip found') || m.contains('not found')
            ? 'Tyre Not Found'
            : 'Connection failed — try again',
        false,
      );
      return;
    }

    switch (result) {
      case ScanCommitSuccess():
        onLocal();
        _sessionUids.add(uid);
        _sessionDocByUid[uid] = documentNo;
        ScanFeedback.correct();
        _showBanner('LOADED — $documentNo', true);
      case ScanCommitDuplicate(:final name, :final scanTime):
        ScanFeedback.wrong();
        _showBanner(
          'Previously loaded by ${name ?? 'someone'}'
          '${scanTime != null ? ' on $scanTime' : ''}',
          false,
        );
      case ScanCommitRejected():
        ScanFeedback.wrong();
        _showBanner('Scan rejected by system', false);
    }
  }

  Future<void> _commitCash({
    required String uid,
    required int operatorId,
    required SlipTyre tyre,
  }) async {
    final ibts = _docs.where((d) => d.isIbt).toList();
    if (ibts.length != 1) {
      ScanFeedback.wrong();
      _showBanner(
        ibts.isEmpty
            ? 'Cash needs an attached IBT'
            : 'Cash needs exactly one IBT — stage one',
        false,
      );
      return;
    }
    final ScanCommitResult result;
    try {
      result = await IbtScanApi.commitScan(
        uid: uid,
        registration: _reg,
        personnelId: operatorId,
        documentNo: ibts.single.documentNo,
        loaded: 1,
        screen: 'truck_hub',
      );
    } on ScanCommitException {
      ScanFeedback.wrong();
      _showBanner('Connection failed — try again', false);
      return;
    }
    switch (result) {
      case ScanCommitSuccess():
        setState(() {
          _sessionUids.add(uid);
          _cashCount++;
        });
        ScanFeedback.correct();
        _showBanner('LOADED — CASH · $_cashCount today', true);
      case ScanCommitDuplicate(:final name, :final scanTime):
        ScanFeedback.wrong();
        _showBanner(
          'Previously loaded by ${name ?? 'someone'}'
          '${scanTime != null ? ' on $scanTime' : ''}',
          false,
        );
      case ScanCommitRejected():
        ScanFeedback.wrong();
        _showBanner('Scan rejected by system', false);
    }
  }

  void _markLoaded({
    required String uid,
    required String documentNo,
    String? lineId,
    IbtLineItem? line,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _docs = [
        for (final d in _docs)
          if (d.documentNo != documentNo)
            d
          else if (d.isIbt && lineId != null && line != null)
            d.copyWith(
              cachedAt: now,
              lineItems: [
                for (final l in d.lineItems)
                  if (l.id != lineId)
                    l
                  else
                    l.copyWith(
                      loadedQuantity: l.loadedQuantity + 1,
                      history: [
                        ...l.history,
                        IbtLineEvent(id: IdGenerator.generate(), delta: 1, at: now),
                      ],
                    ),
              ],
            )
          else
            d.copyWith(
              cachedAt: now,
              slips: [
                for (final s in d.slips)
                  if (s.uid != uid)
                    s
                  else
                    s.copyWith(
                      loaded: 1,
                      previousReg: _reg,
                    ),
              ],
            ),
      ];
    });
    _checkDibtReminder(documentNo, now);
    unawaited(_persistDocs());
  }

  void _checkDibtReminder(String documentNo, int now) {
    StagedDocument? doc;
    for (final d in _docs) {
      if (d.documentNo == documentNo) {
        doc = d;
        break;
      }
    }
    if (doc == null ||
        doc.stream != DocumentStream.dibt ||
        doc.total == null) {
      return;
    }
    final after = doc.loadedCount / doc.total!;
    final before = (doc.loadedCount - 1) / doc.total!;
    final label = _tripId.isNotEmpty ? _tripId : documentNo;
    for (final point
        in DibtProgressReminder.thresholdsCrossed(before, after)) {
      // Once only — persisted, so re-opening the truck never re-fires.
      final flag = 'dibt_reminded_${documentNo}_$point';
      unawaited(_fireOnce(flag: flag, documentNo: documentNo, point: point, label: label));
    }
  }

  Future<void> _fireOnce({
    required String flag,
    required String documentNo,
    required double point,
    required String label,
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool(flag) ?? false) return;
      await sp.setBool(flag, true);
      await NotificationService.showNow(
        title: documentNo,
        body: DibtProgressReminder.messageFor(point, label),
      );
    } catch (_) {}
  }

  Future<void> _persistDocs() async {
    final db = await _dbFuture;
    final repo = _resolvedRepo(db);
    for (final d in _docs) {
      await repo.upsert(d);
    }
  }

  // ── Verdict dialogs (D4, D5, D7) ───────────────────────────────────

  Future<void> _promptApplyToBoth(
    String uid,
    SlipTyre tyre,
    List<String> documentNos,
    int operatorId,
  ) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text(
          'ON TWO DOCUMENTS',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '${tyre.slipNumber ?? tyre.uid} is on both. Where does it go?',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          for (final no in documentNos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, no),
              child: Text(no, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'BOTH'),
            child: const Text(
              'BOTH — apply to every document',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    final targets = chosen == 'BOTH' ? documentNos : [chosen];
    for (final no in targets) {
      await _commitLoad(
        uid: uid,
        documentNo: no,
        operatorId: operatorId,
        onLocal: () => _markLoaded(uid: uid, documentNo: no),
        tyre: tyre,
      );
    }
  }

  Future<void> _promptOffload(String uid, SlipTyre tyre, int operatorId) async {
    final documentNo = _sessionDocByUid[uid] ??
        _findDocContaining(uid, tyre.slipNumber);
    final confirm = await showOffloadDialog(
      context,
      label: '${tyre.slipNumber ?? uid} · ${documentNo ?? ''}',
    );
    if (confirm != true || !mounted) return;
    if (documentNo == null) {
      _showBanner('Cannot offload — document unknown', false);
      return;
    }
    final ScanCommitResult result;
    try {
      result = await IbtScanApi.commitScan(
        uid: uid,
        registration: _reg,
        personnelId: operatorId,
        documentNo: documentNo,
        loaded: 0,
        screen: 'truck_hub',
      );
    } on ScanCommitException {
      ScanFeedback.wrong();
      _showBanner('Connection failed — offload not saved', false);
      return;
    }
    switch (result) {
      case ScanCommitSuccess():
        setState(() {
          _sessionUids.remove(uid);
          _sessionDocByUid.remove(uid);
          if (_sessionLineByUid.containsKey(uid)) {
            final (docNo, lineId) = _sessionLineByUid.remove(uid)!;
            _docs = _decrementLine(docNo, lineId);
          } else {
            _docs = _unloadSlip(documentNo, uid, tyre.slipNumber);
          }
          if (_cashCount > 0 && !_docs.any((d) => d.containsUid(uid))) {
            // Cash offload: no manifest line to touch; drop the count if
            // it was a session cash scan.
          }
        });
        ScanFeedback.correct();
        _showBanner('OFFLOADED — $documentNo', true);
      default:
        ScanFeedback.wrong();
        _showBanner('Offload failed — try again', false);
    }
  }

  List<StagedDocument> _unloadSlip(
    String documentNo,
    String uid,
    int? slipNumber,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      for (final d in _docs)
        if (d.documentNo != documentNo)
          d
        else
          d.copyWith(
            cachedAt: now,
            slips: [
              for (final s in d.slips)
                if (s.uid != uid && (slipNumber == null || s.slipNumber != slipNumber))
                  s
                else
                  s.copyWith(loaded: 0),
            ],
          ),
    ];
  }

  List<StagedDocument> _decrementLine(String documentNo, String lineId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      for (final d in _docs)
        if (d.documentNo != documentNo)
          d
        else
          d.copyWith(
            cachedAt: now,
            lineItems: [
              for (final l in d.lineItems)
                if (l.id != lineId)
                  l
                else
                  l.copyWith(
                    loadedQuantity:
                        l.loadedQuantity > 0 ? l.loadedQuantity - 1 : 0,
                  ),
            ],
          ),
    ];
  }

  String? _findDocContaining(String uid, int? slipNumber) {
    for (final d in _docs) {
      if (d.containsUid(uid)) return d.documentNo;
      if (slipNumber != null && d.containsSlip(slipNumber)) return d.documentNo;
    }
    return null;
  }

  Future<void> _promptUntoggleCash(String documentNo) async {
    final untoggle = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'CASH MODE',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('This tyre is on $documentNo — untoggle cash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP CASH'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('UNTOGGLE'),
          ),
        ],
      ),
    );
    if (untoggle == true && mounted) {
      setState(() => _cashArmed = false);
      AppHaptics.medium();
      _showBanner('Cash mode off — routing documents again', true);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TRUCK',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              _reg.isEmpty ? 'no REG set' : '$_reg · $_driver',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _stageCard(context),
          const SizedBox(height: 10),
          _cashCard(context),
          const SizedBox(height: 10),
          _scanCard(context),
          if (_banner != null) ...[
            const SizedBox(height: 10),
            _bannerCard(context),
          ],
          const SizedBox(height: 14),
          for (final doc in _docs) ...[
            _documentSection(context, doc),
            const SizedBox(height: 8),
          ],
          if (_docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 40,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No documents staged.\nPick a type and add the digits above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.dynamicTextMuted(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stageCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dynamicSurfaceRaised(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.dynamicBorder(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.post_add_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'STAGE DOCUMENTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // CC/BCC-style rows: pick the TYPE, type the DIGITS. Explicit
          // — no prefix guessing, no fat-finger errors.
          for (var i = 0; i < _docRows.length; i++) ...[
            _docRow(context, i),
            if (i < _docRows.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                AppHaptics.light();
                setState(() => _docRows.add(_DocRow()));
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('ADD DOCUMENT'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dynamicTextMuted(context),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (_recents.isNotEmpty && !_resolving) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final no in _recents)
                  GestureDetector(
                    onTap: () {
                      AppHaptics.light();
                      _stageDocuments(preset: no);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dynamicSurfaceSunk(context),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: AppColors.dynamicBorder(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 12,
                            color: AppColors.dynamicTextMuted(context),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            no,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: AppColors.dynamicTextPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _resolving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in _results.entries)
                            _resultChip(context, e.key, e.value),
                        ],
                      ),
              ),
              TextButton(
                onPressed: _resolving ? null : _stageDocuments,
                child: const Text('STAGE ALL'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _docRow(BuildContext context, int index) {
    final row = _docRows[index];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.dynamicSurfaceSunk(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.dynamicBorderLight(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final type in const [
                DocumentStream.inv,
                DocumentStream.dibt,
                DocumentStream.ibt,
                DocumentStream.amsInv,
              ]) ...[
                _typeChip(context, row, type),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              if (_docRows.length > 1)
                GestureDetector(
                  onTap: () {
                    AppHaptics.light();
                    setState(() {
                      _docRows.removeAt(index).controller.dispose();
                    });
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.controller,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 1,
              color: AppColors.dynamicTextPrimary(context),
            ),
            onSubmitted: (_) => _stageDocuments(),
            decoration: InputDecoration(
              prefixText: '${row.type.code} ',
              prefixStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: AppColors.dynamicTextMuted(context),
              ),
              hintText: 'digits only',
              hintStyle: TextStyle(
                fontSize: 12,
                color: AppColors.dynamicTextMuted(context),
              ),
              isDense: true,
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(
    BuildContext context,
    _DocRow row,
    DocumentStream type,
  ) {
    final selected = row.type == type;
    final color = selected
        ? AppColors.infoStrong(context)
        : AppColors.dynamicTextMuted(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        setState(() => row.type = type);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.infoStrong(context).withValues(alpha: 0.16)
              : AppColors.dynamicSurfaceRaised(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.infoStrong(context).withValues(alpha: 0.7)
                : AppColors.dynamicBorder(context),
          ),
        ),
        child: Text(
          type.code,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _resultChip(
    BuildContext context,
    String input,
    DocumentResolveResult r,
  ) {
    String customer = (r.document?.customerName ?? '').trim();
    if (customer.length > 18) customer = '${customer.substring(0, 18)}…';
    final (color, label) = switch (r.status) {
      DocumentResolveStatus.ok => (
          AppColors.successStrong(context),
          customer.isEmpty
              ? r.documentNo!
              : '${r.documentNo} · $customer',
        ),
      DocumentResolveStatus.duplicate => (
          AppColors.warningStrong(context),
          '${r.documentNo} dup'
        ),
      DocumentResolveStatus.notFound => (
          AppColors.errorStrong(context),
          '${r.documentNo} ?'
        ),
      DocumentResolveStatus.error => (
          AppColors.errorStrong(context),
          '${r.message ?? r.documentNo}'
        ),
      DocumentResolveStatus.unsupported => (
          AppColors.dynamicTextMuted(context),
          input
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _cashCard(BuildContext context) {
    final color = _cashArmed
        ? AppColors.warningStrong(context)
        : AppColors.dynamicTextMuted(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        setState(() => _cashArmed = !_cashArmed);
        _showBanner(
          _cashArmed ? 'CASH MODE — scanning cash sales' : 'Cash mode off',
          true,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: _cashArmed ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: _cashArmed ? 0.8 : 0.3),
            width: _cashArmed ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _cashArmed
                  ? Icons.attach_money_rounded
                  : Icons.attach_money_rounded,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _cashArmed
                    ? 'CASH MODE ARMED · $_cashCount today — tap to stop'
                    : 'CASH — tap to arm (accept-anything, rides the IBT)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _cashArmed ? color : AppColors.dynamicTextMuted(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanCard(BuildContext context) {
    final color = _scanArmed
        ? AppColors.successStrong(context)
        : AppColors.errorStrong(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dynamicSurfaceRaised(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _scanArmed
              ? color.withValues(alpha: 0.5)
              : AppColors.dynamicBorder(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.nfc_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCAN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: AppColors.dynamicTextPrimary(context),
                      ),
                    ),
                    Text(
                      _scanArmed
                          ? 'WAITING FOR TAG — hold the tyre to the reader'
                          : 'Scanner off',
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: _scanArmed ? _disarmScan : () => _armScan(),
                  child: Text(_scanArmed ? 'Stop' : 'Arm'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _slipController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'TYPE SLIP NUMBER — NO TAG?',
                    hintStyle: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.dynamicTextMuted(context),
                      letterSpacing: 0.6,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _submitManualSlip(),
                ),
              ),
              TextButton(
                onPressed: _scanBusy ? null : _submitManualSlip,
                child: const Text('SCAN'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerCard(BuildContext context) {
    final color = _bannerOk
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
            _bannerOk ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _banner!,
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

  Widget _documentSection(BuildContext context, StagedDocument doc) {
    final open = _openSections.contains(doc.documentNo);
    final color = doc.isIbt
        ? AppColors.infoStrong(context)
        : AppColors.successStrong(context);
    final loaded = doc.isIbt ? doc.loadedTotal : doc.loadedCount;
    final total = doc.isIbt ? doc.total : doc.total ?? doc.slips.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dynamicSurfaceRaised(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dynamicBorder(context)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              AppHaptics.light();
              setState(() {
                if (open) {
                  _openSections.remove(doc.documentNo);
                } else {
                  _openSections.add(doc.documentNo);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.documentNo,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dynamicTextPrimary(context),
                          ),
                        ),
                        if (doc.customerName != null &&
                            doc.customerName!.trim().isNotEmpty)
                          Text(
                            doc.customerName!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dynamicTextMuted(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '$loaded/${total ?? '?'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.dynamicTextMuted(context),
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: doc.isIbt
                  ? _ibtLines(context, doc)
                  : _slipBlocks(context, doc),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ibtLines(BuildContext context, StagedDocument doc) {
    return Column(
      children: [
        for (final line in doc.lineItems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    line.description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dynamicTextPrimary(context),
                    ),
                  ),
                ),
                Text(
                  '${line.loadedQuantity}/${line.targetTotal}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: line.isComplete
                        ? AppColors.successStrong(context)
                        : AppColors.dynamicTextMuted(context),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _slipBlocks(BuildContext context, StagedDocument doc) {
    final filter = (_filters[doc.documentNo] ?? '').trim().toLowerCase();
    final slips = [
      for (final s in doc.slips)
        if (filter.isEmpty ||
            s.slipNumber.toString().contains(filter) ||
            (s.serial ?? '').toLowerCase().contains(filter) ||
            (s.pattern ?? '').toLowerCase().contains(filter) ||
            (s.make ?? '').toLowerCase().contains(filter))
          s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _filters[doc.documentNo] = v),
          decoration: InputDecoration(
            hintText: 'Search slip / serial…',
            hintStyle: TextStyle(
              fontSize: 12,
              color: AppColors.dynamicTextMuted(context),
            ),
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 16),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 8),
        if (slips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'No tyres match',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.dynamicTextMuted(context),
              ),
            ),
          )
        else
          TyreBlockGrid(
            blocks: [
              for (final s in slips)
                TyreBlock(tyre: s, scanned: s.isLoaded),
            ],
          ),
      ],
    );
  }
}

/// One CC/BCC-style document row: a TYPE + a digits-only controller.
class _DocRow {
  _DocRow();

  DocumentStream type = DocumentStream.inv;
  final TextEditingController controller = TextEditingController();
}
