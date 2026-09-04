import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_storer/data/models/theme_model.dart';
import 'package:photo_storer/widgets/theme_card.dart';

void main() {
  for (final width in <double>[360, 390, 411]) {
    testWidgets('album card has no overflow at ${width.toInt()}dp',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cardWidth = (width - 32 - 14) / 2;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: cardWidth,
                height: cardWidth / 1.02,
                child: ThemeCard(
                  theme: ThemeModel(
                    name: '我的2026暑假旅行照片和珍贵回忆',
                    createdAt: DateTime(2026).millisecondsSinceEpoch,
                    colorValue: 0xFFF39A82,
                  ),
                  photoCount: 12,
                  subAlbumCount: 3,
                  onTap: () {},
                  onMore: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('12 张 · 3 个子相册'), findsOneWidget);
      expect(find.byTooltip('更多操作'), findsOneWidget);
    });
  }
}
