import 'dart:convert';

import '../../dispatch/domain/document_number.dart';
import '../../dispatch/models/slip_tyre.dart';
import 'ibt_manifest.dart';

/// A document staged on a truck (entry) — the multi-document hub's unit.
///
/// Mirrors the reference app's `StagedDocument`: the manifest (slips for
/// INV/DIBT/AMS, line items for IBT) is cached as JSON in SQLite so the
/// truck restores offline and scans resolve against LOCAL data first
/// (D15). `loaded`/`previous_reg`/`scan_time` on each slip is what makes
/// pre-scanned tyres render green (D10).
class StagedDocument {
  const StagedDocument({
    required this.id,
    required this.entryId,
    required this.stream,
    required this.documentNo,
    this.customerName,
    this.customerCode,
    this.total,
    this.slips = const [],
    this.lineItems = const [],
    required this.cachedAt,
  });

  /// `entryId:stream:documentNo` — deterministic, so a save is an upsert
  /// of the same logical document.
  final String id;
  final String entryId;
  final DocumentStream stream;
  final String documentNo;
  final String? customerName;
  final String? customerCode;
  final int? total;
  final List<SlipTyre> slips;
  final List<IbtLineItem> lineItems;
  final int cachedAt;

  bool get isIbt => stream == DocumentStream.ibt;

  /// Tyres already loaded (green blocks on open — D10).
  int get loadedCount => slips.where((s) => s.isLoaded).length;

  /// IBT lines' loaded total (IBT docs have no slip list).
  int get loadedTotal =>
      lineItems.fold(0, (sum, l) => sum + l.loadedQuantity);

  bool containsUid(String uid) => slips.any((s) => s.uid == uid);

  bool containsSlip(int slipNumber) =>
      slips.any((s) => s.slipNumber == slipNumber);

  StagedDocument copyWith({
    String? id,
    String? entryId,
    DocumentStream? stream,
    String? documentNo,
    String? customerName,
    String? customerCode,
    int? total,
    List<SlipTyre>? slips,
    List<IbtLineItem>? lineItems,
    int? cachedAt,
  }) {
    return StagedDocument(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      stream: stream ?? this.stream,
      documentNo: documentNo ?? this.documentNo,
      customerName: customerName ?? this.customerName,
      customerCode: customerCode ?? this.customerCode,
      total: total ?? this.total,
      slips: slips ?? this.slips,
      lineItems: lineItems ?? this.lineItems,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'stream': stream.name,
    'documentNo': documentNo,
    'customerName': customerName,
    'customerCode': customerCode,
    'total': total,
    'slips': slips.map((s) => s.toJson()).toList(),
    'lineItems': lineItems.map((l) => l.toMap()).toList(),
  };

  /// Rebuild from a SQLite row: identity columns come from the row, the
  /// manifest from the JSON blob.
  static StagedDocument fromJson({
    required String id,
    required String entryId,
    required int cachedAt,
    required Map<String, dynamic> json,
  }) {
    return StagedDocument(
      id: id,
      entryId: entryId,
      stream: DocumentStream.values.firstWhere(
        (s) => s.name == json['stream'],
        orElse: () => DocumentStream.inv,
      ),
      documentNo: json['documentNo'] as String? ?? '',
      customerName: json['customerName'] as String?,
      customerCode: json['customerCode'] as String?,
      total: json['total'] as int?,
      slips: (json['slips'] as List? ?? const [])
          .map((e) => SlipTyre.fromJson(e as Map<String, dynamic>))
          .toList(),
      lineItems: (json['lineItems'] as List? ?? const [])
          .map((e) => IbtLineItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      cachedAt: cachedAt,
    );
  }

  /// The manifest blob alone (what lands in the JSON column).
  String encodeManifest() => jsonEncode(toJson());
}
