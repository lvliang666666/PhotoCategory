import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class AppLockController extends ChangeNotifier {
  static const int pinLength = 6;
  static const int _hashRounds = 12000;
  static const int _maxFailures = 5;
  static const Duration backgroundRelockDelay = Duration(seconds: 30);
  static const Duration failureLockDuration = Duration(seconds: 30);

  bool _enabled = false;
  bool _unlocked = true;
  String? _salt;
  String? _hash;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  DateTime? _backgroundedAt;

  bool get enabled => _enabled;
  bool get isUnlocked => !_enabled || _unlocked;
  int get failedAttempts => _failedAttempts;
  int get remainingAttempts =>
      (_maxFailures - _failedAttempts).clamp(0, _maxFailures).toInt();
  Duration get lockRemaining {
    final until = _lockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(AppConstants.prefAppLockEnabled) ?? false;
    _salt = prefs.getString(AppConstants.prefAppLockSalt);
    _hash = prefs.getString(AppConstants.prefAppLockHash);
    if (_enabled && (_salt == null || _hash == null)) {
      _enabled = false;
      await prefs.setBool(AppConstants.prefAppLockEnabled, false);
    }
    _unlocked = !_enabled;
    notifyListeners();
  }

  Future<void> enable(String pin) async {
    _validatePin(pin);
    _salt = _newSalt();
    _hash = _deriveHash(pin, _salt!);
    _enabled = true;
    _unlocked = true;
    _failedAttempts = 0;
    _lockedUntil = null;
    await _persist();
    notifyListeners();
  }

  Future<void> changePin(String pin) async {
    if (!_enabled) throw StateError('应用锁尚未开启');
    await enable(pin);
  }

  Future<void> disable() async {
    _enabled = false;
    _unlocked = true;
    _salt = null;
    _hash = null;
    _failedAttempts = 0;
    _lockedUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefAppLockSalt);
    await prefs.remove(AppConstants.prefAppLockHash);
    await prefs.setBool(AppConstants.prefAppLockEnabled, false);
    notifyListeners();
  }

  Future<bool> verifyPin(String pin, {bool unlockApp = false}) async {
    if (!_enabled || _salt == null || _hash == null) return true;
    if (lockRemaining > Duration.zero) {
      notifyListeners();
      return false;
    }
    _lockedUntil = null;
    if (!_isValidPin(pin)) return false;
    final matches = _constantTimeEquals(_deriveHash(pin, _salt!), _hash!);
    if (matches) {
      _failedAttempts = 0;
      if (unlockApp) _unlocked = true;
      notifyListeners();
      return true;
    }

    _failedAttempts++;
    if (_failedAttempts >= _maxFailures) {
      _failedAttempts = 0;
      _lockedUntil = DateTime.now().add(failureLockDuration);
    }
    notifyListeners();
    return false;
  }

  void lock() {
    if (!_enabled || !_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }

  void markBackgrounded() {
    if (_enabled) _backgroundedAt = DateTime.now();
  }

  void handleResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (_enabled &&
        backgroundedAt != null &&
        DateTime.now().difference(backgroundedAt) >= backgroundRelockDelay) {
      lock();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefAppLockEnabled, _enabled);
    await prefs.setString(AppConstants.prefAppLockSalt, _salt!);
    await prefs.setString(AppConstants.prefAppLockHash, _hash!);
  }

  static void _validatePin(String pin) {
    if (!_isValidPin(pin)) throw const FormatException('密码必须是六位数字');
  }

  static bool _isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  static String _newSalt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  static String _deriveHash(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
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
