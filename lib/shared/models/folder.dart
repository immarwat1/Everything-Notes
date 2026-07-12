class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.colorHex = 0xFF1565C0,
    this.icon = 'folder',
  });

  final String id;
  final String name;
  final String? parentId;
  final int colorHex;
  final String icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    int? colorHex,
    String? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      colorHex: colorHex ?? this.colorHex,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'color_hex': colorHex,
      'icon': icon,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Folder.fromMap(Map<String, Object?> map) {
    return Folder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      colorHex: map['color_hex'] as int? ?? 0xFF1565C0,
      icon: map['icon'] as String? ?? 'folder',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
