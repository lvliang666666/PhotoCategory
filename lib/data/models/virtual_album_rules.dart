import 'dart:convert';

import 'photo_filter.dart';
import 'photo_model.dart';

/// Rule-based "virtual album" definition. A virtual album owns no photos
/// directly; it materializes the photos matching these rules at read time.
class VirtualAlbumRules {
  final Set<int> tagIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool favorite;

  const VirtualAlbumRules({
    this.tagIds = const {},
    this.startDate,
    this.endDate,
    this.favorite = false,
  });

  bool get isEmpty =>
      tagIds.isEmpty && startDate == null && endDate == null && !favorite;

  Map<String, dynamic> toJson() => {
        'tagIds': tagIds.toList(),
        if (startDate != null)
          'startDate': _dateKey(startDate!),
        if (endDate != null) 'endDate': _dateKey(endDate!),
        if (favorite) 'favorite': true,
      };

  String encode() => jsonEncode(toJson());

  factory VirtualAlbumRules.decode(String? json) {
    if (json == null || json.trim().isEmpty) return const VirtualAlbumRules();
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const VirtualAlbumRules();
      return VirtualAlbumRules(
        tagIds: {
          ...((map['tagIds'] as List<dynamic>? ?? const [])
              .whereType<num>()
              .map((value) => value.toInt())),
        },
        startDate: _parseDate(map['startDate'] as String?),
        endDate: _parseDate(map['endDate'] as String?),
        favorite: map['favorite'] == true,
      );
    } catch (_) {
      return const VirtualAlbumRules();
    }
  }

  /// Filter matching the rules. Source types mirror the library page so the
  /// virtual album shows exactly the photos the user can see elsewhere.
  PhotoFilter toPhotoFilter() => PhotoFilter(
        tagIds: tagIds,
        startDate: startDate,
        endDate: endDate,
        favorite: favorite ? true : null,
        sourceTypes: const {
          PhotoSourceType.imported,
          PhotoSourceType.appGenerated,
        },
      );

  /// Human-readable summary for album cards and detail headers.
  String describe() {
    if (isEmpty) return '未设置规则';
    final parts = <String>[];
    if (tagIds.isNotEmpty) parts.add('按标签');
    if (startDate != null || endDate != null) parts.add(_dateRangeText());
    if (favorite) parts.add('仅收藏');
    return parts.join(' · ');
  }

  String _dateRangeText() {
    final start = startDate;
    final end = endDate;
    if (start != null && end != null) {
      return '${start.year}.${start.month}-${end.year}.${end.month}';
    }
    if (start != null) return '${start.year}年${start.month}月起';
    if (end != null) return '至${end.year}年${end.month}月';
    return '';
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
