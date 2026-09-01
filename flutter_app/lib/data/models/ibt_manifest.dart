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
    };
  }

  factory IbtLineItem.fromMap(Map<String, dynamic> map) {
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
