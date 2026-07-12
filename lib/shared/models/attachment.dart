class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.noteId,
    required this.name,
    required this.path,
    required this.mimeType,
    required this.createdAt,
    this.bytes = 0,
  });

  final String id;
  final String noteId;
  final String name;
  final String path;
  final String mimeType;
  final int bytes;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'note_id': noteId,
      'name': name,
      'path': path,
      'mime_type': mimeType,
      'bytes': bytes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory NoteAttachment.fromMap(Map<String, Object?> map) {
    return NoteAttachment(
      id: map['id'] as String,
      noteId: map['note_id'] as String,
      name: map['name'] as String,
      path: map['path'] as String,
      mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
      bytes: map['bytes'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
