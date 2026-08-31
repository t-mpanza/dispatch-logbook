class Trip {
  final String id;
  final String? label;
  final int count;
  final int? rejected;
  final String? note;
  final int createdAt;

  const Trip({
    required this.id,
    this.label,
    required this.count,
    this.rejected,
    this.note,
    required this.createdAt,
  });

  Trip copyWith({
    String? id,
    String? label,
    int? count,
    int? rejected,
    String? note,
    int? createdAt,
  }) {
    return Trip(
      id: id ?? this.id,
      label: label ?? this.label,
      count: count ?? this.count,
      rejected: rejected ?? this.rejected,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'count': count,
      'rejected': rejected,
      'note': note,
      'createdAt': createdAt,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as String,
      label: map['label'] as String?,
      count: (map['count'] as num?)?.toInt() ?? 0,
      rejected: (map['rejected'] as num?)?.toInt(),
      note: map['note'] as String?,
      createdAt: map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
