class NoteBlock {
  final String id;
  final String text;
  final int createdAt;

  const NoteBlock({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  NoteBlock copyWith({
    String? id,
    String? text,
    int? createdAt,
  }) {
    return NoteBlock(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt,
    };
  }

  factory NoteBlock.fromMap(Map<String, dynamic> map) {
    return NoteBlock(
      id: map['id'] as String,
      text: map['text'] as String? ?? '',
      createdAt: map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
