import 'preset.dart';
import 'ibt_manifest.dart';

class LoadingSheetTrip {
  final String id;
  final String? entryId;
  final String reg;
  final String driverName;
  final String tripId;
  final PresetKey? presetKey;
  final int? startTime;
  final int? finishTime;
  final int? durationMinutes;
  final int quantityLoaded;
  final int? targetQuantity;
  final int? rejectedCount;
  final String? note;
  final bool isManual;
  final int createdAt;
  final List<IbtDocument>? ibtDocuments;

  const LoadingSheetTrip({
    required this.id,
    this.entryId,
    required this.reg,
    required this.driverName,
    required this.tripId,
    this.presetKey,
    this.startTime,
    this.finishTime,
    this.durationMinutes,
    required this.quantityLoaded,
    this.targetQuantity,
    this.rejectedCount,
    this.note,
    this.isManual = false,
    required this.createdAt,
    this.ibtDocuments,
  });

  bool get hasIbtDocuments => ibtDocuments != null && ibtDocuments!.isNotEmpty;

  int get ibtTargetTotal =>
      ibtDocuments?.fold<int>(0, (sum, doc) => sum + doc.total) ?? 0;

  int get ibtLoadedTotal =>
      ibtDocuments?.fold<int>(0, (sum, doc) => sum + doc.loadedTotal) ?? 0;

  int get remainingTyres {
    final effectiveTarget = (targetQuantity != null && targetQuantity! > 0)
        ? targetQuantity!
        : (hasIbtDocuments ? ibtTargetTotal : 0);
    if (effectiveTarget <= 0) return 0;
    final diff = effectiveTarget - quantityLoaded;
    return diff > 0 ? diff : 0;
  }

  int get overCount {
    final effectiveTarget = (targetQuantity != null && targetQuantity! > 0)
        ? targetQuantity!
        : (hasIbtDocuments ? ibtTargetTotal : 0);
    if (effectiveTarget <= 0) return 0;
    final diff = quantityLoaded - effectiveTarget;
    return diff > 0 ? diff : 0;
  }

  double? get progressPercent {
    final effectiveTarget = (targetQuantity != null && targetQuantity! > 0)
        ? targetQuantity!
        : (hasIbtDocuments ? ibtTargetTotal : 0);
    if (effectiveTarget <= 0) return null;
    return (quantityLoaded / effectiveTarget).clamp(0.0, 1.0);
  }

  bool get isTargetReached {
    final effectiveTarget = (targetQuantity != null && targetQuantity! > 0)
        ? targetQuantity!
        : (hasIbtDocuments ? ibtTargetTotal : 0);
    return effectiveTarget > 0 && quantityLoaded >= effectiveTarget;
  }

  bool get isTargetExceeded {
    final effectiveTarget = (targetQuantity != null && targetQuantity! > 0)
        ? targetQuantity!
        : (hasIbtDocuments ? ibtTargetTotal : 0);
    return effectiveTarget > 0 && quantityLoaded > effectiveTarget;
  }

  LoadingSheetTrip copyWith({
    String? id,
    String? entryId,
    String? reg,
    String? driverName,
    String? tripId,
    PresetKey? presetKey,
    int? startTime,
    int? finishTime,
    int? durationMinutes,
    int? quantityLoaded,
    int? targetQuantity,
    int? rejectedCount,
    String? note,
    bool? isManual,
    int? createdAt,
    List<IbtDocument>? ibtDocuments,
  }) {
    return LoadingSheetTrip(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      reg: reg ?? this.reg,
      driverName: driverName ?? this.driverName,
      tripId: tripId ?? this.tripId,
      presetKey: presetKey ?? this.presetKey,
      startTime: startTime ?? this.startTime,
      finishTime: finishTime ?? this.finishTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      quantityLoaded: quantityLoaded ?? this.quantityLoaded,
      targetQuantity: targetQuantity ?? this.targetQuantity,
      rejectedCount: rejectedCount ?? this.rejectedCount,
      note: note ?? this.note,
      isManual: isManual ?? this.isManual,
      createdAt: createdAt ?? this.createdAt,
      ibtDocuments: ibtDocuments ?? this.ibtDocuments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entryId': entryId,
      'reg': reg,
      'driverName': driverName,
      'tripId': tripId,
      'presetKey': presetKey?.name,
      'startTime': startTime,
      'finishTime': finishTime,
      'durationMinutes': durationMinutes,
      'quantityLoaded': quantityLoaded,
      'targetQuantity': targetQuantity,
      'rejectedCount': rejectedCount,
      'note': note,
      'isManual': isManual ? 1 : 0,
      'createdAt': createdAt,
      'ibtDocuments': ibtDocuments?.map((e) => e.toMap()).toList(),
    };
  }

  factory LoadingSheetTrip.fromMap(Map<String, dynamic> map) {
    PresetKey? preset;
    if (map['presetKey'] != null) {
      preset = PresetKey.values.firstWhere(
        (p) => p.name == map['presetKey'],
        orElse: () => PresetKey.CUSTOM,
      );
    }

    List<IbtDocument>? ibts;
    if (map['ibtDocuments'] != null) {
      final rawList = map['ibtDocuments'] as List<dynamic>;
      ibts = rawList
          .map((e) => IbtDocument.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return LoadingSheetTrip(
      id: map['id']?.toString() ?? '',
      entryId: map['entryId']?.toString(),
      reg: map['reg']?.toString() ?? '',
      driverName: map['driverName']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      presetKey: preset,
      startTime: (map['startTime'] as num?)?.toInt(),
      finishTime: (map['finishTime'] as num?)?.toInt(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
      quantityLoaded: (map['quantityLoaded'] as num?)?.toInt() ?? 0,
      targetQuantity: (map['targetQuantity'] as num?)?.toInt(),
      rejectedCount: (map['rejectedCount'] as num?)?.toInt(),
      note: map['note']?.toString(),
      isManual: map['isManual'] == 1 || map['isManual'] == true,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      ibtDocuments: ibts,
    );
  }
}
