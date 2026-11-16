import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/photo_filter.dart';
import '../../data/models/photo_model.dart';
import '../../data/models/tag_model.dart';
import '../../data/models/theme_model.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/theme_repository.dart';
import '../../data/services/photo_deletion_service.dart';
import '../../data/services/photo_import_service.dart';

enum SmartAlbum { all, favorites, recentViews, recentlyAdded }

class LibraryController extends ChangeNotifier {
  final PhotoRepository _photos = PhotoRepository();
  final ThemeRepository _themes = ThemeRepository();
  final TagRepository _tags = TagRepository();
  final PhotoDeletionService _deletion = PhotoDeletionService();
  final PhotoImportService _import = PhotoImportService();

  List<PhotoModel> photos = [];
  List<ThemeModel> categories = [];
  List<TagModel> tags = [];
  PhotoFilter filter = const PhotoFilter();
  SmartAlbum smartAlbum = SmartAlbum.all;
  bool groupByTime = false;
  bool isLoading = false;
  bool isOperating = false;
  bool isLoadingMore = false;
  bool isImporting = false;
  int importProgress = 0;
  int importTotal = 0;
  int totalCount = 0;
  String? error;
  final Set<int> selectedIds = {};
  Timer? _searchTimer;

  bool get isSelecting => selectedIds.isNotEmpty;
  bool get hasMore => photos.length < totalCount;
  Set<PhotoSourceType> get _visibleSources =>
      const {PhotoSourceType.imported, PhotoSourceType.appGenerated};

  PhotoFilter get _effectiveFilter =>
      filter.copyWith(sourceTypes: _visibleSources);

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _initializeData().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      error = '图库加载超时，请点击重试';
    } catch (_) {
      error = '加载照片失败，请稍后重试';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeData() async {
    categories = (await _themes.getAllThemes())
        .where((theme) => !theme.isPrivate)
        .toList();
    tags = await _tags.getTags();
    await _loadPhotos(reset: true);
  }

  Future<void> _loadPhotos({required bool reset}) async {
    final offset = reset ? 0 : photos.length;
    final sourceTypes = _visibleSources;
    final effective = _effectiveFilter;
    late final List<PhotoModel> page;
    switch (smartAlbum) {
      case SmartAlbum.recentViews:
        totalCount = await _photos.countRecentViews(sourceTypes: sourceTypes);
        page = await _photos.getRecentViews(
          limit: AppConstants.libraryPageSize,
          offset: offset,
          sourceTypes: sourceTypes,
        );
      case SmartAlbum.recentlyAdded:
        totalCount = await _photos.countPhotos(
          PhotoFilter(sourceTypes: sourceTypes),
        );
        page = await _photos.getRecentlyAdded(
          limit: AppConstants.libraryPageSize,
          offset: offset,
          sourceTypes: sourceTypes,
        );
      case SmartAlbum.favorites:
        final favoriteFilter = effective.copyWith(favorite: true);
        totalCount = await _photos.countPhotos(favoriteFilter);
        page = await _photos.searchPhotos(
          favoriteFilter,
          limit: AppConstants.libraryPageSize,
          offset: offset,
        );
      case SmartAlbum.all:
        totalCount = await _photos.countPhotos(effective);
        page = await _photos.searchPhotos(
          effective,
          limit: AppConstants.libraryPageSize,
          offset: offset,
        );
    }
    if (reset) {
      photos = page;
    } else {
      final existing = photos.map((photo) => photo.id).toSet();
      photos = [
        ...photos,
        ...page.where((photo) => !existing.contains(photo.id))
      ];
    }
  }

  void setQuery(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 280), () async {
      filter = filter.copyWith(query: query);
      await refresh();
    });
  }

  Future<void> applyFilter(PhotoFilter value) async {
    filter = value;
    await refresh();
  }

  Future<void> clearFilter() async {
    filter = const PhotoFilter();
    await refresh();
  }

  Future<void> selectSmartAlbum(SmartAlbum value) async {
    smartAlbum = value;
    selectedIds.clear();
    await refresh();
  }

  /// Toggle the "group by month" view mode. Pure view switch — the photo
  /// list is already sorted by time, so no reload is needed.
  void toggleGroupByTime() {
    groupByTime = !groupByTime;
    notifyListeners();
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _loadPhotos(reset: true).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      error = '图库刷新超时，请稍后重试';
    } catch (_) {
      error = '图库刷新失败，请稍后重试';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Reload the current page of photos without toggling the full-screen
  /// loading state. Used when a kept-alive tab becomes visible again so new
  /// imports show up without a loading flash.
  Future<void> silentRefresh() async {
    try {
      await _loadPhotos(reset: true).timeout(const Duration(seconds: 12));
    } catch (_) {
      // Keep showing the previous content on failure.
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      await _loadPhotos(reset: false);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<PhotoImportResult> importPhotos(List<String> sourcePaths) async {
    if (isImporting || sourcePaths.isEmpty) {
      return const PhotoImportResult(
        successCount: 0,
        failCount: 0,
        errors: [],
      );
    }
    final hiddenLibraryTheme = await _themes.getUncategorizedTheme();
    if (hiddenLibraryTheme?.id == null) {
      return const PhotoImportResult(
        successCount: 0,
        failCount: 0,
        errors: ['图库初始化失败'],
      );
    }

    isImporting = true;
    importProgress = 0;
    importTotal = sourcePaths.length;
    notifyListeners();
    try {
      final result = await _import.importPhotos(
        sourcePaths: sourcePaths,
        themeId: hiddenLibraryTheme!.id!,
        onProgress: (current, total) {
          importProgress = current;
          importTotal = total;
          notifyListeners();
        },
      );
      await _loadPhotos(reset: true);
      return result;
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }

  void toggleSelection(int id) {
    selectedIds.contains(id) ? selectedIds.remove(id) : selectedIds.add(id);
    notifyListeners();
  }

  void selectAll() {
    selectedIds.addAll(photos.map((p) => p.id).whereType<int>());
    notifyListeners();
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  List<PhotoModel> get selectedPhotos =>
      photos.where((p) => selectedIds.contains(p.id)).toList();

  Future<BatchOperationResult> setSelectedFavorite(bool value) =>
      _perform(() => _photos.setFavorite(selectedIds.toList(), value));

  Future<BatchOperationResult> addSelectedCategories(List<int> ids) =>
      _perform(() => _photos.addCategories(selectedIds.toList(), ids));

  /// Move the selected photos into a single album (adds them to it; photos
  /// may belong to multiple albums, so they stay visible in the library).
  Future<BatchOperationResult> moveSelectedToTheme(int themeId) =>
      _perform(() => _photos.addCategories(selectedIds.toList(), [themeId]));

  Future<BatchOperationResult> removeSelectedCategories(List<int> ids) =>
      _perform(() => _photos.removeCategories(selectedIds.toList(), ids));

  Future<BatchOperationResult> addSelectedTags(List<int> ids) =>
      _perform(() => _photos.addTags(selectedIds.toList(), ids));

  Future<BatchOperationResult> removeSelectedTags(List<int> ids) =>
      _perform(() => _photos.removeTags(selectedIds.toList(), ids));

  Future<BatchOperationResult> deleteSelected() async {
    isOperating = true;
    notifyListeners();
    try {
      final result = await _deletion.deleteImportedPhotos(selectedPhotos);
      selectedIds
        ..clear()
        ..addAll(result.failedPhotoIds);
      await _loadPhotos(reset: true);
      return result;
    } finally {
      isOperating = false;
      notifyListeners();
    }
  }

  Future<void> recordView(PhotoModel photo) async {
    if (photo.id != null) await _photos.recordView(photo.id!);
  }

  Future<int> cleanUnavailable() async {
    final count = await _photos.cleanUnavailable();
    await refresh();
    return count;
  }

  Future<BatchOperationResult> _perform(
      Future<BatchOperationResult> Function() action) async {
    isOperating = true;
    notifyListeners();
    try {
      final result = await action();
      selectedIds
        ..clear()
        ..addAll(result.failedPhotoIds);
      await _loadPhotos(reset: true);
      return result;
    } finally {
      isOperating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
