import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/photo_model.dart';
import '../../data/repositories/photo_repository.dart';
import '../../widgets/media_thumbnail.dart';
import 'photo_info_page.dart';

class PhotoViewerPage extends StatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;
  final String themeName;

  const PhotoViewerPage({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.themeName,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _appBarVisible = true;
  final PhotoRepository _photoRepository = PhotoRepository();
  late final List<PhotoModel> _photos;
  final Map<String, Future<File?>> _fileFutures = {};
  final Map<int, TransformationController> _transformations = {};
  bool _isZoomed = false;
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _photos = List<PhotoModel>.from(widget.photos);
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewerTheme = Theme.of(context).copyWith(
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: .14),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
    return PopScope(
      canPop: !_isZoomed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isZoomed) _resetZoom(_currentIndex);
      },
      child: Theme(
        data: viewerTheme,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: _appBarVisible
              ? AppBar(
                  backgroundColor: Colors.black.withValues(alpha: .88),
                  foregroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  systemOverlayStyle: SystemUiOverlayStyle.light,
                  iconTheme: const IconThemeData(color: Colors.white),
                  actionsIconTheme: const IconThemeData(color: Colors.white),
                  title: Text(
                    widget.themeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  centerTitle: false,
                  actions: [
                    IconButton(
                      tooltip: _currentPhoto.isFavorite ? '取消收藏' : '收藏',
                      icon: Icon(_currentPhoto.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded),
                      onPressed: _toggleFavorite,
                    ),
                    PopupMenuButton<_ViewerAction>(
                      tooltip: '更多操作',
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (action) {
                        switch (action) {
                          case _ViewerAction.info:
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  PhotoInfoPage(photo: _currentPhoto),
                            ));
                          case _ViewerAction.story:
                            _editStory();
                          case _ViewerAction.save:
                            _saveCurrentPhoto();
                          case _ViewerAction.share:
                            _shareCurrentPhoto();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _ViewerAction.story,
                          child: ListTile(
                            leading: Icon(Icons.auto_stories_rounded),
                            title: Text('照片故事'),
                            subtitle: Text('记录想法或当下的感受'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _ViewerAction.info,
                          child: ListTile(
                            leading: Icon(Icons.info_outline_rounded),
                            title: Text('照片信息'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _ViewerAction.save,
                          child: ListTile(
                            leading: Icon(Icons.download_rounded),
                            title: Text('保存到系统相册'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _ViewerAction.share,
                          child: ListTile(
                            leading: Icon(Icons.share_rounded),
                            title: Text('分享照片'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              : null,
          body: Stack(
            children: [
              // PageView for swiping
              GestureDetector(
                onTap: () {
                  setState(() => _appBarVisible = !_appBarVisible);
                },
                child: PageView.builder(
                  controller: _pageController,
                  physics: _isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: _photos.length,
                  onPageChanged: (index) {
                    _resetZoom(_currentIndex, notify: false);
                    setState(() {
                      _currentIndex = index;
                      _isZoomed = false;
                    });
                  },
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    final transformation = _transformations.putIfAbsent(
                      index,
                      TransformationController.new,
                    );

                    return Hero(
                      tag: photo.heroTag,
                      transitionOnUserGestures: true,
                      child: Material(
                        color: Colors.black,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTapDown: (details) =>
                              _doubleTapPosition = details.localPosition,
                          onDoubleTap: () =>
                              _toggleDoubleTapZoom(index, transformation),
                          child: InteractiveViewer(
                            transformationController: transformation,
                            minScale: 1,
                            maxScale: 5,
                            boundaryMargin: const EdgeInsets.all(80),
                            onInteractionUpdate: (_) =>
                                _updateZoomState(index, transformation),
                            onInteractionEnd: (_) =>
                                _updateZoomState(index, transformation),
                            child: Center(
                              child: _buildPhoto(photo),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Page counter at bottom
              if (_appBarVisible)
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateZoomState(
    int index,
    TransformationController controller,
  ) {
    if (index != _currentIndex) return;
    final zoomed = controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _isZoomed && mounted) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _toggleDoubleTapZoom(
    int index,
    TransformationController controller,
  ) {
    if (controller.value.getMaxScaleOnAxis() > 1.01) {
      _resetZoom(index);
      return;
    }
    const scale = 2.6;
    final position = _doubleTapPosition;
    controller.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
      );
    _updateZoomState(index, controller);
  }

  void _resetZoom(int index, {bool notify = true}) {
    final controller = _transformations[index];
    if (controller != null) controller.value = Matrix4.identity();
    if (notify && mounted && _isZoomed) {
      setState(() => _isZoomed = false);
    }
  }

  Widget _buildPhoto(PhotoModel photo) {
    if (!photo.isAvailable) return _unavailable();
    final placeholder = SizedBox.expand(
      child: MediaThumbnail(photo: photo, fit: BoxFit.contain),
    );
    return FutureBuilder<File?>(
      future:
          _fileFutures.putIfAbsent(photo.heroTag, () => _resolveFile(photo)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return snapshot.connectionState == ConnectionState.waiting
              ? placeholder
              : _unavailable();
        }
        return Image.file(
          file,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              child: frame == null
                  ? KeyedSubtree(
                      key: const ValueKey('thumbnail'), child: placeholder)
                  : KeyedSubtree(
                      key: const ValueKey('full-image'), child: child),
            );
          },
          errorBuilder: (_, __, ___) => _unavailable('无法解析这张照片'),
        );
      },
    );
  }

  Future<File?> _resolveFile(PhotoModel photo) async {
    if (photo.mediaId != null) {
      return (await AssetEntity.fromId(photo.mediaId!))?.file;
    }
    if (photo.localPath.isEmpty) return null;
    final file = File(photo.localPath);
    return await file.exists() ? file : null;
  }

  Widget _unavailable([String message = '照片不可用或访问权限已撤销']) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );

  PhotoModel get _currentPhoto => _photos[_currentIndex];

  Future<File?> _currentFile() async {
    if (_currentPhoto.mediaId != null) {
      return (await AssetEntity.fromId(_currentPhoto.mediaId!))?.file;
    }
    final file = File(_currentPhoto.localPath);
    return await file.exists() ? file : null;
  }

  Future<void> _toggleFavorite() async {
    final photo = _currentPhoto;
    if (photo.id == null) return;
    final value = !photo.isFavorite;
    final result = await _photoRepository.setFavorite([photo.id!], value);
    if (result.successCount == 1 && mounted) {
      setState(
          () => _photos[_currentIndex] = photo.copyWith(isFavorite: value));
    }
  }

  Future<void> _editStory() async {
    final photo = _currentPhoto;
    if (photo.id == null) return;
    final textController = TextEditingController(text: photo.storyText ?? '');
    final draft = await showModalBottomSheet<_StoryDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .primary
                          .withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('写下这张照片的故事',
                            style: Theme.of(sheetContext).textTheme.titleLarge),
                        const SizedBox(height: 3),
                        Text('记录当时的想法、心情，或者想留给未来的话。',
                            style: Theme.of(sheetContext).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: textController,
                autofocus: true,
                minLines: 6,
                maxLines: 10,
                maxLength: AppConstants.maxPhotoStoryLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: '这一刻，我想记住……',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (photo.hasStory)
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(sheetContext, const _StoryDraft('')),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('清空故事'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _StoryDraft(textController.text),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('保存故事'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    textController.dispose();
    if (draft == null || !mounted) return;
    final normalized = draft.text.trim();
    final success = await _photoRepository.updateStory(photo.id!, normalized);
    if (!mounted) return;
    if (success) {
      final updatedAt = normalized.isEmpty
          ? null
          : DateTime.now().millisecondsSinceEpoch ~/ 1000;
      setState(() {
        _photos[_currentIndex] = photo.copyWith(
          storyText: normalized.isEmpty ? null : normalized,
          clearStoryText: normalized.isEmpty,
          storyUpdatedAt: updatedAt,
          clearStoryUpdatedAt: normalized.isEmpty,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(normalized.isEmpty ? '照片故事已清空' : '照片故事已保存'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('故事保存失败，请稍后重试')),
      );
    }
  }

  Future<void> _saveCurrentPhoto() async {
    try {
      final file = await _currentFile();
      if (file == null) throw const FileSystemException('照片不可用');
      await Gal.putImage(
        file.path,
        album: '相册分类-${widget.themeName}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到系统相册')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请检查相册权限')),
        );
      }
    }
  }

  Future<void> _shareCurrentPhoto() async {
    try {
      final file = await _currentFile();
      if (file == null) throw const FileSystemException('照片不可用');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          title: '分享照片',
          text: '来自相册分类',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开分享面板')),
        );
      }
    }
  }
}

class _StoryDraft {
  final String text;
  const _StoryDraft(this.text);
}

enum _ViewerAction { story, info, save, share }
