import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/models/photo_model.dart';

class MediaThumbnail extends StatefulWidget {
  final PhotoModel photo;
  final BoxFit fit;

  const MediaThumbnail({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
  });

  @override
  State<MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<MediaThumbnail> {
  // Futures are created once per photo identity and cached in state. Creating
  // them inside build (the old FutureBuilder pattern) restarted the async
  // work on EVERY parent rebuild — e.g. each tap during multi-select — which
  // made grids with many photos stutter and thumbnails flicker.
  Future<AssetEntity?>? _entityFuture;
  Future<MemoryImage?>? _thumbnailFuture;
  String? _loadedMediaId;

  @override
  void initState() {
    super.initState();
    _loadIfMediaPhoto();
  }

  @override
  void didUpdateWidget(covariant MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo.mediaId != oldWidget.photo.mediaId) {
      _loadIfMediaPhoto();
    }
  }

  void _loadIfMediaPhoto() {
    final mediaId = widget.photo.mediaId;
    if (mediaId == null || mediaId == _loadedMediaId) return;
    _loadedMediaId = mediaId;
    _entityFuture = AssetEntity.fromId(mediaId);
    _thumbnailFuture = _entityFuture!.then((entity) async {
      if (entity == null) return null;
      final bytes = await entity.thumbnailDataWithSize(
        const ThumbnailSize.square(360),
        quality: 82,
      );
      return bytes == null ? null : MemoryImage(bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    if (!photo.isAvailable) return _placeholder(context, Icons.link_off);
    if (photo.mediaId != null) {
      return FutureBuilder<AssetEntity?>(
        future: _entityFuture,
        builder: (context, entitySnapshot) {
          final entity = entitySnapshot.data;
          if (entity == null) {
            return entitySnapshot.connectionState == ConnectionState.waiting
                ? _placeholder(context, Icons.image_outlined)
                : _placeholder(context, Icons.link_off);
          }
          return FutureBuilder<MemoryImage?>(
            future: _thumbnailFuture,
            builder: (context, imageSnapshot) {
              final image = imageSnapshot.data;
              return image == null
                  ? _placeholder(context, Icons.image_outlined)
                  : Image(image: image,
                      fit: widget.fit,
                      gaplessPlayback: true);
            },
          );
        },
      );
    }
    if (photo.localPath.isNotEmpty) {
      return Image.file(
        File(photo.localPath),
        fit: widget.fit,
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
