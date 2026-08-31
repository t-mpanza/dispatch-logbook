import 'dart:typed_data';

enum AttachmentKind { audio, image, photo, video, file }

class Attachment {
  final String id;
  final AttachmentKind kind;
  final Uint8List? bytes;
  final String mime;
  final String? name;
  final String? caption;
  final int? durationMs;
  final int? width;
  final int? height;
  final String? storagePath;
  final String? downloadUrl;
  final String? localFilePath;
  final int createdAt;

  const Attachment({
    required this.id,
    required this.kind,
    this.bytes,
    required this.mime,
    this.name,
    this.caption,
    this.durationMs,
    this.width,
    this.height,
    this.storagePath,
    this.downloadUrl,
    this.localFilePath,
    required this.createdAt,
  });

  Attachment copyWith({
    String? id,
    AttachmentKind? kind,
    Uint8List? bytes,
    String? mime,
    String? name,
    String? caption,
    int? durationMs,
    int? width,
    int? height,
    String? storagePath,
    String? downloadUrl,
    String? localFilePath,
    int? createdAt,
  }) {
    return Attachment(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      bytes: bytes ?? this.bytes,
      mime: mime ?? this.mime,
      name: name ?? this.name,
      caption: caption ?? this.caption,
      durationMs: durationMs ?? this.durationMs,
      width: width ?? this.width,
      height: height ?? this.height,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kind': kind.name,
      'mime': mime,
      'name': name,
      'caption': caption,
      'durationMs': durationMs,
      'width': width,
      'height': height,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'localFilePath': localFilePath,
      'createdAt': createdAt,
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'] as String,
      kind: AttachmentKind.values.firstWhere(
        (k) => k.name == (map['kind'] as String? ?? 'file'),
        orElse: () => AttachmentKind.file,
      ),
      mime: map['mime'] as String? ?? 'application/octet-stream',
      name: map['name'] as String?,
      caption: map['caption'] as String?,
      durationMs: map['durationMs'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      storagePath: map['storagePath'] as String?,
      downloadUrl: map['downloadUrl'] as String?,
      localFilePath: map['localFilePath'] as String?,
      createdAt: map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
