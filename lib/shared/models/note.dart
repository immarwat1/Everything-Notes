import 'package:everything_notes_offline/core/utils/document_metrics.dart';

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.tags = const [],
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.isTrashed = false,
  });

  final String id;
  final String title;
  final String content;
  final String? folderId;
  final List<String> tags;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final bool isTrashed;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentMetrics get metrics => DocumentMetrics.fromText(content);

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? folderId,
    List<String>? tags,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    bool? isTrashed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isTrashed: isTrashed ?? this.isTrashed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'folder_id': folderId,
      'tags': tags.join(','),
      'is_pinned': isPinned ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_trashed': isTrashed ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'folderId': folderId,
      'tags': tags,
      'isPinned': isPinned,
      'isFavorite': isFavorite,
      'isArchived': isArchived,
      'isTrashed': isTrashed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled',
      content: map['content'] as String? ?? '',
      folderId: map['folder_id'] as String?,
      tags: (map['tags'] as String? ?? '')
          .split(',')
          .where((tag) => tag.trim().isNotEmpty)
          .toList(),
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      isTrashed: (map['is_trashed'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  factory Note.fromJson(Map<String, Object?> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      content: json['content'] as String? ?? '',
      folderId: json['folderId'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      isPinned: json['isPinned'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      isTrashed: json['isTrashed'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
