import 'package:flutter/material.dart';

import '../../data/models/photo_model.dart';

class PhotoInfoPage extends StatelessWidget {
  final PhotoModel photo;

  const PhotoInfoPage({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('照片信息')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(photo.displayName,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(
                        label: Text(photo.isAvailable ? '可用' : '不可用'),
                        avatar: Icon(
                          photo.isAvailable
                              ? Icons.check_circle
                              : Icons.link_off,
                          size: 18,
                        )),
                    if (photo.isFavorite)
                      const Chip(
                          label: Text('已收藏'),
                          avatar: Icon(Icons.favorite, size: 18)),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (photo.hasStory) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(Icons.auto_stories_rounded,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('照片故事',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 7),
                          Text(photo.storyText!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.55)),
                          if (photo.storyUpdatedAt != null) ...[
                            const SizedBox(height: 8),
                            Text('更新于 ${_timestamp(photo.storyUpdatedAt)}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Card(
            child: Column(children: [
              _row(context, '图片格式', photo.mimeType ?? '未知'),
              _row(context, '尺寸', _dimensions(photo)),
              _row(context, '方向', _orientation(photo.orientation)),
              _row(context, '拍摄时间', _timestamp(photo.takenAt)),
              _row(context, '导入时间', _timestamp(photo.importedAt)),
              _row(context, '最后同步', _timestamp(photo.lastSeenAt)),
              _row(context, '内容修改时间', _timestamp(photo.contentModifiedAt)),
              if (!photo.isAvailable)
                _row(context, '不可用原因',
                    photo.unavailableReason ?? '原图已删除或访问权限已撤销'),
            ]),
          ),
          if (photo.mediaId != null || photo.localPath.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: Column(children: [
                if (photo.mediaId != null)
                  _row(context, '媒体标识', photo.mediaId!),
                if (photo.localPath.isNotEmpty)
                  _row(context, '应用内路径', photo.localPath),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => ListTile(
        title: Text(label),
        subtitle: Text(value),
        dense: true,
      );

  String _dimensions(PhotoModel value) =>
      value.width == null || value.height == null
          ? '未知'
          : '${value.width} × ${value.height}';

  String _orientation(String value) => switch (value) {
        'landscape' => '横图',
        'portrait' => '竖图',
        'square' => '正方形',
        _ => '未知',
      };

  String _timestamp(int? seconds) {
    if (seconds == null) return '未知';
    final milliseconds = seconds > 100000000000 ? seconds : seconds * 1000;
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
