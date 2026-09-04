import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/private_album_repository.dart';
import '../constants/app_constants.dart';

class PrivateAlbumController extends ChangeNotifier {
  final PrivateAlbumRepository _repository = PrivateAlbumRepository();
  final Set<int> _unlockedRoots = <int>{};
  bool _showPrivateAlbums = true;

  bool get showPrivateAlbums => _showPrivateAlbums;

  bool isRootUnlocked(int rootThemeId) => _unlockedRoots.contains(rootThemeId);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _showPrivateAlbums =
        prefs.getBool(AppConstants.prefPrivateAlbumsVisible) ?? true;
    notifyListeners();
  }

  Future<void> setShowPrivateAlbums(bool value) async {
    if (_showPrivateAlbums == value) return;
    _showPrivateAlbums = value;
    if (!value) lockAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefPrivateAlbumsVisible, value);
    notifyListeners();
  }

  Future<int?> rootThemeId(int themeId) => _repository.rootThemeId(themeId);

  Future<bool> requiresUnlock(int themeId) async {
    final rootId = await _repository.rootThemeId(themeId);
    return rootId != null && !_unlockedRoots.contains(rootId);
  }

  Future<bool> verifyAndUnlock(int themeId, String password) async {
    final rootId = await _repository.rootThemeId(themeId);
    if (rootId == null) return true;
    final verified = await _repository.verifyPassword(themeId, password);
    if (verified) {
      _unlockedRoots.add(rootId);
      notifyListeners();
    }
    return verified;
  }

  Future<void> setPassword(int rootThemeId, String password) async {
    await _repository.setPassword(rootThemeId, password);
    _unlockedRoots.add(rootThemeId);
    notifyListeners();
  }

  void lockAll() {
    if (_unlockedRoots.isEmpty) return;
    _unlockedRoots.clear();
    notifyListeners();
  }
}
