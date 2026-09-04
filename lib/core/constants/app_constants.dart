class AppConstants {
  AppConstants._();

  static const String appName = '相册分类';

  static const String dbName = 'photo_storer.db';
  static const int dbVersion = 10;

  static const String photosDirName = 'photos';
  static const String coversDirName = 'album_covers';

  static const String systemThemeName = '未分类';

  static const String prefThemeColorIndex = 'theme_color_index';
  static const String prefFirstUseCompleted = 'first_use_completed';
  static const String prefAppLockEnabled = 'app_lock_enabled';
  static const String prefAppLockSalt = 'app_lock_salt';
  static const String prefAppLockHash = 'app_lock_hash';
  static const String prefPrivateAlbumsVisible = 'private_albums_visible';

  static const int thumbnailCacheWidth = 200;
  static const int homeGridColumns = 2;
  static const int detailGridColumns = 3;

  static const int maxThemeNameLength = 30;
  static const int recentViewsLimit = 200;
  static const int maxPhotoStoryLength = 2000;
  static const int maxAlbumDescriptionLength = 500;
  static const int libraryPageSize = 80;
  static const int defaultCategoryColor = 0xFFF39A82;
  static const String defaultCategoryIcon = 'album';
}
