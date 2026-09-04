import 'package:flutter_test/flutter_test.dart';
import 'package:photo_storer/core/security/app_lock_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('six-digit PIN is persisted and unlocks with the correct value',
      () async {
    final controller = AppLockController();
    await controller.load();
    await controller.enable('123456');
    controller.lock();

    expect(controller.enabled, isTrue);
    expect(controller.isUnlocked, isFalse);
    expect(await controller.verifyPin('654321', unlockApp: true), isFalse);
    expect(controller.isUnlocked, isFalse);
    expect(await controller.verifyPin('123456', unlockApp: true), isTrue);
    expect(controller.isUnlocked, isTrue);

    final reloaded = AppLockController();
    await reloaded.load();
    expect(reloaded.enabled, isTrue);
    expect(reloaded.isUnlocked, isFalse);
    expect(await reloaded.verifyPin('123456', unlockApp: true), isTrue);
  });

  test('PIN must contain exactly six digits', () async {
    final controller = AppLockController();
    await controller.load();

    expect(() => controller.enable('12345'), throwsFormatException);
    expect(() => controller.enable('abcdef'), throwsFormatException);
  });
}
