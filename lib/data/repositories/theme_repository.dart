import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../database/app_database.dart';
import '../models/theme_model.dart';

class DuplicateCategoryNameException implements Exception {
  final String name;
  const DuplicateCategoryNameException(this.name);
}

class ThemeRepository {
  Future<Database> get _db => AppDatabase.database;

  /// Get top-level themes in the user-defined order.
  Future<List<ThemeModel>> getThemes() async {
    final db = await _db;
    final maps = await db.query(
      'themes',
      where: 'parent_id IS NULL AND is_system = 0',
      orderBy: 'sort_order ASC, id ASC',
    );
    return maps.map((m) => ThemeModel.fromMap(m)).toList();
  }

  Future<List<ThemeModel>> getSubAlbums(int parentId) async {
    final db = await _db;
    final maps = await db.query(
      'themes',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return maps.map(ThemeModel.fromMap).toList();
  }

  Future<int> getSubAlbumCount(int parentId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM themes WHERE parent_id = ?',
      [parentId],
    );
    return rows.first['count'] as int? ?? 0;
  }

  Future<List<ThemeModel>> getAllThemes() async {
    final db = await _db;
    final maps = await db.query(
      'themes',
      where: 'is_system = 0',
      orderBy: 'parent_id, sort_order ASC, id ASC',
    );
    return maps.map(ThemeModel.fromMap).toList();
  }

  /// Builds a lightweight, database-backed search index for every user album.
  ///
  /// Besides the album name and note, the index includes associated photo file
  /// names and tag names. Because photos imported into a child album are also
  /// associated with its parent, a matching photo can surface both levels.
  Future<Map<int, String>> getThemeSearchIndex() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        t.id,
        t.name,
        COALESCE(t.description, '') AS description,
        CASE WHEN t.is_private = 1 THEN ''
          ELSE COALESCE(GROUP_CONCAT(DISTINCT p.original_name), '') END
          AS photo_names,
        CASE WHEN t.is_private = 1 THEN ''
          ELSE COALESCE(GROUP_CONCAT(DISTINCT tag.name), '') END AS tag_names
      FROM themes t
      LEFT JOIN photo_categories pc ON pc.category_id = t.id
      LEFT JOIN photos p ON p.id = pc.photo_id
      LEFT JOIN photo_tags pt ON pt.photo_id = p.id
      LEFT JOIN tags tag ON tag.id = pt.tag_id
      WHERE t.is_system = 0
      GROUP BY t.id
    ''');
    return {
      for (final row in rows)
        row['id'] as int: [
          row['name'],
          row['description'],
          row['photo_names'],
          row['tag_names'],
        ].whereType<String>().join(' ').toLowerCase(),
    };
  }

  /// Get a single theme by ID. Returns null if not found.
  Future<ThemeModel?> getThemeById(int id) async {
    final db = await _db;
    final maps = await db.query(
      'themes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ThemeModel.fromMap(maps.first);
  }

  /// Get the system "未分类" theme. Returns null if somehow missing.
  Future<ThemeModel?> getUncategorizedTheme() async {
    final db = await _db;
    final maps = await db.query(
      'themes',
      where: 'is_system = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ThemeModel.fromMap(maps.first);
  }

  /// Create a new user theme.
  Future<ThemeModel> createTheme(
    String name, {
    int? parentId,
    int colorValue = AppConstants.defaultCategoryColor,
    String iconKey = AppConstants.defaultCategoryIcon,
    bool isPrivate = false,
    bool isVirtual = false,
    String? virtualRules,
  }) async {
    final db = await _db;
    final normalized = name.trim();
    if (normalized.isEmpty) throw const FormatException('分类名称不能为空');
    if (await categoryNameExists(normalized)) {
      throw DuplicateCategoryNameException(normalized);
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (parentId != null) {
      final parent = await getThemeById(parentId);
      if (parent == null || parent.parentId != null) {
        throw const FormatException('只允许创建一级子相册');
      }
      isPrivate = parent.isPrivate;
    }
    final orderRows = await db.rawQuery(
      parentId == null
          ? 'SELECT MIN(sort_order) AS value FROM themes WHERE parent_id IS NULL AND is_system = 0'
          : 'SELECT MIN(sort_order) AS value FROM themes WHERE parent_id = ?',
      parentId == null ? const [] : [parentId],
    );
    final sortOrder = ((orderRows.first['value'] as int?) ?? 1) - 1;
    final id = await db.insert('themes', {
      'name': normalized,
      'description': null,
      'cover_photo_id': null,
      'cover_image_path': null,
      'created_at': now,
      'is_system': 0,
      'parent_id': parentId,
      'color_value': colorValue,
      'icon_key': iconKey,
      'sort_order': sortOrder,
      'is_private': isPrivate ? 1 : 0,
      'is_virtual': isVirtual ? 1 : 0,
      'virtual_rules': isVirtual ? virtualRules : null,
    });
    return ThemeModel(
      id: id,
      name: normalized,
      description: '',
      coverPhotoId: null,
      coverImagePath: null,
      createdAt: now,
      isSystem: false,
      parentId: parentId,
      colorValue: colorValue,
      iconKey: iconKey,
      sortOrder: sortOrder,
      isPrivate: isPrivate,
      isVirtual: isVirtual,
      virtualRules: isVirtual ? virtualRules : null,
    );
  }

  /// Replace the rules of a virtual album. Ordinary albums are rejected.
  Future<bool> updateVirtualRules(int themeId, String rulesJson) async {
    final db = await _db;
    final rows = await db.query(
      'themes',
      columns: ['is_virtual'],
      where: 'id = ?',
      whereArgs: [themeId],
      limit: 1,
    );
    if (rows.isEmpty || ((rows.first['is_virtual'] as int?) ?? 0) != 1) {
      return false;
    }
    return await db.update(
          'themes',
          {'virtual_rules': rulesJson},
          where: 'id = ? AND is_virtual = 1',
          whereArgs: [themeId],
        ) >
        0;
  }

  Future<void> reorderThemes(List<int> orderedIds, {int? parentId}) async {
    if (orderedIds.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (var index = 0; index < orderedIds.length; index++) {
        await txn.update(
          'themes',
          {'sort_order': index},
          where: parentId == null
              ? 'id = ? AND parent_id IS NULL AND is_system = 0'
              : 'id = ? AND parent_id = ?',
          whereArgs: parentId == null
              ? [orderedIds[index]]
              : [orderedIds[index], parentId],
        );
      }
    });
  }

  /// Rename a theme. Returns true if updated.
  Future<bool> renameTheme(int id, String newName,
      {int? colorValue, String? iconKey}) async {
    final db = await _db;
    final normalized = newName.trim();
    if (normalized.isEmpty) throw const FormatException('分类名称不能为空');
    if (await categoryNameExists(normalized, excludingId: id)) {
      throw DuplicateCategoryNameException(normalized);
    }
    final count = await db.update(
      'themes',
      {
        'name': normalized,
        if (colorValue != null) 'color_value': colorValue,
        if (iconKey != null) 'icon_key': iconKey,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  Future<bool> updateDescription(int id, String description) async {
    final db = await _db;
    final normalized = description.trim();
    final count = await db.update(
      'themes',
      {'description': normalized.isEmpty ? null : normalized},
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  Future<bool> categoryNameExists(String name, {int? excludingId}) async {
    final db = await _db;
    final rows = await db.query('themes', columns: ['id', 'name']);
    final normalized = name.trim().toLowerCase();
    return rows.any((row) =>
        row['id'] != excludingId &&
        (row['name'] as String).trim().toLowerCase() == normalized);
  }

  /// Set the cover photo for a theme. Pass null photoId to clear the cover.
  Future<bool> setCoverPhoto(int themeId, int? photoId) async {
    final db = await _db;
    final count = await db.update(
      'themes',
      {
        'cover_photo_id': photoId,
        if (photoId != null) 'cover_image_path': null,
      },
      where: 'id = ?',
      whereArgs: [themeId],
    );
    return count > 0;
  }

  Future<bool> setCoverImagePath(int themeId, String imagePath) async {
    final db = await _db;
    final count = await db.update(
      'themes',
      {'cover_photo_id': null, 'cover_image_path': imagePath},
      where: 'id = ?',
      whereArgs: [themeId],
    );
    return count > 0;
  }

  /// Delete a theme and move all its photos to the "未分类" theme.
  /// Uses a transaction for atomicity. Returns true on success.
  Future<bool> deleteTheme(int themeId) async {
    final db = await _db;

    try {
      await db.transaction((txn) async {
        // Find the uncategorized theme
        final uncategorizedRows = await txn.query(
          'themes',
          where: 'is_system = ?',
          whereArgs: [1],
          limit: 1,
        );

        if (uncategorizedRows.isEmpty) {
          throw Exception(
              'System theme "${AppConstants.systemThemeName}" not found');
        }

        final uncategorizedId = uncategorizedRows.first['id'] as int;

        final childRows = await txn.query(
          'themes',
          columns: ['id'],
          where: 'parent_id = ?',
          whereArgs: [themeId],
        );
        final affectedThemeIds = <int>[
          themeId,
          ...childRows.map((row) => row['id'] as int),
        ];

        // Keep the legacy non-null theme_id valid before deleting categories.
        for (final affectedId in affectedThemeIds) {
          await txn.update(
            'photos',
            {'theme_id': uncategorizedId},
            where: 'theme_id = ?',
            whereArgs: [affectedId],
          );
        }

        await txn.delete(
          'themes',
          where: 'parent_id = ?',
          whereArgs: [themeId],
        );

        // Delete the theme
        await txn.delete(
          'themes',
          where: 'id = ?',
          whereArgs: [themeId],
        );
        await txn.execute('''
          UPDATE photos
          SET is_private = CASE WHEN EXISTS (
            SELECT 1 FROM photo_categories pc
            JOIN themes t ON t.id = pc.category_id
            WHERE pc.photo_id = photos.id AND t.is_private = 1
          ) THEN 1 ELSE 0 END
        ''');
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the number of photos in a theme.
  Future<int> getPhotoCount(int themeId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM photo_categories WHERE category_id = ?',
      [themeId],
    );
    return (result.first['count'] as int?) ?? 0;
  }
}
