class ThemeModel {
  final int? id;
  final String name;
  final String description;
  final int? coverPhotoId;
  final String? coverImagePath;
  final int createdAt;
  final bool isSystem;
  final int? parentId;
  final int colorValue;
  final String iconKey;
  final int sortOrder;
  final bool isPrivate;
  final bool isVirtual;
  final String? virtualRules;

  const ThemeModel({
    this.id,
    required this.name,
    this.description = '',
    this.coverPhotoId,
    this.coverImagePath,
    required this.createdAt,
    this.isSystem = false,
    this.parentId,
    this.colorValue = 0xFF546E7A,
    this.iconKey = 'album',
    this.sortOrder = 0,
    this.isPrivate = false,
    this.isVirtual = false,
    this.virtualRules,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description.isEmpty ? null : description,
      'cover_photo_id': coverPhotoId,
      'cover_image_path': coverImagePath,
      'created_at': createdAt,
      'is_system': isSystem ? 1 : 0,
      'parent_id': parentId,
      'color_value': colorValue,
      'icon_key': iconKey,
      'sort_order': sortOrder,
      'is_private': isPrivate ? 1 : 0,
      'is_virtual': isVirtual ? 1 : 0,
      'virtual_rules': virtualRules,
    };
  }

  factory ThemeModel.fromMap(Map<String, dynamic> map) {
    return ThemeModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      coverPhotoId: map['cover_photo_id'] as int?,
      coverImagePath: map['cover_image_path'] as String?,
      createdAt: map['created_at'] as int,
      isSystem: (map['is_system'] as int) == 1,
      parentId: map['parent_id'] as int?,
      colorValue: (map['color_value'] as int?) ?? 0xFF546E7A,
      iconKey: (map['icon_key'] as String?) ?? 'album',
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isPrivate: ((map['is_private'] as int?) ?? 0) == 1,
      isVirtual: ((map['is_virtual'] as int?) ?? 0) == 1,
      virtualRules: map['virtual_rules'] as String?,
    );
  }

  ThemeModel copyWith({
    int? id,
    String? name,
    String? description,
    int? coverPhotoId,
    bool clearCover = false,
    String? coverImagePath,
    bool clearCoverImage = false,
    int? createdAt,
    bool? isSystem,
    int? parentId,
    bool clearParent = false,
    int? colorValue,
    String? iconKey,
    int? sortOrder,
    bool? isPrivate,
    bool? isVirtual,
    String? virtualRules,
    bool clearVirtualRules = false,
  }) {
    return ThemeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverPhotoId: clearCover ? null : (coverPhotoId ?? this.coverPhotoId),
      coverImagePath:
          clearCoverImage ? null : (coverImagePath ?? this.coverImagePath),
      createdAt: createdAt ?? this.createdAt,
      isSystem: isSystem ?? this.isSystem,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrivate: isPrivate ?? this.isPrivate,
      isVirtual: isVirtual ?? this.isVirtual,
      virtualRules:
          clearVirtualRules ? null : (virtualRules ?? this.virtualRules),
    );
  }

  bool get isSubAlbum => parentId != null;
}
