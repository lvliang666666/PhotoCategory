import 'photo_model.dart';

class PhotoFilter {
  final String query;
  final Set<int> categoryIds;
  final Set<int> tagIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String> formats;
  final bool? favorite;
  final String? orientation;
  final bool onlyUnclassified;
  final Set<PhotoSourceType> sourceTypes;
  final bool includePrivate;

  const PhotoFilter({
    this.query = '',
    this.categoryIds = const {},
    this.tagIds = const {},
    this.startDate,
    this.endDate,
    this.formats = const {},
    this.favorite,
    this.orientation,
    this.onlyUnclassified = false,
    this.sourceTypes = const {},
    this.includePrivate = false,
  });

  bool get isEmpty =>
      query.trim().isEmpty &&
      categoryIds.isEmpty &&
      tagIds.isEmpty &&
      startDate == null &&
      endDate == null &&
      formats.isEmpty &&
      favorite == null &&
      orientation == null &&
      !onlyUnclassified;

  int get activeCount => [
        query.trim().isNotEmpty,
        categoryIds.isNotEmpty,
        tagIds.isNotEmpty,
        startDate != null || endDate != null,
        formats.isNotEmpty,
        favorite != null,
        orientation != null,
        onlyUnclassified,
      ].where((value) => value).length;

  PhotoFilter copyWith({
    String? query,
    Set<int>? categoryIds,
    Set<int>? tagIds,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
    Set<String>? formats,
    bool? favorite,
    bool clearFavorite = false,
    String? orientation,
    bool clearOrientation = false,
    bool? onlyUnclassified,
    Set<PhotoSourceType>? sourceTypes,
    bool? includePrivate,
  }) =>
      PhotoFilter(
        query: query ?? this.query,
        categoryIds: categoryIds ?? this.categoryIds,
        tagIds: tagIds ?? this.tagIds,
        startDate: clearDates ? null : (startDate ?? this.startDate),
        endDate: clearDates ? null : (endDate ?? this.endDate),
        formats: formats ?? this.formats,
        favorite: clearFavorite ? null : (favorite ?? this.favorite),
        orientation:
            clearOrientation ? null : (orientation ?? this.orientation),
        onlyUnclassified: onlyUnclassified ?? this.onlyUnclassified,
        sourceTypes: sourceTypes ?? this.sourceTypes,
        includePrivate: includePrivate ?? this.includePrivate,
      );
}
