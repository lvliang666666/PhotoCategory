import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';

class AppDatabase {
  AppDatabase._();

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.dbName);

    final db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );

    // Safety net: ensure the system uncategorized theme always exists.
    // Covers edge cases like manual DB modification or corrupted state.
    await _ensureUncategorizedTheme(db);

    return db;
  }

  /// Guarantee that the "未分类" system theme exists.
  static Future<void> _ensureUncategorizedTheme(Database db) async {
    final count = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM themes WHERE is_system = 1',
    );
    final exists = (count.first['cnt'] as int?) ?? 0;
    if (exists == 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.insert('themes', {
        'name': AppConstants.systemThemeName,
        'cover_photo_id': null,
        'created_at': now,
        'is_system': 1,
        'parent_id': null,
        'color_value': AppConstants.defaultCategoryColor,
        'icon_key': AppConstants.defaultCategoryIcon,
      });
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE themes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        cover_photo_id INTEGER,
        cover_image_path TEXT,
        created_at INTEGER NOT NULL,
        is_system INTEGER NOT NULL DEFAULT 0,
        parent_id INTEGER,
        color_value INTEGER NOT NULL DEFAULT ${AppConstants.defaultCategoryColor},
        icon_key TEXT NOT NULL DEFAULT '${AppConstants.defaultCategoryIcon}',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_private INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (parent_id) REFERENCES themes(id) ON DELETE CASCADE,
        UNIQUE(name COLLATE NOCASE)
      )
    ''');

    await db.execute('''
      CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        theme_id INTEGER NOT NULL,
        local_path TEXT NOT NULL,
        original_name TEXT,
        taken_at INTEGER,
        imported_at INTEGER NOT NULL,
        media_id TEXT,
        media_uri TEXT,
        mime_type TEXT,
        width INTEGER,
        height INTEGER,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_available INTEGER NOT NULL DEFAULT 1,
        last_seen_at INTEGER,
        source_type TEXT NOT NULL DEFAULT 'imported',
        content_modified_at INTEGER,
        unavailable_reason TEXT,
        story_text TEXT,
        story_updated_at INTEGER,
        is_private INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (theme_id) REFERENCES themes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_photos_theme_id ON photos(theme_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_themes_parent_id ON themes(parent_id)
    ''');

    await _createV3Tables(db);
    await _createV10Tables(db);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_photos_source_type '
      'ON photos(source_type, imported_at DESC)',
    );

    // Create system "未分类" theme
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.insert('themes', {
      'name': AppConstants.systemThemeName,
      'cover_photo_id': null,
      'created_at': now,
      'is_system': 1,
      'parent_id': null,
      'color_value': AppConstants.defaultCategoryColor,
      'icon_key': AppConstants.defaultCategoryIcon,
    });
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE themes ADD COLUMN parent_id INTEGER');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_themes_parent_id ON themes(parent_id)',
      );
    }
    if (oldVersion < 3) {
      await _upgradeToV3(db);
    }
    if (oldVersion < 4) {
      await _upgradeToV4(db);
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE themes ADD COLUMN icon_key TEXT NOT NULL DEFAULT '${AppConstants.defaultCategoryIcon}'",
      );
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE photos ADD COLUMN story_text TEXT');
      await db
          .execute('ALTER TABLE photos ADD COLUMN story_updated_at INTEGER');
    }
    if (oldVersion < 7) {
      // System-gallery indexing was removed. Delete only its cached metadata;
      // foreign-key cascades clean local relations and device originals remain
      // untouched.
      await db.delete(
        'photos',
        where: "source_type = 'media_store'",
      );
    }
    if (oldVersion < 8) {
      await db.transaction((txn) async {
        final themeColumns = await txn.rawQuery('PRAGMA table_info(themes)');
        final hasCoverImagePath = themeColumns.any(
          (column) => column['name'] == 'cover_image_path',
        );
        if (!hasCoverImagePath) {
          await txn.execute(
            'ALTER TABLE themes ADD COLUMN cover_image_path TEXT',
          );
        }
        // A sub-album is part of its parent album. Backfill the parent
        // association for photos imported by earlier versions.
        await txn.execute('''
          INSERT OR IGNORE INTO photo_categories(photo_id, category_id, created_at)
          SELECT pc.photo_id, child.parent_id, pc.created_at
          FROM photo_categories pc
          JOIN themes child ON child.id = pc.category_id
          WHERE child.parent_id IS NOT NULL
        ''');
      });
    }
    if (oldVersion < 9) {
      await _addColumnIfMissing(db, 'themes', 'description', 'TEXT');
    }
    if (oldVersion < 10) {
      await db.transaction((txn) async {
        await _addColumnIfMissing(
          txn,
          'themes',
          'sort_order',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _addColumnIfMissing(
          txn,
          'themes',
          'is_private',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _addColumnIfMissing(
          txn,
          'photos',
          'is_private',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await txn.execute(
          'UPDATE themes SET sort_order = -created_at WHERE sort_order = 0',
        );
        await _createV10Tables(txn);
      });
    }
  }

  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  static Future<void> _createV10Tables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS private_album_credentials (
        root_theme_id INTEGER PRIMARY KEY,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(root_theme_id) REFERENCES themes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_themes_sort_order '
      'ON themes(parent_id, sort_order, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_photos_private '
      'ON photos(is_private, imported_at DESC)',
    );
  }

  static Future<void> _upgradeToV3(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        'ALTER TABLE themes ADD COLUMN color_value INTEGER NOT NULL '
        'DEFAULT ${AppConstants.defaultCategoryColor}',
      );
      await txn.execute('ALTER TABLE photos ADD COLUMN media_id TEXT');
      await txn.execute('ALTER TABLE photos ADD COLUMN media_uri TEXT');
      await txn.execute('ALTER TABLE photos ADD COLUMN mime_type TEXT');
      await txn.execute('ALTER TABLE photos ADD COLUMN width INTEGER');
      await txn.execute('ALTER TABLE photos ADD COLUMN height INTEGER');
      await txn.execute(
        'ALTER TABLE photos ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
      );
      await txn.execute(
        'ALTER TABLE photos ADD COLUMN is_available INTEGER NOT NULL DEFAULT 1',
      );
      await txn.execute('ALTER TABLE photos ADD COLUMN last_seen_at INTEGER');
      await _createV3Tables(txn);
      await txn.execute('''
        INSERT OR IGNORE INTO photo_categories(photo_id, category_id, created_at)
        SELECT id, theme_id, imported_at FROM photos
        WHERE theme_id IS NOT NULL
      ''');
      // Older builds did not reject duplicate names. Keep all legacy rows;
      // repositories enforce uniqueness for every new write after migration.
    });
  }

  static Future<void> _createV3Tables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        color_value INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS photo_categories (
        photo_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(photo_id, category_id),
        FOREIGN KEY(photo_id) REFERENCES photos(id) ON DELETE CASCADE,
        FOREIGN KEY(category_id) REFERENCES themes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS photo_tags (
        photo_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(photo_id, tag_id),
        FOREIGN KEY(photo_id) REFERENCES photos(id) ON DELETE CASCADE,
        FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recent_views (
        photo_id INTEGER PRIMARY KEY,
        viewed_at INTEGER NOT NULL,
        FOREIGN KEY(photo_id) REFERENCES photos(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_photo_categories_category '
      'ON photo_categories(category_id, photo_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_photo_tags_tag '
      'ON photo_tags(tag_id, photo_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recent_views_time '
      'ON recent_views(viewed_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_photos_search '
      'ON photos(original_name, taken_at, imported_at, is_favorite)',
    );
  }

  static Future<void> _upgradeToV4(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        "ALTER TABLE photos ADD COLUMN source_type TEXT NOT NULL DEFAULT 'imported'",
      );
      await txn.execute(
        'ALTER TABLE photos ADD COLUMN content_modified_at INTEGER',
      );
      await txn.execute(
        'ALTER TABLE photos ADD COLUMN unavailable_reason TEXT',
      );
      await txn.execute(
        "UPDATE photos SET source_type = 'media_store' "
        "WHERE media_id IS NOT NULL AND TRIM(COALESCE(local_path, '')) = ''",
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_photos_source_type '
        'ON photos(source_type, imported_at DESC)',
      );
    });
  }

  /// Close and reset the database connection. Useful for testing.
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  static Future<void> createSchemaForTesting(Database db) async {
    await _onCreate(db, AppConstants.dbVersion);
    _database = db;
  }

  static Future<void> upgradeSchemaForTesting(
      Database db, int oldVersion) async {
    await _onUpgrade(db, oldVersion, AppConstants.dbVersion);
    _database = db;
  }
}
