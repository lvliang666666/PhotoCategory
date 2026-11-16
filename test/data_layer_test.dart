import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

import 'package:photo_storer/core/constants/app_constants.dart';
import 'package:photo_storer/data/database/app_database.dart';
import 'package:photo_storer/data/models/photo_filter.dart';
import 'package:photo_storer/data/models/photo_model.dart';
import 'package:photo_storer/data/repositories/photo_repository.dart';
import 'package:photo_storer/data/repositories/private_album_repository.dart';
import 'package:photo_storer/data/repositories/tag_repository.dart';
import 'package:photo_storer/data/repositories/theme_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ThemeRepository themes;
  late TagRepository tags;
  late PhotoRepository photos;
  late int systemId;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await AppDatabase.createSchemaForTesting(db);
    themes = ThemeRepository();
    tags = TagRepository();
    photos = PhotoRepository();
    systemId = (await themes.getUncategorizedTheme())!.id!;
  });

  tearDown(() async {
    await AppDatabase.close();
  });

  test('分类可创建编辑删除，空名和重复名称会被拒绝', () async {
    final category = await themes.createTheme('电影', colorValue: 0xFF112233);
    expect(category.colorValue, 0xFF112233);
    expect(
        await themes.renameTheme(category.id!, '经典电影', colorValue: 0xFF334455),
        isTrue);
    expect((await themes.getThemeById(category.id!))!.name, '经典电影');
    expect(await themes.updateDescription(category.id!, '记录喜欢的电影片段'), isTrue);
    expect((await themes.getThemeById(category.id!))!.description, '记录喜欢的电影片段');
    await expectLater(
      themes.createTheme('经典电影'),
      throwsA(isA<DuplicateCategoryNameException>()),
    );
    await expectLater(
      themes.createTheme('   '),
      throwsA(isA<FormatException>()),
    );
    expect(await themes.deleteTheme(category.id!), isTrue);
  });

  test('标签可创建编辑删除且关系随标签删除，照片保留', () async {
    final tag = await tags.createTag('旅行', 0xFF00897B);
    expect(await tags.updateTag(tag.id!, '出游', 0xFF1E88E5), isTrue);
    final photo = await _addPhoto(photos, systemId, 'trip.jpg', 1000);
    expect((await photos.addTags([photo.id!], [tag.id!])).successCount, 1);
    expect(
        (await photos.searchPhotos(PhotoFilter(tagIds: {tag.id!}))).length, 1);
    expect(await tags.deleteTag(tag.id!), isTrue);
    expect(await photos.getPhotoById(photo.id!), isNotNull);
  });

  test('一张照片可属于多个分类和多个标签', () async {
    final a = await themes.createTheme('电影');
    final b = await themes.createTheme('收藏夹');
    final x = await tags.createTag('海报', 0xFFE53935);
    final y = await tags.createTag('高清', 0xFF3949AB);
    final photo = await _addPhoto(photos, systemId, 'poster.png', 2000);
    await photos.addCategories([photo.id!], [a.id!, b.id!]);
    await photos.addTags([photo.id!], [x.id!, y.id!]);
    expect(
        (await photos.searchPhotos(PhotoFilter(categoryIds: {a.id!, b.id!})))
            .single
            .id,
        photo.id);
    expect(
        (await photos.searchPhotos(PhotoFilter(tagIds: {x.id!, y.id!})))
            .single
            .id,
        photo.id);
  });

  test('添加到子相册时会同时加入母相册', () async {
    final parent = await themes.createTheme('电影');
    final child = await themes.createTheme('八仙', parentId: parent.id);
    final photo = await _addPhoto(photos, systemId, 'scene.jpg', 2100);

    final result = await photos.addCategories([photo.id!], [child.id!]);
    expect(result.failCount, 0);
    expect(
      (await photos.getPhotosByTheme(child.id!)).map((item) => item.id),
      contains(photo.id),
    );
    expect(
      (await photos.getPhotosByTheme(parent.id!)).map((item) => item.id),
      contains(photo.id),
    );
  });

  test('私密相册子相册共享主相册密码且公共查询不显示私密照片', () async {
    final privateAlbums = PrivateAlbumRepository();
    final root = await themes.createTheme('私密回忆', isPrivate: true);
    final child = await themes.createTheme('旅行', parentId: root.id);
    await privateAlbums.setPassword(root.id!, 'Memory2026');

    expect(child.isPrivate, isTrue);
    expect(await privateAlbums.rootThemeId(child.id!), root.id);
    expect(await privateAlbums.verifyPassword(child.id!, 'Memory2026'), isTrue);
    expect(await privateAlbums.verifyPassword(child.id!, 'wrong000'), isFalse);

    final photo = await _addPhoto(photos, systemId, 'private.jpg', 2120);
    await photos.addCategories([photo.id!], [child.id!]);
    expect(await photos.searchPhotos(const PhotoFilter()), isEmpty);
    expect(
      (await photos.getPhotosByTheme(child.id!)).map((item) => item.id),
      contains(photo.id),
    );
    await photos.recordView(photo.id!);
    expect(await photos.getRecentViews(), isEmpty);
  });

  test('相册拖动顺序按父级范围持久化', () async {
    final first = await themes.createTheme('第一');
    final second = await themes.createTheme('第二');
    final third = await themes.createTheme('第三');
    await themes.reorderThemes([first.id!, third.id!, second.id!]);
    expect(
      (await themes.getThemes()).map((theme) => theme.id),
      [first.id, third.id, second.id],
    );
  });

  test('主页搜索索引包含子相册名称与其中的照片文件名', () async {
    final parent = await themes.createTheme('电影');
    final child = await themes.createTheme('八仙', parentId: parent.id);
    final photo = await _addPhoto(photos, systemId, '海边决战.jpg', 2150);
    await photos.addCategories([photo.id!], [child.id!]);

    final index = await themes.getThemeSearchIndex();
    expect(index[child.id], contains('八仙'));
    expect(index[child.id], contains('海边决战.jpg'));
    expect(index[parent.id], contains('海边决战.jpg'));
  });

  test('相册可保存独立封面路径并清除照片封面引用', () async {
    final album = await themes.createTheme('独立封面');
    final photo = await _addPhoto(photos, systemId, 'inside.jpg', 2200);
    await themes.setCoverPhoto(album.id!, photo.id);
    expect((await themes.getThemeById(album.id!))!.coverPhotoId, photo.id);

    expect(
        await themes.setCoverImagePath(album.id!, 'covers/custom.jpg'), isTrue);
    final updated = await themes.getThemeById(album.id!);
    expect(updated!.coverPhotoId, isNull);
    expect(updated.coverImagePath, 'covers/custom.jpg');
  });

  test('删除分类只删除关系，不删除照片记录', () async {
    final category = await themes.createTheme('待删除');
    final photo = await _addPhoto(photos, category.id!, 'keep.jpg', 3000);
    expect(await themes.deleteTheme(category.id!), isTrue);
    expect(await photos.getPhotoById(photo.id!), isNotNull);
    expect(
        (await photos.searchPhotos(const PhotoFilter(onlyUnclassified: true)))
            .map((p) => p.id),
        contains(photo.id));
  });

  test('收藏持久化、最近浏览倒序且上限有效', () async {
    final created = <PhotoModel>[];
    for (var i = 0; i < AppConstants.recentViewsLimit + 5; i++) {
      created.add(await _addPhoto(photos, systemId, 'p$i.jpg', i + 10));
      await photos.recordView(created.last.id!);
    }
    await photos.setFavorite([created.last.id!], true);
    expect(
        (await photos.searchPhotos(const PhotoFilter(favorite: true)))
            .single
            .id,
        created.last.id);
    final recent =
        await photos.getRecentViews(limit: AppConstants.recentViewsLimit + 20);
    expect(recent.length, AppConstants.recentViewsLimit);
    expect(recent.first.id, created.last.id);
    expect(recent.map((p) => p.id), isNot(contains(created.first.id)));
  });

  test('照片故事可保存、修改和清空且不影响原照片', () async {
    final photo = await _addPhoto(photos, systemId, 'memory.jpg', 3500);
    expect(await photos.updateStory(photo.id!, '那天的风很温柔。'), isTrue);
    var stored = await photos.getPhotoById(photo.id!);
    expect(stored!.storyText, '那天的风很温柔。');
    expect(stored.storyUpdatedAt, isNotNull);
    expect(await photos.updateStory(photo.id!, '后来再看，依然很喜欢。'), isTrue);
    stored = await photos.getPhotoById(photo.id!);
    expect(stored!.storyText, '后来再看，依然很喜欢。');
    expect(await photos.updateStory(photo.id!, '   '), isTrue);
    stored = await photos.getPhotoById(photo.id!);
    expect(stored!.storyText, isNull);
    expect(stored.storyUpdatedAt, isNull);
    expect(stored.originalName, 'memory.jpg');
  });

  test('文件名、分类、标签、日期、格式、收藏和方向可组合筛选', () async {
    final category = await themes.createTheme('电影');
    final tag = await tags.createTag('海报', 0xFF00897B);
    final target = await photos.addPhoto(PhotoModel(
      themeId: systemId,
      localPath: '',
      originalName: '流浪地球海报.PNG',
      takenAt: DateTime(2024, 2, 3).millisecondsSinceEpoch ~/ 1000,
      importedAt: 4000,
      mimeType: 'image/png',
      width: 1920,
      height: 1080,
      isFavorite: true,
    ));
    await photos.addCategories([target.id!], [category.id!]);
    await photos.addTags([target.id!], [tag.id!]);
    await _addPhoto(photos, systemId, 'other.jpg', 5000);

    final result = await photos.searchPhotos(PhotoFilter(
      query: '地球',
      categoryIds: {category.id!},
      tagIds: {tag.id!},
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 12, 31),
      formats: const {'png'},
      favorite: true,
      orientation: 'landscape',
    ));
    expect(result.single.id, target.id);
    expect(const PhotoFilter().isEmpty, isTrue);
    expect(const PhotoFilter(query: 'x').activeCount, 1);
  });

  test('批量分类、收藏和部分失败会报告失败项目', () async {
    final category = await themes.createTheme('批量');
    final one = await _addPhoto(photos, systemId, 'one.jpg', 6000);
    final two = await _addPhoto(photos, systemId, 'two.jpg', 6001);
    final relation =
        await photos.addCategories([one.id!, two.id!], [category.id!]);
    expect(relation.successCount, 2);
    final favorite = await photos.setFavorite([one.id!, 999999], true);
    expect(favorite.successCount, 1);
    expect(favorite.failCount, 1);
    expect(favorite.failedPhotoIds, [999999]);
  });

  test('直接删除照片会清理数据库记录和相册封面引用', () async {
    final category = await themes.createTheme('待删除');
    final photo = await _addPhoto(photos, systemId, 'delete.jpg', 6500);
    await themes.setCoverPhoto(category.id!, photo.id);

    expect(await photos.deletePhoto(photo.id!), isTrue);
    expect(await photos.getPhotoById(photo.id!), isNull);
    expect((await themes.getThemeById(category.id!))!.coverPhotoId, isNull);
  });

  test('手动导入图库支持数据库分页和总数查询', () async {
    for (var i = 0; i < 85; i++) {
      await _addPhoto(photos, systemId, 'page-$i.jpg', 8000 + i);
    }
    const manualFilter = PhotoFilter(
      sourceTypes: {PhotoSourceType.imported, PhotoSourceType.appGenerated},
    );
    expect(await photos.countPhotos(manualFilter), 85);
    expect(await photos.searchPhotos(manualFilter, limit: 80), hasLength(80));
    expect(await photos.searchPhotos(manualFilter, limit: 80, offset: 80),
        hasLength(5));
  });

  test('旧版本数据库升级保留照片和分类并迁移多对多关系', () async {
    await AppDatabase.close();
    final legacy = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await legacy.execute('''CREATE TABLE themes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      cover_photo_id INTEGER, created_at INTEGER NOT NULL,
      is_system INTEGER NOT NULL DEFAULT 0, parent_id INTEGER)''');
    await legacy.execute('''CREATE TABLE photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT, theme_id INTEGER NOT NULL,
      local_path TEXT NOT NULL, original_name TEXT, taken_at INTEGER,
      imported_at INTEGER NOT NULL)''');
    await legacy.insert('themes', {
      'id': 1,
      'name': '未分类',
      'created_at': 1,
      'is_system': 1,
    });
    await legacy.insert('themes', {
      'id': 2,
      'name': '旧分类',
      'created_at': 2,
      'is_system': 0,
    });
    await legacy.insert('photos', {
      'id': 1,
      'theme_id': 2,
      'local_path': 'legacy.jpg',
      'original_name': 'legacy.jpg',
      'imported_at': 3,
    });
    await AppDatabase.upgradeSchemaForTesting(legacy, 2);
    final migrated = await legacy.rawQuery(
      'SELECT * FROM photo_categories WHERE photo_id = 1 AND category_id = 2',
    );
    expect(migrated, hasLength(1));
    expect((await legacy.query('photos', where: 'id = 1')), hasLength(1));
    expect((await legacy.query('themes', where: 'id = 2')), hasLength(1));
    expect(
        (await legacy.query('photos', where: 'id = 1')).single['source_type'],
        'imported');
    db = legacy;
  });

  test('v7 升级只清除旧系统索引并保留手动导入照片', () async {
    await db.insert('photos', {
      'theme_id': systemId,
      'local_path': 'manual.jpg',
      'original_name': 'manual.jpg',
      'imported_at': 10,
      'source_type': 'imported',
    });
    await db.insert('photos', {
      'theme_id': systemId,
      'local_path': '',
      'original_name': 'indexed.jpg',
      'imported_at': 11,
      'media_id': 'legacy-media-id',
      'source_type': 'media_store',
    });

    await AppDatabase.upgradeSchemaForTesting(db, 6);

    expect(await db.query('photos', where: "source_type = 'media_store'"),
        isEmpty);
    expect(await db.query('photos', where: "source_type = 'imported'"),
        hasLength(1));
  });

  test('v9 升级到 v10 保留相册照片并添加私密与排序结构', () async {
    await AppDatabase.close();
    final legacy = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await legacy.execute('''CREATE TABLE themes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      description TEXT, cover_photo_id INTEGER, cover_image_path TEXT,
      created_at INTEGER NOT NULL, is_system INTEGER NOT NULL DEFAULT 0,
      parent_id INTEGER, color_value INTEGER NOT NULL DEFAULT 0,
      icon_key TEXT NOT NULL DEFAULT 'album')''');
    await legacy.execute('''CREATE TABLE photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT, theme_id INTEGER NOT NULL,
      local_path TEXT NOT NULL, original_name TEXT, taken_at INTEGER,
      imported_at INTEGER NOT NULL)''');
    await legacy.insert('themes', {
      'id': 1,
      'name': '保留相册',
      'created_at': 88,
      'is_system': 0,
      'color_value': 0,
      'icon_key': 'album',
    });
    await legacy.insert('photos', {
      'id': 1,
      'theme_id': 1,
      'local_path': 'keep.jpg',
      'imported_at': 99,
    });

    await AppDatabase.upgradeSchemaForTesting(legacy, 9);
    expect(await legacy.query('themes', where: 'id = 1'), hasLength(1));
    expect(await legacy.query('photos', where: 'id = 1'), hasLength(1));
    expect(
      (await legacy.query('themes', where: 'id = 1')).single['sort_order'],
      -88,
    );
    expect(
      (await legacy.query('photos', where: 'id = 1')).single['is_private'],
      0,
    );
    expect(
      await legacy.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='private_album_credentials'",
      ),
      hasLength(1),
    );
    db = legacy;
  });

  test('v10 升级到 v11 保留照片并添加内容指纹列与索引', () async {
    await AppDatabase.close();
    final legacy = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await legacy.execute('''CREATE TABLE themes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      description TEXT, cover_photo_id INTEGER, cover_image_path TEXT,
      created_at INTEGER NOT NULL, is_system INTEGER NOT NULL DEFAULT 0,
      parent_id INTEGER, color_value INTEGER NOT NULL DEFAULT 0,
      icon_key TEXT NOT NULL DEFAULT 'album',
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_private INTEGER NOT NULL DEFAULT 0)''');
    await legacy.execute('''CREATE TABLE photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT, theme_id INTEGER NOT NULL,
      local_path TEXT NOT NULL, original_name TEXT, taken_at INTEGER,
      imported_at INTEGER NOT NULL, media_id TEXT, media_uri TEXT,
      mime_type TEXT, width INTEGER, height INTEGER,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      is_available INTEGER NOT NULL DEFAULT 1, last_seen_at INTEGER,
      source_type TEXT NOT NULL DEFAULT 'imported',
      content_modified_at INTEGER, unavailable_reason TEXT,
      story_text TEXT, story_updated_at INTEGER,
      is_private INTEGER NOT NULL DEFAULT 0)''');
    await legacy.insert('themes', {
      'id': 1,
      'name': '老相册',
      'created_at': 88,
      'is_system': 0,
      'color_value': 0,
      'icon_key': 'album',
    });
    await legacy.insert('photos', {
      'id': 1,
      'theme_id': 1,
      'local_path': 'legacy.jpg',
      'imported_at': 99,
    });

    await AppDatabase.upgradeSchemaForTesting(legacy, 10);
    expect(await legacy.query('photos', where: 'id = 1'), hasLength(1));
    final columns = await legacy.rawQuery('PRAGMA table_info(photos)');
    expect(columns.any((column) => column['name'] == 'content_hash'), isTrue);
    expect(
      await legacy.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_photos_content_hash'",
      ),
      hasLength(1),
    );
    db = legacy;
  });

  test('按内容指纹查重命中已有照片', () async {
    final photo = await photos.addPhoto(PhotoModel(
      themeId: systemId,
      localPath: 'hash-a.jpg',
      importedAt: 1000,
      contentHash: 'hash-a',
    ));
    expect(await photos.getPhotoIdByContentHash('hash-a'), photo.id);
    expect(await photos.getPhotoIdByContentHash('hash-missing'), isNull);
  });

  test('回填查询只返回缺少指纹且有本地路径的照片', () async {
    await photos.addPhoto(PhotoModel(
      themeId: systemId,
      localPath: 'with-hash.jpg',
      importedAt: 1000,
      contentHash: 'already-hashed',
    ));
    await photos.addPhoto(PhotoModel(
      themeId: systemId,
      localPath: 'needs-hash.jpg',
      importedAt: 1001,
    ));
    await photos.addPhoto(PhotoModel(
      themeId: systemId,
      localPath: '',
      importedAt: 1002,
    ));

    final pending = await photos.getPhotosMissingHash();
    final names = pending.map((photo) => photo.localPath).toList();
    expect(names, contains('needs-hash.jpg'));
    expect(names, isNot(contains('with-hash.jpg')));
    expect(names, isNot(contains('')));
  });

  test('图库照片移入相册后同时归属原相册与目标相册', () async {
    final target = await themes.createTheme('旅行');
    final photo = await _addPhoto(photos, systemId, 'move-me.jpg', 4000);

    final result = await photos.addCategories([photo.id!], [target.id!]);
    expect(result.successCount, 1);

    final inTarget =
        await photos.searchPhotos(PhotoFilter(categoryIds: {target.id!}));
    expect(inTarget.single.id, photo.id);
    // 多对多语义：照片仍归属原（系统）相册，图库列表不受影响。
    final inSystem =
        await photos.searchPhotos(PhotoFilter(categoryIds: {systemId}));
    expect(inSystem.map((p) => p.id), contains(photo.id));
  });
}

Future<PhotoModel> _addPhoto(
    PhotoRepository repository, int themeId, String name, int importedAt) {
  return repository.addPhoto(PhotoModel(
    themeId: themeId,
    localPath: '',
    originalName: name,
    importedAt: importedAt,
    mimeType: name.split('.').last,
    width: 100,
    height: 200,
  ));
}
