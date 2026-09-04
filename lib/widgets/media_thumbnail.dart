import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/models/photo_model.dart';

class MediaThumbnail extends StatelessWidget {
  final PhotoModel photo;
  final BoxFit fit;

  const MediaThumbnail({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (!photo.isAvailable) return _placeholder(context, Icons.link_off);
    if (photo.mediaId != null) {
      return FutureBuilder<AssetEntity?>(
        future: AssetEntity.fromId(photo.mediaId!),
        builder: (context, entitySnapshot) {
          final entity = entitySnapshot.data;
          if (entity == null) {
            return entitySnapshot.connectionState == ConnectionState.waiting
                ? _placeholder(context, Icons.image_outlined)
                : _placeholder(context, Icons.link_off);
          }
          return FutureBuilder<MemoryImage?>(
            future: entity
                .thumbnailDataWithSize(const ThumbnailSize.square(360),
                    quality: 82)
                .then((bytes) => bytes == null ? null : MemoryImage(bytes)),
            builder: (context, imageSnapshot) {
              final image = imageSnapshot.data;
              return image == null
                  ? _placeholder(context, Icons.image_outlined)
                  : Image(image: image, fit: fit, gaplessPlayback: true);
            },
          );
        },
      );
    }
    if (photo.localPath.isNotEmpty) {
      return Image.file(
        File(photo.localPath),
        fit: fit,
        cacheWidth: 360,
        errorBuilder: (_, __, ___) => _placeholder(context, Icons.link_off),
      );
    }
    return _placeholder(context, Icons.broken_image_outlined);
  }

  Widget _placeholder(BuildContext context, IconData icon) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(icon, color: Theme.of(context).colorScheme.outline),
      );
}
