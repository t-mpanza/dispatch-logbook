import 'preset.dart';

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
  });

  int get remainingTyres {
    if (targetQuantity == null || targetQuantity! <= 0) return 0;
    final diff = targetQuantity! - quantityLoaded;
    return diff > 0 ? diff : 0;
  }

  int get overCount {
    if (targetQuantity == null || targetQuantity! <= 0) return 0;
    final diff = quantityLoaded - targetQuantity!;
    return diff > 0 ? diff : 0;
  }

  double? get progressPercent {
    if (targetQuantity == null || targetQuantity! <= 0) return null;
    return (quantityLoaded / targetQuantity!).clamp(0.0, 1.0);
  }

  bool get isTargetReached =>
      targetQuantity != null && targetQuantity! > 0 && quantityLoaded >= targetQuantity!;

  bool get isTargetExceeded =>
      targetQuantity != null && targetQuantity! > 0 && quantityLoaded > targetQuantity!;

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

    return LoadingSheetTrip(
      id: map['id'] as String,
      entryId: map['entryId'] as String?,
      reg: (map['reg'] as String? ?? '').toUpperCase(),
      driverName: map['driverName'] as String? ?? '',
      tripId: map['tripId'] as String? ?? '',
      presetKey: preset,
      startTime: (map['startTime'] as num?)?.toInt(),
      finishTime: (map['finishTime'] as num?)?.toInt(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
      quantityLoaded: (map['quantityLoaded'] as num?)?.toInt() ?? 0,
      targetQuantity: (map['targetQuantity'] as num?)?.toInt(),
      rejectedCount: (map['rejectedCount'] as num?)?.toInt(),
      note: map['note'] as String?,
      isManual: map['isManual'] == 1 || map['isManual'] == true,
      createdAt: map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
