import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class PrivateAlbumRepository {
  static const int _hashRounds = 12000;

  Future<Database> get _db => AppDatabase.database;

  Future<int?> rootThemeId(int themeId) async {
    final db = await _db;
    final rows = await db.query(
      'themes',
      columns: ['id', 'parent_id', 'is_private'],
      where: 'id = ?',
      whereArgs: [themeId],
      limit: 1,
    );
    if (rows.isEmpty || ((rows.first['is_private'] as int?) ?? 0) != 1) {
      return null;
    }
    return (rows.first['parent_id'] as int?) ?? (rows.first['id'] as int);
  }

  Future<bool> hasPassword(int rootThemeId) async {
    final db = await _db;
    final rows = await db.query(
      'private_album_credentials',
      columns: ['root_theme_id'],
      where: 'root_theme_id = ?',
      whereArgs: [rootThemeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> setPassword(int rootThemeId, String password) async {
    validatePassword(password);
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final salt = _newSalt();
    await db.insert(
      'private_album_credentials',
      {
        'root_theme_id': rootThemeId,
        'password_salt': salt,
        'password_hash': _deriveHash(password, salt),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> verifyPassword(int themeId, String password) async {
    final rootId = await rootThemeId(themeId);
    if (rootId == null) return true;
    final db = await _db;
    final rows = await db.query(
      'private_album_credentials',
      columns: ['password_salt', 'password_hash'],
      where: 'root_theme_id = ?',
      whereArgs: [rootId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final salt = rows.first['password_salt'] as String;
    final expected = rows.first['password_hash'] as String;
    return _constantTimeEquals(_deriveHash(password, salt), expected);
  }

  static void validatePassword(String password) {
    if (!RegExp(r'^[A-Za-z0-9]{6,32}$').hasMatch(password)) {
      throw const FormatException('密码需为 6～32 位数字或英文字母');
    }
  }

  static String _newSalt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  static String _deriveHash(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');
    final saltBytes = utf8.encode(salt);
    for (var i = 0; i < _hashRounds; i++) {
      bytes = sha256.convert([...bytes, ...saltBytes]).bytes;
    }
    return base64UrlEncode(bytes);
  }

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return difference == 0;
  }
}
