import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/file_utils.dart';
import '../database/app_database.dart';

class LibraryBackupResult {
  final String path;
  final int photoCount;
  final int missingPhotoCount;
  final int albumCount;

  const LibraryBackupResult({
    required this.path,
    required this.photoCount,
    required this.missingPhotoCount,
    required this.albumCount,
  });
}

class LibraryRestoreResult {
  final int photoCount;
  final int missingPhotoCount;
  final int albumCount;

  const LibraryRestoreResult({
    required this.photoCount,
    required this.missingPhotoCount,
    required this.albumCount,
  });
}

class InvalidLibraryBackupException implements Exception {
  final String message;

  const InvalidLibraryBackupException(this.message);

  @override
  String toString() => message;
}

class LibraryBackupService {
  static const MethodChannel _channel =
      MethodChannel('com.photostorer.photo_storer/archive');
  static const String _format = 'photo_storer_library_backup';
  static const int _formatVersion = 2;

  Future<LibraryBackupResult> exportAndShare() async {
    final db = await AppDatabase.database;
    final themes = await db.query('themes', orderBy: 'id');
    final photos = await db.query('photos', orderBy: 'id');
    final tags = await db.query('tags', orderBy: 'id');
    final photoCategories = await db.query('photo_categories');
    final photoTags = await db.query('photo_tags');
    final recentViews = await db.query('recent_views');
    final privateCredentials = await db.query('private_album_credentials');

    final entries = <Map<String, String>>[];
    final exportedThemes = <Map<String, Object?>>[];
    final exportedPhotos = <Map<String, Object?>>[];
    var missingPhotos = 0;

    for (final source in themes) {
      final row = Map<String, Object?>.from(source);
      final coverPath = row.remove('cover_image_path') as String?;
      if (coverPath != null &&
          coverPath.isNotEmpty &&
          await File(coverPath).exists()) {
        final entryName = 'covers/${row['id']}${_safeExtension(coverPath)}';
        row['backup_cover_file'] = entryName;
        entries.add({'sourcePath': coverPath, 'entryName': entryName});
      }
      exportedThemes.add(row);
    }

    for (final source in photos) {
      final row = Map<String, Object?>.from(source);
      final localPath = row.remove('local_path') as String? ?? '';
      if (localPath.isNotEmpty && await File(localPath).exists()) {
        final entryName = 'photos/${row['id']}${_safeExtension(localPath)}';
        row['backup_file'] = entryName;
        entries.add({'sourcePath': localPath, 'entryName': entryName});
      } else {
        missingPhotos++;
      }
      exportedPhotos.add(row);
    }

    final manifest = <String, Object?>{
      'format': _format,
      'format_version': _formatVersion,
      'database_version': AppConstants.dbVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'app_name': AppConstants.appName,
      'tables': {
        'themes': exportedThemes,
        'photos': exportedPhotos,
        'tags': tags,
        'photo_categories': photoCategories,
        'photo_tags': photoTags,
        'recent_views': recentViews,
        'private_album_credentials': privateCredentials,
      },
    };

    final temp = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final manifestFile = File(p.join(temp.path, 'manifest-$timestamp.json'));
    await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
    entries.insert(
      0,
      {'sourcePath': manifestFile.path, 'entryName': 'manifest.json'},
    );
    final outputPath = p.join(
      temp.path,
      '相册分类-完整备份-$timestamp.album.zip',
    );

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'createBackupZip',
        {'entries': entries, 'outputPath': outputPath},
      );
      final path = response?['path'] as String?;
      if (path == null || !await File(path).exists()) {
        throw const FileSystemException('完整备份包创建失败');
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/zip')],
          title: '导出相册分类完整备份',
          text: '相册分类完整备份包（包含照片和相册资料，请妥善保管）',
        ),
      );
      return LibraryBackupResult(
        path: path,
        photoCount: photos.length - missingPhotos,
        missingPhotoCount: missingPhotos,
        albumCount: themes.where((row) => row['is_system'] != 1).length,
      );
    } finally {
      await _deleteFileQuietly(manifestFile.path);
    }
  }

  Future<LibraryRestoreResult?> pickAndRestore() async {
    final pickedPath = await _channel.invokeMethod<String>('pickBackupZip');
    if (pickedPath == null) return null;

    final temp = await getTemporaryDirectory();
    final extractionDirectory = Directory(
      p.join(
        temp.path,
        'album-restore-${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await extractionDirectory.create(recursive: true);

    try {
      await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'extractBackupZip',
        {
          'inputPath': pickedPath,
          'outputDirectory': extractionDirectory.path,
        },
      );
      return await _restoreExtractedBackup(extractionDirectory);
    } finally {
      await _deleteFileQuietly(pickedPath);
      try {
        if (await extractionDirectory.exists()) {
          await extractionDirectory.delete(recursive: true);
        }
      } catch (_) {
        // Temporary cleanup is best-effort.
      }
    }
  }

  Future<LibraryRestoreResult> _restoreExtractedBackup(
    Directory extractionDirectory,
  ) async {
    final manifestFile =
        File(p.join(extractionDirectory.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw const InvalidLibraryBackupException('不是有效的相册分类完整备份包');
    }
    if (await manifestFile.length() > 10 * 1024 * 1024) {
      throw const InvalidLibraryBackupException('备份清单异常，文件过大');
    }

    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['format'] != _format) {
      throw const InvalidLibraryBackupException('备份格式不受支持');
    }
    final version = (decoded['format_version'] as num?)?.toInt();
    if (version == null || version < 1 || version > _formatVersion) {
      throw const InvalidLibraryBackupException('备份版本高于当前应用支持范围');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const InvalidLibraryBackupException('备份清单缺少相册数据');
    }

    final themes = _readRows(tables, 'themes');
    final photos = _readRows(tables, 'photos');
    final tags = _readRows(tables, 'tags');
    final photoCategories = _readRows(tables, 'photo_categories');
    final photoTags = _readRows(tables, 'photo_tags');
    final recentViews = _readRows(tables, 'recent_views');
    final privateCredentials =
        _readOptionalRows(tables, 'private_album_credentials');
    _validateReferences(
      themes: themes,
      photos: photos,
      tags: tags,
      photoCategories: photoCategories,
      photoTags: photoTags,
      recentViews: recentViews,
      privateCredentials: privateCredentials,
    );

    final appDirectory = await getApplicationDocumentsDirectory();
    final photosDirectory =
        p.join(appDirectory.path, AppConstants.photosDirName);
    final coversDirectory =
        p.join(appDirectory.path, AppConstants.coversDirName);
    await FileUtils.ensureDirectory(photosDirectory);
    await FileUtils.ensureDirectory(coversDirectory);

    final restoreToken = DateTime.now().millisecondsSinceEpoch;
    final createdFiles = <String>[];
    final restoredThemes = <Map<String, Object?>>[];
    final restoredPhotos = <Map<String, Object?>>[];
    var missingPhotos = 0;

    try {
      for (final source in themes) {
        final row = _selectColumns(source, _themeColumns);
        final backupFile = source['backup_cover_file'] as String?;
        if (backupFile != null) {
          final file = _resolveBackupFile(extractionDirectory, backupFile);
          if (await file.exists()) {
            final destination = p.join(
              coversDirectory,
              'restore-$restoreToken-${row['id']}${_safeExtension(file.path)}',
            );
            await file.copy(destination);
            createdFiles.add(destination);
            row['cover_image_path'] = destination;
          } else {
            row['cover_image_path'] = null;
          }
        } else {
          row['cover_image_path'] = null;
        }
        restoredThemes.add(row);
      }

      for (final source in photos) {
        final row = _selectColumns(source, _photoColumns);
        final backupFile = source['backup_file'] as String?;
        if (backupFile != null) {
          final file = _resolveBackupFile(extractionDirectory, backupFile);
          if (await file.exists()) {
            final destination = p.join(
              photosDirectory,
              'restore-$restoreToken-${row['id']}${_safeExtension(file.path)}',
            );
            await file.copy(destination);
            createdFiles.add(destination);
            row['local_path'] = destination;
            row['is_available'] = 1;
            row['unavailable_reason'] = null;
          } else {
            _markMissingPhoto(row);
            missingPhotos++;
          }
        } else {
          _markMissingPhoto(row);
          missingPhotos++;
        }
        row['media_id'] = null;
        row['media_uri'] = null;
        restoredPhotos.add(row);
      }

      final db = await AppDatabase.database;
      final oldPhotoPaths = (await db.query('photos', columns: ['local_path']))
          .map((row) => row['local_path'] as String?)
          .whereType<String>()
          .toList();
      final oldCoverPaths =
          (await db.query('themes', columns: ['cover_image_path']))
              .map((row) => row['cover_image_path'] as String?)
              .whereType<String>()
              .toList();

      await db.transaction((txn) async {
        await txn.delete('private_album_credentials');
        await txn.delete('recent_views');
        await txn.delete('photo_tags');
        await txn.delete('photo_categories');
        await txn.delete('photos');
        await txn.delete('tags');
        await txn.delete('themes');

        final rootThemes =
            restoredThemes.where((row) => row['parent_id'] == null);
        final childThemes =
            restoredThemes.where((row) => row['parent_id'] != null);
        for (final row in [...rootThemes, ...childThemes]) {
          await txn.insert('themes', row);
        }
        for (final row in privateCredentials) {
          await txn.insert(
            'private_album_credentials',
            _selectColumns(row, _privateCredentialColumns),
          );
        }
        for (final row in restoredPhotos) {
          await txn.insert('photos', row);
        }
        for (final row in tags) {
          await txn.insert('tags', _selectColumns(row, _tagColumns));
        }
        for (final row in photoCategories) {
          await txn.insert(
            'photo_categories',
            _selectColumns(row, _photoCategoryColumns),
          );
        }
        for (final row in photoTags) {
          await txn.insert(
            'photo_tags',
            _selectColumns(row, _photoTagColumns),
          );
        }
        for (final row in recentViews.take(AppConstants.recentViewsLimit)) {
          await txn.insert(
            'recent_views',
            _selectColumns(row, _recentViewColumns),
          );
        }
      });

      final newFiles = createdFiles.toSet();
      for (final path in [...oldPhotoPaths, ...oldCoverPaths]) {
        if (!newFiles.contains(path) &&
            (_isWithin(photosDirectory, path) ||
                _isWithin(coversDirectory, path))) {
          await _deleteFileQuietly(path);
        }
      }

      return LibraryRestoreResult(
        photoCount: restoredPhotos.length - missingPhotos,
        missingPhotoCount: missingPhotos,
        albumCount: restoredThemes.where((row) => row['is_system'] != 1).length,
      );
    } catch (_) {
      for (final path in createdFiles) {
        await _deleteFileQuietly(path);
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _readRows(
    Map<String, dynamic> tables,
    String name,
  ) {
    final value = tables[name];
    if (value is! List) {
      throw InvalidLibraryBackupException('备份缺少数据表：$name');
    }
    return value.map((row) {
      if (row is! Map) {
        throw const InvalidLibraryBackupException('备份数据结构损坏');
      }
      return row.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  List<Map<String, dynamic>> _readOptionalRows(
    Map<String, dynamic> tables,
    String name,
  ) {
    if (!tables.containsKey(name)) return const [];
    return _readRows(tables, name);
  }

  void _validateReferences({
    required List<Map<String, dynamic>> themes,
    required List<Map<String, dynamic>> photos,
    required List<Map<String, dynamic>> tags,
    required List<Map<String, dynamic>> photoCategories,
    required List<Map<String, dynamic>> photoTags,
    required List<Map<String, dynamic>> recentViews,
    required List<Map<String, dynamic>> privateCredentials,
  }) {
    final themeIds = _uniqueIds(themes, '相册');
    final photoIds = _uniqueIds(photos, '照片');
    final tagIds = _uniqueIds(tags, '标签');
    if (!themes.any((row) => row['is_system'] == 1)) {
      throw const InvalidLibraryBackupException('备份缺少必要的系统相册');
    }
    for (final theme in themes) {
      final parentId = _optionalInt(theme['parent_id']);
      if (parentId != null && !themeIds.contains(parentId)) {
        throw const InvalidLibraryBackupException('备份包含无效的子相册关系');
      }
    }
    for (final photo in photos) {
      final themeId = _requiredInt(photo['theme_id']);
      if (!themeIds.contains(themeId)) {
        throw const InvalidLibraryBackupException('备份中的照片缺少所属相册');
      }
    }
    for (final row in photoCategories) {
      if (!photoIds.contains(_requiredInt(row['photo_id'])) ||
          !themeIds.contains(_requiredInt(row['category_id']))) {
        throw const InvalidLibraryBackupException('备份包含无效的照片分类关系');
      }
    }
    for (final row in photoTags) {
      if (!photoIds.contains(_requiredInt(row['photo_id'])) ||
          !tagIds.contains(_requiredInt(row['tag_id']))) {
        throw const InvalidLibraryBackupException('备份包含无效的照片标签关系');
      }
    }
    for (final row in recentViews) {
      if (!photoIds.contains(_requiredInt(row['photo_id']))) {
        throw const InvalidLibraryBackupException('备份包含无效的最近浏览记录');
      }
    }
    for (final row in privateCredentials) {
      final rootId = _requiredInt(row['root_theme_id']);
      if (!themeIds.contains(rootId)) {
        throw const InvalidLibraryBackupException('备份包含无效的私密相册密码关系');
      }
    }
  }

  Set<int> _uniqueIds(List<Map<String, dynamic>> rows, String label) {
    final ids = <int>{};
    for (final row in rows) {
      final id = _requiredInt(row['id']);
      if (!ids.add(id)) {
        throw InvalidLibraryBackupException('备份中存在重复$label编号');
      }
    }
    return ids;
  }

  int _requiredInt(Object? value) {
    if (value is num) return value.toInt();
    throw const InvalidLibraryBackupException('备份字段类型错误');
  }

  int? _optionalInt(Object? value) =>
      value == null ? null : _requiredInt(value);

  Map<String, Object?> _selectColumns(
    Map<String, dynamic> source,
    List<String> columns,
  ) {
    return {
      for (final column in columns)
        column: source[column] ??
            switch (column) {
              'sort_order' || 'is_private' => 0,
              _ => null,
            },
    };
  }

  File _resolveBackupFile(Directory root, String relativePath) {
    final normalizedRoot = p.normalize(root.absolute.path);
    final resolved = p.normalize(p.join(normalizedRoot, relativePath));
    if (!p.isWithin(normalizedRoot, resolved)) {
      throw const InvalidLibraryBackupException('备份包含不安全文件路径');
    }
    return File(resolved);
  }

  void _markMissingPhoto(Map<String, Object?> row) {
    row['local_path'] = '';
    row['is_available'] = 0;
    row['unavailable_reason'] = '备份中未包含此照片文件';
  }

  String _safeExtension(String path) {
    final extension = p.extension(path).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension) ? extension : '';
  }

  bool _isWithin(String root, String candidate) {
    if (candidate.isEmpty) return false;
    final normalizedRoot = p.normalize(p.absolute(root));
    final normalizedCandidate = p.normalize(p.absolute(candidate));
    return p.isWithin(normalizedRoot, normalizedCandidate);
  }

  Future<void> _deleteFileQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cleanup is best-effort.
    }
  }

  static const _themeColumns = <String>[
    'id',
    'name',
    'description',
    'cover_photo_id',
    'cover_image_path',
    'created_at',
    'is_system',
    'parent_id',
    'color_value',
    'icon_key',
    'sort_order',
    'is_private',
  ];
  static const _photoColumns = <String>[
    'id',
    'theme_id',
    'local_path',
    'original_name',
    'taken_at',
    'imported_at',
    'media_id',
    'media_uri',
    'mime_type',
    'width',
    'height',
    'is_favorite',
    'is_available',
    'last_seen_at',
    'source_type',
    'content_modified_at',
    'unavailable_reason',
    'story_text',
    'story_updated_at',
    'is_private',
  ];
  static const _tagColumns = <String>[
    'id',
    'name',
    'color_value',
    'created_at',
  ];
  static const _photoCategoryColumns = <String>[
    'photo_id',
    'category_id',
    'created_at',
  ];
  static const _photoTagColumns = <String>[
    'photo_id',
    'tag_id',
    'created_at',
  ];
  static const _recentViewColumns = <String>['photo_id', 'viewed_at'];
  static const _privateCredentialColumns = <String>[
    'root_theme_id',
    'password_salt',
    'password_hash',
    'created_at',
    'updated_at',
  ];
}
