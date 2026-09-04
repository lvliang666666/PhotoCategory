import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/security/private_album_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/clay_assets.dart';
import '../data/models/theme_model.dart';

class ThemeCard extends StatefulWidget {
  final ThemeModel theme;
  final int photoCount;
  final String? coverPath;
  final String? coverMediaId;
  final int subAlbumCount;
  final String? pathLabel;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final VoidCallback? onLongPress;

  const ThemeCard({
    super.key,
    required this.theme,
    required this.photoCount,
    this.coverPath,
    this.coverMediaId,
    this.subAlbumCount = 0,
    this.pathLabel,
    required this.onTap,
    this.onMore,
    this.onLongPress,
  });

  @override
  State<ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<ThemeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = Color(widget.theme.colorValue);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final privacy = context.watch<PrivateAlbumController?>();
    final showPrivateLock = widget.theme.isPrivate &&
        !widget.theme.isSubAlbum &&
        widget.theme.id != null &&
        privacy?.isRootUnlocked(widget.theme.id!) != true;
    return AnimatedScale(
      scale: _pressed ? .98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6E554B)
                    .withValues(alpha: dark ? .13 : .065),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withValues(alpha: dark ? .78 : .68),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 65,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCover(accent),
                    if (showPrivateLock)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .48),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 35,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 8, 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.theme.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                            ),
                          ),
                          SizedBox.square(
                            dimension: 24,
                            child: IconButton(
                              onPressed: widget.onMore,
                              tooltip: '更多操作',
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: scheme.onSurfaceVariant
                                    .withValues(alpha: .78),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _metaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _metaText {
    if (widget.pathLabel != null) {
      return '${widget.pathLabel} · ${widget.photoCount} 张';
    }
    if (widget.photoCount > 0 && widget.subAlbumCount > 0) {
      return '${widget.photoCount} 张 · ${widget.subAlbumCount} 个子相册';
    }
    if (widget.photoCount > 0) {
      return '${widget.photoCount} 张照片';
    }
    if (widget.subAlbumCount > 0) {
      return '${widget.subAlbumCount} 个子相册';
    }
    return '暂无照片';
  }

  Widget _buildCover(Color accent) {
    if (widget.coverMediaId != null) {
      return FutureBuilder<AssetEntity?>(
        future: AssetEntity.fromId(widget.coverMediaId!),
        builder: (context, entitySnapshot) {
          final entity = entitySnapshot.data;
          if (entity == null) return _buildPlaceholder(accent);
          return FutureBuilder<MemoryImage?>(
            future: entity
                .thumbnailDataWithSize(const ThumbnailSize.square(480),
                    quality: 82)
                .then((bytes) => bytes == null ? null : MemoryImage(bytes)),
            builder: (context, imageSnapshot) => imageSnapshot.data == null
                ? _buildPlaceholder(accent)
                : Image(image: imageSnapshot.data!, fit: BoxFit.cover),
          );
        },
      );
    }
    if (widget.coverPath != null) {
      return Image.file(
        File(widget.coverPath!),
        fit: BoxFit.cover,
        cacheWidth: AppConstants.thumbnailCacheWidth,
        errorBuilder: (_, __, ___) => _buildPlaceholder(accent),
      );
    }
    return _buildPlaceholder(accent);
  }

  Widget _buildPlaceholder(Color accent) => ClipRect(
        child: Transform.scale(
          scale: 1.11,
          child: Image.asset(
            ClayAssets.defaultCover,
            fit: BoxFit.cover,
            cacheWidth: 720,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => _buildGeneratedPlaceholder(accent),
          ),
        ),
      );

  Widget _buildGeneratedPlaceholder(Color accent) => LayoutBuilder(
        builder: (context, constraints) => Container(
          color: AppColors.tint(accent, amount: .76),
          child: Stack(
            children: [
              Positioned(
                right: constraints.maxWidth * .13,
                top: constraints.maxHeight * .14,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.butter.withValues(alpha: .9),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -12,
                right: constraints.maxWidth * .28,
                bottom: -20,
                height: constraints.maxHeight * .6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(90),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: constraints.maxWidth * .36,
                right: -18,
                bottom: -26,
                height: constraints.maxHeight * .52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .78),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(100),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 18,
                child: Icon(Icons.cloud_rounded,
                    color: Colors.white.withValues(alpha: .88), size: 28),
              ),
            ],
          ),
        ),
      );
}
