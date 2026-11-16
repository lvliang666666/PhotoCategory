import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../database/app_database.dart';
import '../models/photo_filter.dart';
import '../models/photo_model.dart';

class BatchOperationResult {
  final int successCount;
  final int failCount;
  final List<int> failedPhotoIds;

  const BatchOperationResult({
    required this.successCount,
    required this.failCount,
    this.failedPhotoIds = const [],
  });
}

class PhotoRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<PhotoModel>> getPhotosByTheme(
    int themeId, {
    int limit = AppConstants.libraryPageSize,
    int offset = 0,
  }) async {
    final db = await _db;
    final themeRows = await db.query(
      'themes',
      columns: ['is_private'],
      where: 'id = ?',
      whereArgs: [themeId],
      limit: 1,
    );
    final includePrivate = themeRows.isNotEmpty &&
        ((themeRows.first['is_private'] as int?) ?? 0) == 1;
    return searchPhotos(
      PhotoFilter(categoryIds: {themeId}, includePrivate: includePrivate),
      limit: limit,
      offset: offset,
    );
  }

  Future<List<PhotoModel>> searchPhotos(
    PhotoFilter filter, {
    int limit = AppConstants.libraryPageSize,
    int offset = 0,
  }) async {
    final db = await _db;
    final (whereSql, args) = _buildFilter(filter);
    final rows = await db.rawQuery(
      'SELECT p.* FROM photos p $whereSql '
      'ORDER BY COALESCE(p.taken_at, p.imported_at) DESC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    return rows.map(PhotoModel.fromMap).toList();
  }

  Future<int> countPhotos(PhotoFilter filter) async {
    final db = await _db;
    final (whereSql, args) = _buildFilter(filter);
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM photos p $whereSql',
      args,
    );
    return rows.first['count'] as int? ?? 0;
  }

  (String, List<Object?>) _buildFilter(PhotoFilter filter) {
    final where = <String>[];
    final args = <Object?>[];
    if (!filter.includePrivate) {
      where.add('p.is_private = 0');
    }
    final query = filter.query.trim().toLowerCase();
    if (query.isNotEmpty) {
      where.add('LOWER(COALESCE(p.original_name, \'\')) LIKE ?');
      args.add('%$query%');
    }
    if (filter.favorite != null) {
      where.add('p.is_favorite = ?');
      args.add(filter.favorite! ? 1 : 0);
    }
    if (filter.startDate != null) {
      where.add('COALESCE(p.taken_at, p.imported_at) >= ?');
      args.add(filter.startDate!.millisecondsSinceEpoch ~/ 1000);
    }
    if (filter.endDate != null) {
      final endExclusive = DateTime(
        filter.endDate!.year,
        filter.endDate!.month,
        filter.endDate!.day + 1,
      );
      where.add('COALESCE(p.taken_at, p.imported_at) < ?');
      args.add(endExclusive.millisecondsSinceEpoch ~/ 1000);
    }
    if (filter.formats.isNotEmpty) {
      final clauses = <String>[];
      for (final format in filter.formats) {
        clauses.add(
          'LOWER(COALESCE(p.mime_type, p.original_name, \'\')) LIKE ?',
        );
        args.add('%${format.toLowerCase()}%');
      }
      where.add('(${clauses.join(' OR ')})');
    }
    if (filter.sourceTypes.isNotEmpty) {
      where.add(
        'p.source_type IN (${List.filled(filter.sourceTypes.length, '?').join(',')})',
      );
      args.addAll(filter.sourceTypes.map((source) => source.dbValue));
    }
    if (filter.orientation == 'landscape') {
      where.add('p.width > p.height');
    } else if (filter.orientation == 'portrait') {
      where.add('p.height > p.width');
    } else if (filter.orientation == 'square') {
      where.add('p.width = p.height AND p.width IS NOT NULL');
    }
    if (filter.onlyUnclassified) {
      where.add(
        'NOT EXISTS (SELECT 1 FROM photo_categories ux '
        'WHERE ux.photo_id = p.id AND ux.category_id NOT IN '
        '(SELECT id FROM themes WHERE is_system = 1))',
      );
    }
    for (final categoryId in filter.categoryIds) {
      where.add(
        'EXISTS (SELECT 1 FROM photo_categories pc '
        'WHERE pc.photo_id = p.id AND pc.category_id = ?)',
      );
      args.add(categoryId);
    }
    for (final tagId in filter.tagIds) {
      where.add(
        'EXISTS (SELECT 1 FROM photo_tags pt '
        'WHERE pt.photo_id = p.id AND pt.tag_id = ?)',
      );
      args.add(tagId);
    }

    return (where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}', args);
  }

  Future<List<PhotoModel>> getRecentViews({
    int limit = AppConstants.libraryPageSize,
    int offset = 0,
    Set<PhotoSourceType> sourceTypes = const {},
  }) async {
    final db = await _db;
    final sourceSql = sourceTypes.isEmpty
        ? 'WHERE p.is_private = 0'
        : 'WHERE p.is_private = 0 AND p.source_type IN (${List.filled(sourceTypes.length, '?').join(',')})';
    final rows = await db.rawQuery(
      'SELECT p.* FROM recent_views rv JOIN photos p ON p.id = rv.photo_id '
      '$sourceSql ORDER BY rv.viewed_at DESC LIMIT ? OFFSET ?',
      [...sourceTypes.map((source) => source.dbValue), limit, offset],
    );
    return rows.map(PhotoModel.fromMap).toList();
  }

  Future<int> countRecentViews({
    Set<PhotoSourceType> sourceTypes = const {},
  }) async {
    final db = await _db;
    final sourceSql = sourceTypes.isEmpty
        ? 'WHERE p.is_private = 0'
        : 'WHERE p.is_private = 0 AND p.source_type IN (${List.filled(sourceTypes.length, '?').join(',')})';
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM recent_views rv '
      'JOIN photos p ON p.id = rv.photo_id $sourceSql',
      sourceTypes.map((source) => source.dbValue).toList(),
    );
    return rows.first['count'] as int? ?? 0;
  }

  Future<List<PhotoModel>> getRecentlyAdded({
    int limit = AppConstants.libraryPageSize,
    int offset = 0,
    Set<PhotoSourceType> sourceTypes = const {},
  }) async {
    final db = await _db;
    final rows = await db.query(
      'photos',
      where: sourceTypes.isEmpty
          ? 'is_private = 0'
          : 'is_private = 0 AND source_type IN (${List.filled(sourceTypes.length, '?').join(',')})',
      whereArgs: sourceTypes.map((source) => source.dbValue).toList(),
      orderBy: 'imported_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(PhotoModel.fromMap).toList();
  }

  Future<PhotoModel?> getPhotoById(int id) async {
    final db = await _db;
    final rows =
        await db.query('photos', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : PhotoModel.fromMap(rows.first);
  }

  /// Returns the id of an existing photo with the same content hash, or null.
  /// Used by the import pipeline to skip duplicate files.
  Future<int?> getPhotoIdByContentHash(String hash) async {
    final db = await _db;
    final rows = await db.query(
      'photos',
      columns: ['id'],
      where: 'content_hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  /// Photos that still lack a content fingerprint (legacy imports).
  Future<List<PhotoModel>> getPhotosMissingHash({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'photos',
      where: 'content_hash IS NULL AND TRIM(local_path) != ?',
      whereArgs: [''],
      limit: limit,
    );
    return rows.map(PhotoModel.fromMap).toList();
  }

  Future<void> updateContentHash(int photoId, String hash) async {
    final db = await _db;
    await db.update(
      'photos',
      {'content_hash': hash},
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  Future<PhotoModel?> getLatestPhoto(int themeId) async {
    final photos = await searchPhotos(
      PhotoFilter(categoryIds: {themeId}),
      limit: 1,
    );
    return photos.isEmpty ? null : photos.first;
  }

  Future<PhotoModel> addPhoto(
    PhotoModel photo, {
    Iterable<int> additionalCategoryIds = const [],
  }) async {
    final db = await _db;
    final id = await db.transaction((txn) async {
      final themeRows = await txn.query(
        'themes',
        columns: ['is_private'],
        where: 'id = ?',
        whereArgs: [photo.themeId],
        limit: 1,
      );
      final isPrivate = themeRows.isNotEmpty &&
          ((themeRows.first['is_private'] as int?) ?? 0) == 1;
      final createdId = await txn.insert(
        'photos',
        {...photo.toMap(), 'is_private': isPrivate ? 1 : 0},
      );
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final categoryId in <int>{
        photo.themeId,
        ...additionalCategoryIds,
      }) {
        await txn.insert(
          'photo_categories',
          {
            'photo_id': createdId,
            'category_id': categoryId,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      return createdId;
    });
    final createdRows =
        await db.query('photos', where: 'id = ?', whereArgs: [id], limit: 1);
    final created = PhotoModel.fromMap(createdRows.single);
    return created;
  }

  Future<void> recordView(int photoId) async {
    final db = await _db;
    final photoRows = await db.query(
      'photos',
      columns: ['is_private'],
      where: 'id = ?',
      whereArgs: [photoId],
      limit: 1,
    );
    if (photoRows.isEmpty ||
        ((photoRows.first['is_private'] as int?) ?? 0) == 1) {
      return;
    }
    final maxRows = await db.rawQuery(
      'SELECT MAX(viewed_at) AS latest FROM recent_views',
    );
    final latest = maxRows.first['latest'] as int? ?? 0;
    final clock = DateTime.now().millisecondsSinceEpoch;
    final now = clock > latest ? clock : latest + 1;
    await db.insert(
      'recent_views',
      {'photo_id': photoId, 'viewed_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.rawDelete(
      'DELETE FROM recent_views WHERE photo_id NOT IN '
      '(SELECT photo_id FROM recent_views ORDER BY viewed_at DESC LIMIT ?)',
      [AppConstants.recentViewsLimit],
    );
  }

  Future<BatchOperationResult> setFavorite(List<int> photoIds, bool value) =>
      _updateMany(photoIds, {'is_favorite': value ? 1 : 0});

  Future<bool> updateStory(int photoId, String value) async {
    final db = await _db;
    final normalized = value.trim();
    final count = await db.update(
      'photos',
      {
        'story_text': normalized.isEmpty ? null : normalized,
        'story_updated_at': normalized.isEmpty
            ? null
            : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      where: 'id = ?',
      whereArgs: [photoId],
    );
    return count > 0;
  }

  Future<BatchOperationResult> addCategories(
      List<int> photoIds, List<int> categoryIds) async {
    final db = await _db;
    final failed = <int>[];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final photoId in photoIds) {
      try {
        await db.transaction((txn) async {
          final placeholders = List.filled(categoryIds.length, '?').join(',');
          final privacyRows = await txn.rawQuery(
            'SELECT MAX(is_private) AS private_target FROM themes '
            'WHERE id IN ($placeholders)',
            categoryIds,
          );
          final targetIsPrivate =
              ((privacyRows.first['private_target'] as int?) ?? 0) == 1;
          await txn.update(
            'photos',
            {'is_private': targetIsPrivate ? 1 : 0},
            where: 'id = ?',
            whereArgs: [photoId],
          );
          await txn.rawDelete(
            'DELETE FROM photo_categories WHERE photo_id = ? AND category_id IN '
            '(SELECT id FROM themes WHERE is_private = ?)',
            [photoId, targetIsPrivate ? 0 : 1],
          );
          for (final categoryId in categoryIds) {
            final categoryRows = await txn.query(
              'themes',
              columns: ['parent_id'],
              where: 'id = ?',
              whereArgs: [categoryId],
              limit: 1,
            );
            final parentId = categoryRows.isEmpty
                ? null
                : categoryRows.first['parent_id'] as int?;
            for (final linkedCategoryId in <int>{
              categoryId,
              if (parentId != null) parentId,
            }) {
              await txn.insert(
                'photo_categories',
                {
                  'photo_id': photoId,
                  'category_id': linkedCategoryId,
                  'created_at': now
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          }
        });
      } catch (_) {
        failed.add(photoId);
      }
    }
    return BatchOperationResult(
      successCount: photoIds.length - failed.length,
      failCount: failed.length,
      failedPhotoIds: failed,
    );
  }

  Future<BatchOperationResult> removeCategories(
      List<int> photoIds, List<int> categoryIds) async {
    final result = await _deleteRelations(
        'photo_categories', 'category_id', photoIds, categoryIds);
    final db = await _db;
    final systemRows = await db.query(
      'themes',
      columns: ['id'],
      where: 'is_system = 1',
      limit: 1,
    );
    final systemId = systemRows.isEmpty ? null : systemRows.first['id'] as int;
    for (final photoId in photoIds.where(
      (id) => !result.failedPhotoIds.contains(id),
    )) {
      await db.transaction((txn) async {
        final privateRows = await txn.rawQuery(
          'SELECT 1 FROM photo_categories pc JOIN themes t '
          'ON t.id = pc.category_id '
          'WHERE pc.photo_id = ? AND t.is_private = 1 LIMIT 1',
          [photoId],
        );
        if (privateRows.isNotEmpty) return;
        await txn.update(
          'photos',
          {'is_private': 0},
          where: 'id = ?',
          whereArgs: [photoId],
        );
        if (systemId != null) {
          final anyRows = await txn.query(
            'photo_categories',
            columns: ['photo_id'],
            where: 'photo_id = ?',
            whereArgs: [photoId],
            limit: 1,
          );
          if (anyRows.isEmpty) {
            await txn.insert(
              'photo_categories',
              {
                'photo_id': photoId,
                'category_id': systemId,
                'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      });
    }
    return result;
  }

  Future<BatchOperationResult> addTags(
      List<int> photoIds, List<int> tagIds) async {
    final db = await _db;
    final failed = <int>[];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final photoId in photoIds) {
      try {
        for (final tagId in tagIds) {
          await db.insert(
            'photo_tags',
            {'photo_id': photoId, 'tag_id': tagId, 'created_at': now},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      } catch (_) {
        failed.add(photoId);
      }
    }
    return BatchOperationResult(
      successCount: photoIds.length - failed.length,
      failCount: failed.length,
      failedPhotoIds: failed,
    );
  }

  Future<BatchOperationResult> removeTags(
          List<int> photoIds, List<int> tagIds) =>
      _deleteRelations('photo_tags', 'tag_id', photoIds, tagIds);

  Future<BatchOperationResult> markUnavailable(List<int> photoIds) =>
      _updateMany(photoIds, {
        'is_available': 0,
        'unavailable_reason': '照片已被删除或访问权限已撤销',
      });

  Future<int> cleanUnavailable() async {
    final db = await _db;
    return db.delete('photos', where: 'is_available = 0');
  }

  Future<bool> deletePhoto(int id) async {
    final db = await _db;
    return db.transaction((txn) async {
      await txn.update(
        'themes',
        {'cover_photo_id': null},
        where: 'cover_photo_id = ?',
        whereArgs: [id],
      );
      return await txn.delete('photos', where: 'id = ?', whereArgs: [id]) > 0;
    });
  }

  Future<bool> movePhoto(int photoId, int targetThemeId) async {
    final result = await addCategories([photoId], [targetThemeId]);
    return result.successCount == 1;
  }

  Future<BatchOperationResult> _updateMany(
      List<int> ids, Map<String, Object?> values) async {
    final db = await _db;
    final failed = <int>[];
    for (final id in ids) {
      try {
        if (await db
                .update('photos', values, where: 'id = ?', whereArgs: [id]) ==
            0) {
          failed.add(id);
        }
      } catch (_) {
        failed.add(id);
      }
    }
    return BatchOperationResult(
      successCount: ids.length - failed.length,
      failCount: failed.length,
      failedPhotoIds: failed,
    );
  }

  Future<BatchOperationResult> _deleteRelations(String table,
      String relationColumn, List<int> photoIds, List<int> relationIds) async {
    final db = await _db;
    final failed = <int>[];
    for (final photoId in photoIds) {
      try {
        for (final relationId in relationIds) {
          await db.delete(
            table,
            where: 'photo_id = ? AND $relationColumn = ?',
            whereArgs: [photoId, relationId],
          );
        }
      } catch (_) {
        failed.add(photoId);
      }
    }
    return BatchOperationResult(
      successCount: photoIds.length - failed.length,
      failCount: failed.length,
      failedPhotoIds: failed,
    );
  }
}
