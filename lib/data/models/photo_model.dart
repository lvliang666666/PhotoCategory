enum PhotoSourceType { imported, appGenerated }

extension PhotoSourceTypeValue on PhotoSourceType {
  String get dbValue => switch (this) {
        PhotoSourceType.imported => 'imported',
        PhotoSourceType.appGenerated => 'app_generated',
      };

  static PhotoSourceType fromDb(String? value) => switch (value) {
        'app_generated' => PhotoSourceType.appGenerated,
        _ => PhotoSourceType.imported,
      };
}

class PhotoModel {
  final int? id;
  final int themeId;
  final String localPath;
  final String? originalName;
  final int? takenAt;
  final int importedAt;
  final String? mediaId;
  final String? mediaUri;
  final String? mimeType;
  final int? width;
  final int? height;
  final bool isFavorite;
  final bool isAvailable;
  final int? lastSeenAt;
  final PhotoSourceType sourceType;
  final int? contentModifiedAt;
  final String? unavailableReason;
  final String? storyText;
  final int? storyUpdatedAt;
  final bool isPrivate;

  const PhotoModel({
    this.id,
    required this.themeId,
    required this.localPath,
    this.originalName,
    this.takenAt,
    required this.importedAt,
    this.mediaId,
    this.mediaUri,
    this.mimeType,
    this.width,
    this.height,
    this.isFavorite = false,
    this.isAvailable = true,
    this.lastSeenAt,
    this.sourceType = PhotoSourceType.imported,
    this.contentModifiedAt,
    this.unavailableReason,
    this.storyText,
    this.storyUpdatedAt,
    this.isPrivate = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'theme_id': themeId,
      'local_path': localPath,
      'original_name': originalName,
      'taken_at': takenAt,
      'imported_at': importedAt,
      'media_id': mediaId,
      'media_uri': mediaUri,
      'mime_type': mimeType,
      'width': width,
      'height': height,
      'is_favorite': isFavorite ? 1 : 0,
      'is_available': isAvailable ? 1 : 0,
      'last_seen_at': lastSeenAt,
      'source_type': sourceType.dbValue,
      'content_modified_at': contentModifiedAt,
      'unavailable_reason': unavailableReason,
      'story_text': storyText,
      'story_updated_at': storyUpdatedAt,
      'is_private': isPrivate ? 1 : 0,
    };
  }

  factory PhotoModel.fromMap(Map<String, dynamic> map) {
    return PhotoModel(
      id: map['id'] as int?,
      themeId: map['theme_id'] as int,
      localPath: map['local_path'] as String,
      originalName: map['original_name'] as String?,
      takenAt: map['taken_at'] as int?,
      importedAt: map['imported_at'] as int,
      mediaId: map['media_id'] as String?,
      mediaUri: map['media_uri'] as String?,
      mimeType: map['mime_type'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      isFavorite: ((map['is_favorite'] as int?) ?? 0) == 1,
      isAvailable: ((map['is_available'] as int?) ?? 1) == 1,
      lastSeenAt: map['last_seen_at'] as int?,
      sourceType: PhotoSourceTypeValue.fromDb(map['source_type'] as String?),
      contentModifiedAt: map['content_modified_at'] as int?,
      unavailableReason: map['unavailable_reason'] as String?,
      storyText: map['story_text'] as String?,
      storyUpdatedAt: map['story_updated_at'] as int?,
      isPrivate: ((map['is_private'] as int?) ?? 0) == 1,
    );
  }

  PhotoModel copyWith({
    int? id,
    int? themeId,
    String? localPath,
    String? originalName,
    int? takenAt,
    bool? clearTakenAt,
    int? importedAt,
    String? mediaId,
    String? mediaUri,
    String? mimeType,
    int? width,
    int? height,
    bool? isFavorite,
    bool? isAvailable,
    int? lastSeenAt,
    PhotoSourceType? sourceType,
    int? contentModifiedAt,
    String? unavailableReason,
    String? storyText,
    bool clearStoryText = false,
    int? storyUpdatedAt,
    bool clearStoryUpdatedAt = false,
    bool? isPrivate,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      themeId: themeId ?? this.themeId,
      localPath: localPath ?? this.localPath,
      originalName: originalName ?? this.originalName,
      takenAt: clearTakenAt == true ? null : (takenAt ?? this.takenAt),
      importedAt: importedAt ?? this.importedAt,
      mediaId: mediaId ?? this.mediaId,
      mediaUri: mediaUri ?? this.mediaUri,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      isFavorite: isFavorite ?? this.isFavorite,
      isAvailable: isAvailable ?? this.isAvailable,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      sourceType: sourceType ?? this.sourceType,
      contentModifiedAt: contentModifiedAt ?? this.contentModifiedAt,
      unavailableReason: unavailableReason ?? this.unavailableReason,
      storyText: clearStoryText ? null : (storyText ?? this.storyText),
      storyUpdatedAt:
          clearStoryUpdatedAt ? null : (storyUpdatedAt ?? this.storyUpdatedAt),
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  String get displayName => originalName?.trim().isNotEmpty == true
      ? originalName!
      : (mediaId ?? '照片');

  String get orientation {
    if (width == null || height == null) return 'unknown';
    if (width == height) return 'square';
    return width! > height! ? 'landscape' : 'portrait';
  }

  bool get hasStory => storyText?.trim().isNotEmpty == true;

  /// Stable across grids and the viewer so the already decoded thumbnail can
  /// remain visible during navigation instead of flashing a black frame.
  String get heroTag => 'photo-${id ?? localPath}';
}
