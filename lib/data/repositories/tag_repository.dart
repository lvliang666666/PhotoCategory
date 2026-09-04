import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/tag_model.dart';

class DuplicateTagNameException implements Exception {
  final String name;
  const DuplicateTagNameException(this.name);
}

class TagRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<List<TagModel>> getTags() async {
    final db = await _db;
    final rows = await db.query('tags', orderBy: 'name COLLATE NOCASE');
    return rows.map(TagModel.fromMap).toList();
  }

  Future<TagModel> createTag(String name, int colorValue) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw const FormatException('标签名称不能为空');
    final db = await _db;
    if (await _exists(normalized)) throw DuplicateTagNameException(normalized);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final id = await db.insert('tags', {
      'name': normalized,
      'color_value': colorValue,
      'created_at': now,
    });
    return TagModel(
      id: id,
      name: normalized,
      colorValue: colorValue,
      createdAt: now,
    );
  }

  Future<bool> updateTag(int id, String name, int colorValue) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw const FormatException('标签名称不能为空');
    final db = await _db;
    if (await _exists(normalized, excludingId: id)) {
      throw DuplicateTagNameException(normalized);
    }
    return await db.update(
          'tags',
          {'name': normalized, 'color_value': colorValue},
          where: 'id = ?',
          whereArgs: [id],
        ) >
        0;
  }

  Future<bool> deleteTag(int id) async {
    final db = await _db;
    return await db.delete('tags', where: 'id = ?', whereArgs: [id]) > 0;
  }

  Future<bool> _exists(String name, {int? excludingId}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT 1 FROM tags WHERE name = ? COLLATE NOCASE '
      '${excludingId == null ? '' : 'AND id != ?'} LIMIT 1',
      [name, if (excludingId != null) excludingId],
    );
    return rows.isNotEmpty;
  }
}
