import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/photo_model.dart';
import '../../data/models/theme_model.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/theme_repository.dart';
import '../../data/services/album_cover_service.dart';
import '../../data/services/album_archive_service.dart';
import '../../data/services/photo_import_service.dart';
import '../../data/services/photo_export_service.dart';

class ThemeDetailController extends ChangeNotifier {
  final ThemeRepository _themeRepository = ThemeRepository();
  final PhotoRepository _photoRepository = PhotoRepository();
  final PhotoImportService _importService = PhotoImportService();
  final PhotoExportService _exportService = PhotoExportService();
  final AlbumCoverService _coverService = AlbumCoverService();
  final AlbumArchiveService _archiveService = AlbumArchiveService();

  ThemeModel? _theme;
  int _photoCount = 0;
  String? _coverPath;
  PhotoModel? _coverPhoto;
  List<PhotoModel> _photos = [];
  List<ThemeModel> _subAlbums = [];
  final Map<int, int> _subAlbumCounts = {};
  final Map<int, String?> _subAlbumCoverPaths = {};
  final Map<int, String?> _subAlbumCoverMediaIds = {};
  final Set<int> _selectedIds = {};
  bool _isLoading = false;
  bool _isImporting = false;
  bool _isExporting = false;
  bool _isArchiving = false;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _isOperating = false;
  int _importProgress = 0;
  int _importTotal = 0;
  int _exportProgress = 0;
  int _exportTotal = 0;
  String? _error;

  ThemeModel? get theme => _theme;
  int get photoCount => _photoCount;
  String? get coverPath => _coverPath;
  PhotoModel? get coverPhoto => _coverPhoto;
  List<PhotoModel> get photos => _photos;
  List<ThemeModel> get subAlbums => _subAlbums;
  Map<int, int> get subAlbumCounts => _subAlbumCounts;
  Map<int, String?> get subAlbumCoverPaths => _subAlbumCoverPaths;
  Map<int, String?> get subAlbumCoverMediaIds => _subAlbumCoverMediaIds;
  Set<int> get selectedIds => Set.unmodifiable(_selectedIds);
  List<PhotoModel> get selectedPhotos =>
      _photos.where((photo) => _selectedIds.contains(photo.id)).toList();
  bool get isLoading => _isLoading;
  bool get isImporting => _isImporting;
  bool get isExporting => _isExporting;
  bool get isArchiving => _isArchiving;
  bool get isLoadingMore => _isLoadingMore;
  bool get isRefreshing => _isRefreshing;
  bool get isOperating => _isOperating;
  bool get isSelecting => _selectedIds.isNotEmpty;
  bool get hasMore => _photos.length < _photoCount;
  int get importProgress => _importProgress;
  int get importTotal => _importTotal;
  int get exportProgress => _exportProgress;
  int get exportTotal => _exportTotal;
  String? get error => _error;

  Future<void> loadTheme(int themeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _theme = await _themeRepository.getThemeById(themeId);
      if (_theme == null) {
        _error = '主题不存在';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _refreshData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '加载主题失败';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshData() async {
    if (_theme == null) return;

    // Load photos
    _photos = await _photoRepository.getPhotosByTheme(_theme!.id!);
    _photoCount = await _themeRepository.getPhotoCount(_theme!.id!);
    _subAlbums = _theme!.parentId == null
        ? await _themeRepository.getSubAlbums(_theme!.id!)
        : <ThemeModel>[];
    _subAlbumCounts.clear();
    _subAlbumCoverPaths.clear();
    _subAlbumCoverMediaIds.clear();
    for (final album in _subAlbums) {
      _subAlbumCounts[album.id!] =
          await _themeRepository.getPhotoCount(album.id!);
      PhotoModel? albumCover;
      if (album.coverPhotoId != null) {
        albumCover = await _photoRepository.getPhotoById(album.coverPhotoId!);
      }
      albumCover ??= await _photoRepository.getLatestPhoto(album.id!);
      _subAlbumCoverPaths[album.id!] =
          album.coverImagePath ?? albumCover?.localPath;
      _subAlbumCoverMediaIds[album.id!] =
          album.coverImagePath == null ? albumCover?.mediaId : null;
    }

    // Determine cover path
    PhotoModel? coverPhoto;
    if (_theme!.coverImagePath == null && _theme!.coverPhotoId != null) {
      coverPhoto = await _photoRepository.getPhotoById(_theme!.coverPhotoId!);
      if (coverPhoto == null) {
        // Cover photo was deleted; reset
        await _themeRepository.setCoverPhoto(_theme!.id!, null);
        _theme = _theme!.copyWith(clearCover: true);
      }
    }

    if (_theme!.coverImagePath == null &&
        coverPhoto == null &&
        _photos.isNotEmpty) {
      coverPhoto = _photos.first;
    }

    _coverPhoto = coverPhoto;
    _coverPath = _theme!.coverImagePath ?? coverPhoto?.localPath;
  }

  Future<bool> createSubAlbum(String name,
      {int colorValue = 0xFFF39A82, String iconKey = 'album'}) async {
    if (_theme == null || _theme!.parentId != null || _theme!.isSystem) {
      return false;
    }
    try {
      await _themeRepository.createTheme(
        name,
        parentId: _theme!.id!,
        colorValue: colorValue,
        iconKey: iconKey,
      );
      await _refreshData();
      notifyListeners();
      return true;
    } catch (_) {
      _error = '创建失败，分类名称可能已存在';
      notifyListeners();
      return false;
    }
  }

  Future<PhotoExportResult> exportAllPhotos() async {
    if (_theme == null || _isExporting) {
      return const PhotoExportResult(successCount: 0, failCount: 0);
    }
    _isExporting = true;
    _exportProgress = 0;
    final exportPhotos = await _photoRepository.getPhotosByTheme(
      _theme!.id!,
      limit: _photoCount,
    );
    _exportTotal = exportPhotos.length;
    notifyListeners();
    final result = await _exportService.exportPhotos(
      photos: exportPhotos,
      albumName: _theme!.name,
      onProgress: (current, total) {
        _exportProgress = current;
        _exportTotal = total;
        notifyListeners();
      },
    );
    _isExporting = false;
    notifyListeners();
    return result;
  }

  Future<bool> exportPhoto(PhotoModel photo) async {
    if (_theme == null) return false;
    return _exportService.exportPhoto(photo, albumName: _theme!.name);
  }

  Future<AlbumArchiveResult> createAlbumArchive() async {
    if (_theme == null) throw StateError('相册尚未加载');
    if (_isArchiving) throw StateError('正在创建压缩包');
    _isArchiving = true;
    notifyListeners();
    try {
      final archivePhotos = await _photoRepository.getPhotosByTheme(
        _theme!.id!,
        limit: _photoCount,
      );
      return await _archiveService.createArchive(
        albumName: _theme!.name,
        photoPaths: archivePhotos.map((photo) => photo.localPath).toList(),
      );
    } finally {
      _isArchiving = false;
      notifyListeners();
    }
  }

  Future<void> shareAlbumArchive(AlbumArchiveResult archive) async {
    if (_theme == null) return;
    await _archiveService.shareArchive(archive, _theme!.name);
  }

  /// Import photos from system picker paths into the current theme.
  /// Shows progress via [isImporting], [importProgress], [importTotal].
  /// Returns the import result with success/failure counts.
  Future<PhotoImportResult> importPhotos(List<String> sourcePaths) async {
    if (_theme == null) {
      return const PhotoImportResult(
        successCount: 0,
        failCount: 0,
        errors: ['主题未加载'],
      );
    }

    // Prevent concurrent imports
    if (_isImporting) {
      return const PhotoImportResult(
        successCount: 0,
        failCount: 0,
        errors: ['导入正在进行中'],
      );
    }

    _isImporting = true;
    _importProgress = 0;
    _importTotal = sourcePaths.length;
    notifyListeners();

    final result = await _importService.importPhotos(
      sourcePaths: sourcePaths,
      themeId: _theme!.id!,
      additionalThemeIds:
          _theme!.parentId == null ? const [] : [_theme!.parentId!],
      onProgress: (current, total) {
        _importProgress = current;
        _importTotal = total;
        notifyListeners();
      },
    );

    // Reload data after import
    await _refreshData();

    _isImporting = false;
    notifyListeners();

    return result;
  }

  /// Set a photo as this theme's cover.
  Future<bool> setCoverPhoto(int photoId) async {
    if (_theme == null) return false;
    try {
      final success =
          await _themeRepository.setCoverPhoto(_theme!.id!, photoId);
      if (success) {
        _theme = _theme!.copyWith(
          coverPhotoId: photoId,
          clearCoverImage: true,
        );
        final photo = await _photoRepository.getPhotoById(photoId);
        if (photo != null) {
          _coverPath = photo.localPath;
          _coverPhoto = photo;
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Save an independently selected image as the album cover without adding
  /// it to the album's photo list.
  Future<bool> setExternalCover(String sourcePath) async {
    if (_theme == null) return false;
    try {
      final savedPath = await _coverService.saveCover(
        sourcePath,
        previousPath: _theme!.coverImagePath,
      );
      final success =
          await _themeRepository.setCoverImagePath(_theme!.id!, savedPath);
      if (!success) return false;
      _theme = _theme!.copyWith(
        clearCover: true,
        coverImagePath: savedPath,
      );
      _coverPhoto = null;
      _coverPath = savedPath;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Load all photos in this category for the dedicated cover picker.
  Future<List<PhotoModel>> getCoverCandidates() async {
    if (_theme == null || _photoCount == 0) return const [];
    return _photoRepository.getPhotosByTheme(
      _theme!.id!,
      limit: _photoCount,
    );
  }

  /// Removes a photo from this category without touching the device original.
  Future<bool> deletePhoto(int photoId) async {
    if (_theme == null) return false;
    try {
      final result =
          await _photoRepository.removeCategories([photoId], [_theme!.id!]);
      if (result.failCount > 0) return false;

      // If this was the cover photo, reset
      if (_theme!.coverPhotoId == photoId) {
        await _themeRepository.setCoverPhoto(_theme!.id!, null);
        _theme = _theme!.copyWith(clearCover: true);
      }

      await _refreshData();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Move an association to another category without moving the original file.
  Future<bool> movePhoto(int photoId, int targetThemeId) async {
    if (_theme == null) return false;
    try {
      // If moving within the same theme, do nothing
      if (_theme!.id == targetThemeId) return false;

      final success = await _photoRepository.movePhoto(photoId, targetThemeId);
      if (!success) return false;
      final removed =
          await _photoRepository.removeCategories([photoId], [_theme!.id!]);
      if (removed.failCount > 0) return false;

      // If this was the cover photo, reset cover on the source theme
      if (_theme!.coverPhotoId == photoId) {
        await _themeRepository.setCoverPhoto(_theme!.id!, null);
        _theme = _theme!.copyWith(clearCover: true);
      }

      await _refreshData();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Return the full hierarchy. The picker disables the current album while
  /// keeping its parent visible so sibling sub-albums remain reachable.
  Future<List<ThemeModel>> getOtherThemes() async {
    return _themeRepository.getAllThemes();
  }

  Future<bool> renameTheme(String newName) async {
    if (_theme == null) return false;
    try {
      final success = await _themeRepository.renameTheme(_theme!.id!, newName);
      if (success) {
        _theme = _theme!.copyWith(name: newName.trim());
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = '重命名失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDescription(String value) async {
    if (_theme?.id == null) return false;
    if (value.length > AppConstants.maxAlbumDescriptionLength) return false;
    final success =
        await _themeRepository.updateDescription(_theme!.id!, value);
    if (success) {
      _theme = _theme!.copyWith(description: value.trim());
      notifyListeners();
    }
    return success;
  }

  void toggleSelection(int photoId) {
    _selectedIds.contains(photoId)
        ? _selectedIds.remove(photoId)
        : _selectedIds.add(photoId);
    notifyListeners();
  }

  void selectAll() {
    _selectedIds.addAll(_photos.map((photo) => photo.id).whereType<int>());
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }

  Future<BatchOperationResult> setSelectedFavorite(bool value) {
    return _performBatch(
      () => _photoRepository.setFavorite(_selectedIds.toList(), value),
    );
  }

  Future<BatchOperationResult> addSelectedToCategory(int categoryId) {
    return _performBatch(
      () => _photoRepository.addCategories(
        _selectedIds.toList(),
        [categoryId],
      ),
    );
  }

  Future<BatchOperationResult> removeSelectedFromCurrentAlbum() {
    if (_theme?.id == null) {
      return Future.value(const BatchOperationResult(
        successCount: 0,
        failCount: 0,
      ));
    }
    return _performBatch(
      () => _photoRepository.removeCategories(
        _selectedIds.toList(),
        [_theme!.id!],
      ),
    );
  }

  Future<BatchOperationResult> _performBatch(
      Future<BatchOperationResult> Function() action) async {
    if (_isOperating || _selectedIds.isEmpty) {
      return const BatchOperationResult(successCount: 0, failCount: 0);
    }
    _isOperating = true;
    notifyListeners();
    try {
      final result = await action();
      _selectedIds
        ..clear()
        ..addAll(result.failedPhotoIds);
      await _refreshData();
      return result;
    } finally {
      _isOperating = false;
      notifyListeners();
    }
  }

  Future<bool> renameThemeById(int id, String newName,
      {int? colorValue, String? iconKey}) async {
    try {
      final success = await _themeRepository.renameTheme(
        id,
        newName,
        colorValue: colorValue,
        iconKey: iconKey,
      );
      if (success) await _refreshData();
      notifyListeners();
      return success;
    } catch (e) {
      _error = e is DuplicateCategoryNameException ? '分类名称已存在' : '重命名失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteThemeById(int id) async {
    final success = await _themeRepository.deleteTheme(id);
    if (success) await _refreshData();
    notifyListeners();
    return success;
  }

  Future<bool> deleteTheme() async {
    if (_theme == null) return false;
    try {
      final success = await _themeRepository.deleteTheme(_theme!.id!);
      return success;
    } catch (e) {
      _error = '删除失败';
      notifyListeners();
      return false;
    }
  }

  Future<void> refresh() async {
    if (_theme == null || _isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      await _refreshData();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_theme == null || _isLoadingMore || !hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _photoRepository.getPhotosByTheme(
        _theme!.id!,
        offset: _photos.length,
      );
      final existing = _photos.map((photo) => photo.id).toSet();
      _photos = [
        ..._photos,
        ...page.where((photo) => !existing.contains(photo.id)),
      ];
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> recordView(PhotoModel photo) async {
    if (photo.id != null) await _photoRepository.recordView(photo.id!);
  }

  Future<bool> toggleFavorite(PhotoModel photo) async {
    if (photo.id == null) return false;
    final result =
        await _photoRepository.setFavorite([photo.id!], !photo.isFavorite);
    if (result.failCount > 0) return false;
    await _refreshData();
    notifyListeners();
    return true;
  }
}
