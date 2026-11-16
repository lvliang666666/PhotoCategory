import 'package:flutter_test/flutter_test.dart';
import 'package:photo_storer/data/models/photo_filter.dart';
import 'package:photo_storer/data/models/photo_model.dart';
import 'package:photo_storer/data/models/virtual_album_rules.dart';

void main() {
  group('VirtualAlbumRules', () {
    test('toJson/fromJson 往返保留全部字段', () {
      final rules = VirtualAlbumRules(
        tagIds: {1, 2},
        startDate: DateTime(2025, 1, 15),
        endDate: DateTime(2025, 12, 31),
        favorite: true,
      );
      final restored = VirtualAlbumRules.decode(rules.encode());
      expect(restored.tagIds, {1, 2});
      expect(restored.startDate, DateTime(2025, 1, 15));
      expect(restored.endDate, DateTime(2025, 12, 31));
      expect(restored.favorite, isTrue);
    });

    test('decode 空值和损坏 JSON 返回空规则', () {
      expect(VirtualAlbumRules.decode(null).isEmpty, isTrue);
      expect(VirtualAlbumRules.decode('').isEmpty, isTrue);
      expect(VirtualAlbumRules.decode('not-json{').isEmpty, isTrue);
      expect(VirtualAlbumRules.decode('[1,2]').isEmpty, isTrue);
    });

    test('toPhotoFilter 映射字段并限定可见来源', () {
      final filter = VirtualAlbumRules(
        tagIds: {3},
        startDate: DateTime(2025, 3, 1),
        endDate: DateTime(2025, 6, 30),
        favorite: true,
      ).toPhotoFilter();
      expect(filter.tagIds, {3});
      expect(filter.startDate, DateTime(2025, 3, 1));
      expect(filter.endDate, DateTime(2025, 6, 30));
      expect(filter.favorite, isTrue);
      expect(
        filter.sourceTypes,
        {PhotoSourceType.imported, PhotoSourceType.appGenerated},
      );
    });

    test('toPhotoFilter 未开启收藏时 favorite 为 null（不过滤）', () {
      expect(VirtualAlbumRules(tagIds: {1}).toPhotoFilter().favorite, isNull);
    });

    test('describe 输出人类可读摘要', () {
      expect(
        const VirtualAlbumRules(tagIds: {1, 2}).describe(),
        '按标签',
      );
      expect(
        const VirtualAlbumRules(favorite: true).describe(),
        '仅收藏',
      );
      expect(
        VirtualAlbumRules(
          startDate: DateTime(2025, 3, 1),
          endDate: DateTime(2025, 6, 30),
        ).describe(),
        '2025.3-2025.6',
      );
      expect(
        const VirtualAlbumRules(
          tagIds: {1},
          favorite: true,
        ).describe(),
        '按标签 · 仅收藏',
      );
      expect(const VirtualAlbumRules().describe(), '未设置规则');
    });

    test('isEmpty 判定空规则', () {
      expect(const VirtualAlbumRules().isEmpty, isTrue);
      expect(const VirtualAlbumRules(tagIds: {1}).isEmpty, isFalse);
      expect(const VirtualAlbumRules(favorite: true).isEmpty, isFalse);
    });
  });
}
