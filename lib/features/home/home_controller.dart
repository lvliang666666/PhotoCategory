import 'package:flutter/material.dart';

import '../../data/models/theme_model.dart';
import '../../data/models/virtual_album_rules.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/theme_repository.dart';

class HomeController extends ChangeNotifier {
  final ThemeRepository _themeRepository = ThemeRepository();
  final PhotoRepository _photoRepository = PhotoRepository();

  List<ThemeModel> _themes = [];
  List<ThemeModel> _allThemes = [];
  Map<int, String> _searchIndex = {};
  Map<int, int> _photoCounts = {};
  Map<int, String?> _coverPaths = {};
  Map<int, String?> _coverMediaIds = {};
  Map<int, int> _subAlbumCounts = {};
  bool _isLoading = false;
  String? _error;

  List<ThemeModel> get themes => _themes;
  List<ThemeModel> get allThemes => _allThemes;
  Map<int, int> get photoCounts => _photoCounts;
  Map<int, String?> get coverPaths => _coverPaths;
  Map<int, String?> get coverMediaIds => _coverMediaIds;
  Map<int, int> get subAlbumCounts => _subAlbumCounts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<ThemeModel> searchThemes(String query, {bool includePrivate = true}) {
    final normalized = query.trim().toLowerCase();
    final source = normalized.isEmpty ? _themes : _allThemes;
    return source.where((theme) {
      if (!includePrivate && theme.isPrivate) return false;
      final terms = _searchIndex[theme.id] ?? theme.name.toLowerCase();
      return normalized.isEmpty || terms.contains(normalized);
    }).toList();
  }

  String? parentNameOf(ThemeModel theme) {
    final parentId = theme.parentId;
    if (parentId == null) return null;
    for (final candidate in _allThemes) {
      if (candidate.id == parentId) return candidate.name;
    }
    return null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadThemes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _themes = await _themeRepository.getThemes();
      _allThemes = await _themeRepository.getAllThemes();
      _searchIndex = await _themeRepository.getThemeSearchIndex();

      // Load photo counts and cover paths for each theme
      _photoCounts = {};
      _coverPaths = {};
      _coverMediaIds = {};
      _subAlbumCounts = {};

      for (final theme in _allThemes) {
        if (theme.isVirtual) {
          // Virtual albums count and cover from their live rule query —
          // photo_categories has no rows for them.
          final rules = VirtualAlbumRules.decode(theme.virtualRules);
          final filter = rules.toPhotoFilter();
          _photoCounts[theme.id!] = await _photoRepository.countPhotos(filter);
          _subAlbumCounts[theme.id!] = 0;
          final latest =
              await _photoRepository.searchPhotos(filter, limit: 1);
          _coverPaths[theme.id!] = latest.isEmpty ? null : latest.first.localPath;
          _coverMediaIds[theme.id!] =
              latest.isEmpty ? null : latest.first.mediaId;
          continue;
        }

        final count = await _themeRepository.getPhotoCount(theme.id!);
        _photoCounts[theme.id!] = count;
        _subAlbumCounts[theme.id!] =
            await _themeRepository.getSubAlbumCount(theme.id!);

        // Determine cover path
        String? coverPath = theme.coverImagePath;
        if (coverPath == null && theme.coverPhotoId != null) {
          final coverPhoto =
              await _photoRepository.getPhotoById(theme.coverPhotoId!);
          if (coverPhoto != null) {
            coverPath = coverPhoto.localPath;
            _coverMediaIds[theme.id!] = coverPhoto.mediaId;
          } else {
            // Cover photo was deleted; reset cover_photo_id
            await _themeRepository.setCoverPhoto(theme.id!, null);
          }
        }

        if (coverPath == null) {
          final latestPhoto = await _photoRepository.getLatestPhoto(theme.id!);
          coverPath = latestPhoto?.localPath;
          _coverMediaIds[theme.id!] = latestPhoto?.mediaId;
        }

        _coverPaths[theme.id!] = coverPath;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '加载主题失败';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTheme(String name,
      {int colorValue = 0xFFF39A82,
      String iconKey = 'album',
      bool isPrivate = false}) async {
    try {
      await _themeRepository.createTheme(name,
          colorValue: colorValue, iconKey: iconKey, isPrivate: isPrivate);
      await loadThemes();
      return true;
    } on DuplicateCategoryNameException {
      _error = '分类名称已存在';
      notifyListeners();
      return false;
    } on FormatException {
      _error = '分类名称不能为空';
      notifyListeners();
      return false;
    } catch (e) {
      _error = '创建分类失败';
      notifyListeners();
      return false;
    }
  }

  Future<ThemeModel?> createThemeModel(
    String name, {
    int colorValue = 0xFFF39A82,
    String iconKey = 'album',
    bool isPrivate = false,
    bool isVirtual = false,
    String? virtualRules,
  }) async {
    try {
      final created = await _themeRepository.createTheme(
        name,
        colorValue: colorValue,
        iconKey: iconKey,
        isPrivate: isPrivate,
        isVirtual: isVirtual,
        virtualRules: virtualRules,
      );
      await loadThemes();
      return created;
    } on DuplicateCategoryNameException {
      _error = '分类名称已存在';
    } on FormatException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = '创建分类失败';
    }
    notifyListeners();
    return null;
  }

  Future<bool> updateVirtualAlbumRules(int themeId, String rulesJson) async {
    final success = await _themeRepository.updateVirtualRules(
        themeId, rulesJson);
    if (success) await loadThemes();
    return success;
  }

  Future<void> moveTheme(int draggedId, int targetId) async {
    final from = _themes.indexWhere((theme) => theme.id == draggedId);
    final to = _themes.indexWhere((theme) => theme.id == targetId);
    if (from < 0 || to < 0 || from == to) return;
    final previous = List<ThemeModel>.from(_themes);
    final moved = _themes.removeAt(from);
    _themes.insert(to, moved);
    notifyListeners();
    try {
      await _themeRepository.reorderThemes(
        _themes.map((theme) => theme.id!).toList(),
      );
    } catch (_) {
      _themes = previous;
      _error = '排序保存失败';
      notifyListeners();
    }
  }

  Future<bool> renameTheme(int themeId, String newName,
      {int? colorValue, String? iconKey}) async {
    try {
      final success = await _themeRepository.renameTheme(
        themeId,
        newName,
        colorValue: colorValue,
        iconKey: iconKey,
      );
      if (success) {
        await loadThemes();
      }
      return success;
    } on DuplicateCategoryNameException {
      _error = '分类名称已存在';
      notifyListeners();
      return false;
    } on FormatException {
      _error = '分类名称不能为空';
      notifyListeners();
      return false;
    } catch (e) {
      _error = '重命名失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTheme(int themeId) async {
    try {
      final success = await _themeRepository.deleteTheme(themeId);
      if (success) {
        await loadThemes();
      }
      return success;
    } catch (e) {
      _error = '删除主题失败';
      notifyListeners();
      return false;
    }
  }
}
