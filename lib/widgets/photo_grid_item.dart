import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

class PhotoGridItem extends StatelessWidget {
  final String localPath;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PhotoGridItem({
    super.key,
    required this.localPath,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Image.file(
        File(localPath),
        fit: BoxFit.cover,
        cacheWidth: AppConstants.thumbnailCacheWidth,
        errorBuilder: (context, error, stackTrace) =>
            _buildBrokenImage(colorScheme),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame == null) {
            // Show nothing while loading (prevents flash of broken icon)
            return Container(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            );
          }
          return child;
        },
      ),
    );
  }

  Widget _buildBrokenImage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 32,
          color: colorScheme.onSurface.withOpacity(0.2),
        ),
      ),
    );
  }
}
