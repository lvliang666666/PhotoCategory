import 'package:flutter_test/flutter_test.dart';
import 'package:photo_storer/core/security/private_album_controller.dart';
import 'package:photo_storer/data/database/app_database.dart';
import 'package:photo_storer/data/repositories/theme_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ThemeRepository themes;
  late PrivateAlbumController controller;
  late int privateRootId;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await AppDatabase.createSchemaForTesting(db);
    themes = ThemeRepository();
    controller = PrivateAlbumController();
    final theme =
        await themes.createTheme('私密旅行', isPrivate: true);
    privateRootId = theme.id!;
    await controller.setPassword(privateRootId, 'abc123');
  });

  tearDown(() async {
    await AppDatabase.close();
  });

  test('正确密码解锁后 isRootUnlocked 为 true', () async {
    // setPassword 后创建者默认处于已解锁态，先模拟退后台的锁定态。
    controller.lockAll();
    expect(await controller.requiresUnlock(privateRootId), isTrue);
    final verified =
        await controller.verifyAndUnlock(privateRootId, 'abc123');
    expect(verified, isTrue);
    expect(controller.isRootUnlocked(privateRootId), isTrue);
    expect(await controller.requiresUnlock(privateRootId), isFalse);
  });

  test('错误密码不解锁', () async {
    controller.lockAll();
    final verified = await controller.verifyAndUnlock(privateRootId, 'wrong1');
    expect(verified, isFalse);
    expect(controller.isRootUnlocked(privateRootId), isFalse);
    expect(await controller.requiresUnlock(privateRootId), isTrue);
  });

  test('lockAll（退后台触发）清除所有解锁状态，需重新输入密码', () async {
    await controller.verifyAndUnlock(privateRootId, 'abc123');
    expect(controller.isRootUnlocked(privateRootId), isTrue);

    controller.lockAll();
    expect(controller.isRootUnlocked(privateRootId), isFalse);
    expect(await controller.requiresUnlock(privateRootId), isTrue);
  });

  test('子相册共享根相册的解锁状态', () async {
    final sub = await themes.createTheme('私密子相册',
        parentId: privateRootId, isPrivate: true);
    controller.lockAll();
    expect(await controller.requiresUnlock(sub.id!), isTrue);
    // 通过子相册 id 验证，解锁的是根相册。
    final verified = await controller.verifyAndUnlock(sub.id!, 'abc123');
    expect(verified, isTrue);
    expect(controller.isRootUnlocked(privateRootId), isTrue);
    expect(await controller.requiresUnlock(sub.id!), isFalse);
  });
}
