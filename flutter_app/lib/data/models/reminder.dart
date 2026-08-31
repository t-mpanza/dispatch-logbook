class Reminder {
  final String id;
  final String entryId;
  final int at; // epoch ms
  final String text;
  final bool done;

  const Reminder({
    required this.id,
    required this.entryId,
    required this.at,
    required this.text,
    this.done = false,
  });

  Reminder copyWith({
    String? id,
    String? entryId,
    int? at,
    String? text,
    bool? done,
  }) {
    return Reminder(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      at: at ?? this.at,
      text: text ?? this.text,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entryId': entryId,
      'at': at,
      'text': text,
      'done': done ? 1 : 0,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      entryId: map['entryId'] as String,
      at: (map['at'] as num).toInt(),
      text: map['text'] as String,
      done: map['done'] == 1 || map['done'] == true,
    );
  }
}
