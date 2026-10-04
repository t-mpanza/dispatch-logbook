/// One discrete change applied to a line item's loaded quantity.
///
/// Mirrors the global trip counter's event log, but scoped to a single IBT
/// line so operators can always answer: "what did I just add to this line?"
class IbtLineEvent {
  final String id;
  final int delta; // Signed change applied to loadedQuantity (e.g. +4, -2)
  final int at; // epoch ms

  const IbtLineEvent({required this.id, required this.delta, required this.at});

  IbtLineEvent copyWith({String? id, int? delta, int? at}) {
    return IbtLineEvent(
      id: id ?? this.id,
      delta: delta ?? this.delta,
      at: at ?? this.at,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'delta': delta, 'at': at};
  }

  factory IbtLineEvent.fromMap(Map<String, dynamic> map) {
    return IbtLineEvent(
      id: map['id']?.toString() ?? '',
      delta: (map['delta'] as num?)?.toInt() ?? 0,
      at: (map['at'] as num?)?.toInt() ?? 0,
    );
  }
}

class IbtLineItem {
  final String id;
  final String description;
  final String? rcsCode;
  final int? sizeId;
  final int? rubberId;
  final String? size;
  final String? rubber;
  final int targetTotal;
  final int loadedQuantity;

  /// Chronological log of every change applied to [loadedQuantity]
  /// (newest last). Lets the operator see exactly what was added — and undo
  /// mistaken taps — without guessing.
  final List<IbtLineEvent> history;

  const IbtLineItem({
    required this.id,
    required this.description,
    this.rcsCode,
    this.sizeId,
    this.rubberId,
    this.size,
    this.rubber,
    required this.targetTotal,
    this.loadedQuantity = 0,
    this.history = const [],
  });

  int get remaining => (targetTotal - loadedQuantity).clamp(0, targetTotal);
  int get overCount {
    if (loadedQuantity <= targetTotal) return 0;
    return loadedQuantity - targetTotal;
  }

  bool get isComplete => targetTotal > 0 && loadedQuantity >= targetTotal;
  bool get isShort => targetTotal > 0 && loadedQuantity < targetTotal;
  bool get isOverloaded => targetTotal > 0 && loadedQuantity > targetTotal;
  double get progressPercent =>
      targetTotal > 0 ? (loadedQuantity / targetTotal).clamp(0.0, 1.0) : 0.0;

  IbtLineEvent? get lastEvent =>
      history.isEmpty ? null : history[history.length - 1];

  IbtLineItem copyWith({
    String? id,
    String? description,
    String? rcsCode,
    int? sizeId,
    int? rubberId,
    String? size,
    String? rubber,
    int? targetTotal,
    int? loadedQuantity,
    List<IbtLineEvent>? history,
    bool clearHistory = false,
  }) {
    return IbtLineItem(
      id: id ?? this.id,
      description: description ?? this.description,
      rcsCode: rcsCode ?? this.rcsCode,
      sizeId: sizeId ?? this.sizeId,
      rubberId: rubberId ?? this.rubberId,
      size: size ?? this.size,
      rubber: rubber ?? this.rubber,
      targetTotal: targetTotal ?? this.targetTotal,
      loadedQuantity: loadedQuantity ?? this.loadedQuantity,
      history: clearHistory
          ? const []
          : (history ?? this.history),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'rcsCode': rcsCode,
      'sizeId': sizeId,
      'rubberId': rubberId,
      'size': size,
      'rubber': rubber,
      'targetTotal': targetTotal,
      'loadedQuantity': loadedQuantity,
      'history': history.map((e) => e.toMap()).toList(),
    };
  }

  factory IbtLineItem.fromMap(Map<String, dynamic> map) {
    final List<IbtLineEvent> parsedHistory = [];
    final rawHistory = map['history'];
    if (rawHistory is List) {
      for (final e in rawHistory) {
        if (e is Map) {
          parsedHistory.add(IbtLineEvent.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    return IbtLineItem(
      id: map['id']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      rcsCode: map['rcsCode']?.toString(),
      sizeId: map['sizeId'] as int?,
      rubberId: map['rubberId'] as int?,
      size: map['size']?.toString(),
      rubber: map['rubber']?.toString(),
      targetTotal: (map['targetTotal'] as num?)?.toInt() ?? 0,
      loadedQuantity: (map['loadedQuantity'] as num?)?.toInt() ?? 0,
      history: parsedHistory,
    );
  }
}

class IbtDocument {
  final String documentNo;
  final int total;
  final List<IbtLineItem> lineItems;

  const IbtDocument({
    required this.documentNo,
    required this.total,
    required this.lineItems,
  });

  int get loadedTotal =>
      lineItems.fold(0, (sum, item) => sum + item.loadedQuantity);
  int get remainingTotal => (total - loadedTotal).clamp(0, total);
  bool get isComplete => total > 0 && loadedTotal >= total;
  bool get hasShortages => lineItems.any((item) => item.isShort);

  IbtDocument copyWith({
    String? documentNo,
    int? total,
    List<IbtLineItem>? lineItems,
  }) {
    return IbtDocument(
      documentNo: documentNo ?? this.documentNo,
      total: total ?? this.total,
      lineItems: lineItems ?? this.lineItems,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentNo': documentNo,
      'total': total,
      'lineItems': lineItems.map((e) => e.toMap()).toList(),
    };
  }

  factory IbtDocument.fromMap(Map<String, dynamic> map) {
    final rawLines = map['lineItems'] as List<dynamic>? ?? [];
    return IbtDocument(
      documentNo: map['documentNo']?.toString() ?? '',
      total: (map['total'] as num?)?.toInt() ?? 0,
      lineItems: rawLines
          .map((e) => IbtLineItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
