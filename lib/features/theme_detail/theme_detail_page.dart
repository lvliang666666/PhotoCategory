import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/security/private_album_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/clay_assets.dart';
import '../../data/models/photo_model.dart';
import '../../data/models/theme_model.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/theme_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/clay_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_thumbnail.dart';
import '../../widgets/hierarchical_album_picker.dart';
import '../../widgets/radial_action_menu.dart';
import '../../widgets/theme_card.dart';
import '../ai/moments_caption_page.dart';
import '../photo_viewer/photo_viewer_page.dart';
import '../private_album/private_album_password_pages.dart';
import 'album_cover_crop_page.dart';
import 'theme_detail_controller.dart';

class ThemeDetailPage extends StatefulWidget {
  final int themeId;

  const ThemeDetailPage({super.key, required this.themeId});

  @override
  State<ThemeDetailPage> createState() => _ThemeDetailPageState();
}

class _ThemeDetailPageState extends State<ThemeDetailPage> {
  late final ThemeDetailController _controller;
  bool _dataChanged = false;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = ThemeDetailController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAfterPrivacyCheck();
    });
  }

  Future<void> _loadAfterPrivacyCheck() async {
    final theme = await ThemeRepository().getThemeById(widget.themeId);
    if (!mounted) return;
    if (theme == null) {
      await _controller.loadTheme(widget.themeId);
      return;
    }
    final privacy = context.read<PrivateAlbumController>();
    if (theme.isPrivate && await privacy.requiresUnlock(theme.id!)) {
      if (!mounted) return;
      final unlocked = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PrivateAlbumPasswordVerifyPage(
            themeId: theme.id!,
            albumName: theme.name,
          ),
        ),
      );
      if (unlocked != true) {
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
    }
    await _controller.loadTheme(widget.themeId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      builder: (context, _) {
        return Consumer<ThemeDetailController>(
          builder: (context, controller, _) {
            if (controller.isLoading) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            if (controller.error != null && controller.theme == null) {
              return Scaffold(
                appBar: AppBar(),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.error!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('返回'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final theme = controller.theme!;
            final isSystem = theme.isSystem;

            return PopScope(
              canPop: !controller.isSelecting,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && controller.isSelecting) {
                  controller.clearSelection();
                }
              },
              child: Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: Icon(controller.isSelecting
                        ? Icons.close_rounded
                        : Icons.arrow_back_rounded),
                    onPressed: controller.isSelecting
                        ? controller.clearSelection
                        : () => Navigator.of(context).pop(_dataChanged),
                  ),
                  title: Text(controller.isSelecting
                      ? '已选择 ${controller.selectedIds.length} 张'
                      : theme.name),
                  actions: controller.isSelecting
                      ? [
                          TextButton(
                            onPressed: controller.selectAll,
                            child: const Text('全选'),
                          ),
                        ]
                      : [
                          RadialActionMenu(
                            actions: [
                              if (!isSystem && !theme.isSubAlbum)
                                RadialMenuAction(
                                  icon: Icons.create_new_folder_outlined,
                                  label: '新建子相册',
                                  onPressed: () => _showCreateSubAlbumDialog(
                                      context, controller),
                                ),
                              if (controller.photoCount > 0)
                                RadialMenuAction(
                                  icon: Icons.download_outlined,
                                  label: '导出全部照片',
                                  onPressed: () =>
                                      _exportAll(context, controller),
                                ),
                              if (theme.isPrivate && !theme.isSubAlbum)
                                RadialMenuAction(
                                  icon: Icons.password_rounded,
                                  label: '修改私密密码',
                                  onPressed: () => _changePrivatePassword(
                                    context,
                                    theme,
                                  ),
                                ),
                              if (controller.photoCount > 0)
                                RadialMenuAction(
                                  icon: Icons.folder_zip_outlined,
                                  label: '导出为压缩包',
                                  onPressed: () =>
                                      _exportZip(context, controller),
                                ),
                              if (!isSystem)
                                RadialMenuAction(
                                  icon: Icons.edit_outlined,
                                  label: '重命名',
                                  onPressed: () => _showRenameDialog(
                                      context, controller, theme),
                                ),
                              if (!isSystem)
                                RadialMenuAction(
                                  icon: Icons.delete_outline,
                                  label: '删除相册',
                                  destructive: true,
                                  onPressed: () => _confirmDeleteTheme(
                                      context, controller, theme),
                                ),
                            ],
                          ),
                        ],
                ),
                body: _buildScrollableBody(context, controller),
                floatingActionButton: controller.isSelecting
                    ? null
                    : _buildFloatingTools(context, controller),
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.endFloat,
                bottomNavigationBar: controller.isSelecting
                    ? _buildBatchBar(context, controller)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScrollableBody(
      BuildContext context, ThemeDetailController controller) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 500) controller.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverToBoxAdapter(child: _buildCoverSection(context, controller)),
          SliverToBoxAdapter(
              child: _buildDescriptionSection(context, controller)),
          if (controller.subAlbums.isNotEmpty)
            SliverToBoxAdapter(child: _buildSubAlbums(context, controller)),
          SliverToBoxAdapter(
              child: _buildPhotoSectionHeader(context, controller)),
          if (controller.photoCount == 0)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: EmptyState(
                  icon: Icons.photo_outlined,
                  title: '暂无照片',
                  subtitle: '点击右下角加号导入照片，开始建立这个主题。',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 20),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppConstants.detailGridColumns,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: controller.photos.length,
                itemBuilder: (context, index) => _buildPhotoTile(
                  context,
                  controller,
                  controller.photos[index],
                  index,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
              child: Center(
                child: controller.isLoadingMore
                    ? const CircularProgressIndicator()
                    : Text(
                        '已加载 ${controller.photos.length} / ${controller.photoCount} 张',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildFloatingTools(
      BuildContext context, ThemeDetailController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClayActionButton(
          assetPath: ClayAssets.addPurple,
          tooltip: '从手机相册批量导入',
          size: 52,
          zoom: 1.34,
          loading: controller.isImporting,
          onPressed:
              controller.isImporting ? null : () => _startImport(context),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(
      BuildContext context, ThemeDetailController controller) {
    final description = controller.theme?.description.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ClayCard(
        radius: 22,
        onTap: description.isEmpty
            ? () => _editAlbumDescription(context, controller)
            : () => setState(
                  () => _isDescriptionExpanded = !_isDescriptionExpanded,
                ),
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '相册小记',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: '编辑相册小记',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editAlbumDescription(context, controller),
                  icon: const Icon(Icons.edit_rounded, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 1),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Text(
                description.isEmpty ? '添加一段文字，记录这个相册讲述的内容。' : description,
                maxLines: description.isEmpty
                    ? 2
                    : (_isDescriptionExpanded ? null : 3),
                overflow: _isDescriptionExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                    ),
              ),
            ),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Center(
                  child: AnimatedRotation(
                    turns: _isDescriptionExpanded ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAlbumDescription(
      BuildContext context, ThemeDetailController controller) async {
    final text = TextEditingController(text: controller.theme?.description);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑相册小记'),
        content: TextField(
          controller: text,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          maxLength: AppConstants.maxAlbumDescriptionLength,
          decoration: const InputDecoration(
            hintText: '例如：记录这部电影中的人物、情节和喜欢的画面……',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value == null || !context.mounted) return;
    final success = await controller.updateDescription(value);
    if (context.mounted) {
      if (success) _dataChanged = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '相册小记已保存' : '保存小记失败')),
      );
    }
  }

  Widget _buildPhotoSectionHeader(
      BuildContext context, ThemeDetailController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 10),
      child: Row(
        children: [
          Text(
            '全部照片',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (controller.photoCount > 0)
            TextButton.icon(
              onPressed: controller.isExporting
                  ? null
                  : () => _exportAll(context, controller),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('导出'),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile(
    BuildContext context,
    ThemeDetailController controller,
    PhotoModel photo,
    int index,
  ) {
    final selected =
        photo.id != null && controller.selectedIds.contains(photo.id);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () {
              if (controller.isSelecting && photo.id != null) {
                controller.toggleSelection(photo.id!);
              } else {
                _openViewer(context, controller, index);
              }
            },
            onLongPress: photo.id == null
                ? null
                : () => controller.toggleSelection(photo.id!),
            child: Hero(
              tag: photo.heroTag,
              transitionOnUserGestures: true,
              child: MediaThumbnail(photo: photo),
            ),
          ),
        ),
        if (controller.isSelecting)
          Positioned(
            top: 7,
            right: 7,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withValues(alpha: .76),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 17, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildBatchBar(
      BuildContext context, ThemeDetailController controller) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
        child: ClayCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              _batchAction(
                icon: Icons.photo_album_rounded,
                label: '分类',
                onPressed: controller.isOperating
                    ? null
                    : () => _showBatchCategorySheet(context, controller),
              ),
              _batchAction(
                icon: Icons.favorite_rounded,
                label: '收藏',
                onPressed: controller.isOperating
                    ? null
                    : () => _showBatchFavoriteSheet(context, controller),
              ),
              _batchAction(
                icon: Icons.auto_awesome_rounded,
                label: '朋友圈',
                onPressed: controller.isOperating
                    ? null
                    : () => _openMomentsCaption(context, controller),
              ),
              _batchAction(
                icon: Icons.share_rounded,
                label: '分享',
                onPressed: controller.isOperating
                    ? null
                    : () => _shareSelected(context, controller),
              ),
              _batchAction(
                icon: Icons.remove_circle_outline_rounded,
                label: '移出',
                color: Theme.of(context).colorScheme.error,
                onPressed: controller.isOperating
                    ? null
                    : () => _removeSelected(context, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _batchAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return Expanded(
      child: TextButton(
        onPressed: onPressed,
        style:
            color == null ? null : TextButton.styleFrom(foregroundColor: color),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _showBatchCategorySheet(
      BuildContext context, ThemeDetailController controller) async {
    final themes = await controller.getOtherThemes();
    if (!context.mounted) return;
    final selected = await showHierarchicalAlbumPicker(
      context,
      albums: themes,
      title: '批量添加到分类',
      excludedIds: {controller.theme!.id!},
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;
    final target = themes.firstWhere((theme) => theme.id == selected.first);
    final result = await controller.addSelectedToCategory(target.id!);
    if (context.mounted) {
      _showBatchResult(context, result, '已添加到「${target.name}」');
    }
  }

  Future<void> _showBatchFavoriteSheet(
      BuildContext context, ThemeDetailController controller) async {
    final value = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_rounded),
              title: const Text('批量收藏'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: const Icon(Icons.heart_broken_rounded),
              title: const Text('取消收藏'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
          ],
        ),
      ),
    );
    if (value == null || !context.mounted) return;
    final result = await controller.setSelectedFavorite(value);
    if (context.mounted) {
      _showBatchResult(context, result, value ? '已收藏' : '已取消收藏');
    }
  }

  Future<void> _shareSelected(
      BuildContext context, ThemeDetailController controller) async {
    final files = <XFile>[];
    for (final photo in controller.selectedPhotos) {
      final file = File(photo.localPath);
      if (await file.exists()) files.add(XFile(file.path));
    }
    if (!context.mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所选照片文件均不可用')),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: files, title: '分享所选照片'),
    );
  }

  Future<void> _openMomentsCaption(
      BuildContext context, ThemeDetailController controller) async {
    final photos = List.of(controller.selectedPhotos);
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择照片')),
      );
      return;
    }
    final theme = controller.theme;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentsCaptionPage(
          photos: photos,
          albumName: theme?.name,
          albumDescription: theme?.description,
        ),
      ),
    );
  }

  Future<void> _removeSelected(
      BuildContext context, ThemeDetailController controller) async {
    final count = controller.selectedIds.length;
    final confirmed = await ConfirmDialog.show(
      context,
      title: '移出 $count 张照片？',
      message: '只会从当前相册移除分类关系，不会删除照片文件。',
      confirmLabel: '移出相册',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final result = await controller.removeSelectedFromCurrentAlbum();
    if (context.mounted) {
      _dataChanged = _dataChanged || result.successCount > 0;
      _showBatchResult(context, result, '已从当前相册移出');
    }
  }

  void _showBatchResult(
      BuildContext context, BatchOperationResult result, String successText) {
    _dataChanged = _dataChanged || result.successCount > 0;
    final text = result.failCount == 0
        ? '$successText ${result.successCount} 张照片'
        : '成功 ${result.successCount} 张，失败 ${result.failCount} 张';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _buildSubAlbums(
      BuildContext context, ThemeDetailController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('子相册',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const Spacer(),
              Text('${controller.subAlbums.length} 个',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppConstants.homeGridColumns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.02,
            ),
            itemCount: controller.subAlbums.length,
            itemBuilder: (context, index) {
              final album = controller.subAlbums[index];
              return ThemeCard(
                theme: album,
                photoCount: controller.subAlbumCounts[album.id!] ?? 0,
                coverPath: controller.subAlbumCoverPaths[album.id!],
                coverMediaId: controller.subAlbumCoverMediaIds[album.id!],
                onMore: () => _showSubAlbumActions(context, controller, album),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ThemeDetailPage(themeId: album.id!),
                    ),
                  );
                  await controller.refresh();
                  if (changed == true) _dataChanged = true;
                },
                onLongPress: () =>
                    _showSubAlbumActions(context, controller, album),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSubAlbumActions(BuildContext context,
      ThemeDetailController controller, ThemeModel album) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              title: Text(album.name),
              leading: const Icon(Icons.photo_album_outlined)),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑子相册'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showRenameDialog(context, controller, album);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('删除子相册',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(sheetContext);
              _confirmDeleteTheme(context, controller, album);
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildCoverSection(
      BuildContext context, ThemeDetailController controller) {
    final accent = Color(controller.theme!.colorValue);
    final coverPhoto = controller.coverPhoto;
    final coverPath = controller.coverPath;
    return Container(
      width: double.infinity,
      height: 218,
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Colors.white.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? .05 : .45,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E554B).withValues(alpha: .12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: .32),
            blurRadius: 5,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: coverPhoto != null
                ? () {
                    final index = controller.photos
                        .indexWhere((photo) => photo.id == coverPhoto.id);
                    if (index >= 0) _openViewer(context, controller, index);
                  }
                : null,
            child: coverPhoto != null
                ? MediaThumbnail(photo: coverPhoto, fit: BoxFit.cover)
                : coverPath != null
                    ? Image.file(
                        File(coverPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildCoverPlaceholder(accent),
                      )
                    : _buildCoverPlaceholder(accent),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 74,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .22),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 12,
            child: TextButton.icon(
              onPressed: () => _showCoverPicker(context, controller),
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: .88),
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.wallpaper_rounded, size: 17),
              label: const Text('设置封面'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder(Color accent) {
    return Container(
      color: AppColors.tint(accent, amount: .82),
      child: Stack(
        children: [
          Positioned(
            left: -8,
            bottom: -10,
            child: Container(
              width: 72,
              height: 54,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.only(topRight: Radius.circular(60)),
              ),
            ),
          ),
          Positioned(
            right: -10,
            bottom: -12,
            child: Container(
              width: 68,
              height: 51,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .75),
                borderRadius:
                    const BorderRadius.only(topLeft: Radius.circular(60)),
              ),
            ),
          ),
          const Positioned(
            right: 15,
            top: 13,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.butter,
            ),
          ),
          Positioned(
            left: 13,
            top: 16,
            child: Icon(Icons.cloud_rounded,
                size: 27, color: Colors.white.withValues(alpha: .9)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCoverPicker(
      BuildContext context, ThemeDetailController controller) async {
    final pageContext = context;
    final future = controller.getCoverCandidates();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .45,
        maxChildSize: .94,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('设置相册封面', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('选择照片后，可拖动和缩放，自行裁剪「${controller.theme?.name ?? ''}」的封面。',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _pickExternalCover(
                        pageContext,
                        sheetContext,
                        controller,
                      ),
                      icon: const ClayAssetIcon(
                        assetPath: ClayAssets.importPhoto,
                        size: 24,
                        zoom: 1.62,
                        cacheWidth: 80,
                        radius: 8,
                      ),
                      label: const Text('从手机另选封面图片'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<PhotoModel>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final photos = snapshot.data ?? const <PhotoModel>[];
                  if (photos.isEmpty) {
                    return const EmptyState(
                      icon: Icons.photo_outlined,
                      title: '没有可用照片',
                      subtitle: '请先向这个相册导入照片。',
                    );
                  }
                  return GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: InkWell(
                          onTap: photo.localPath.isEmpty
                              ? null
                              : () async {
                                  Navigator.pop(sheetContext);
                                  await _cropAndSetCover(
                                    pageContext,
                                    controller,
                                    photo.localPath,
                                  );
                                },
                          child: MediaThumbnail(photo: photo),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExternalCover(
    BuildContext pageContext,
    BuildContext sheetContext,
    ThemeDetailController controller,
  ) async {
    Navigator.pop(sheetContext);
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
      if (pageContext.mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          const SnackBar(content: Text('无法打开照片选择器')),
        );
      }
      return;
    }
    if (picked == null || !pageContext.mounted) return;
    await _cropAndSetCover(pageContext, controller, picked.path);
  }

  Future<void> _cropAndSetCover(
    BuildContext pageContext,
    ThemeDetailController controller,
    String sourcePath,
  ) async {
    if (!pageContext.mounted) return;
    final croppedPath = await Navigator.of(pageContext).push<String>(
      MaterialPageRoute(
        builder: (_) => AlbumCoverCropPage(imagePath: sourcePath),
      ),
    );
    if (croppedPath == null || !pageContext.mounted) return;
    final success = await controller.setExternalCover(croppedPath);
    if (!pageContext.mounted) return;
    if (success) setState(() => _dataChanged = true);
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(content: Text(success ? '封面设置成功' : '封面设置失败')),
    );
  }

  Future<void> _showRenameDialog(BuildContext context,
      ThemeDetailController controller, ThemeModel theme) async {
    final draft = await _showThemeEditor(context, theme: theme);
    if (draft == null || !mounted) return;
    final success = await controller.renameThemeById(
      theme.id!,
      draft.name,
      colorValue: draft.colorValue,
      iconKey: draft.iconKey,
    );
    if (success && mounted) setState(() => _dataChanged = true);
  }

  Future<void> _confirmDeleteTheme(BuildContext context,
      ThemeDetailController controller, ThemeModel theme) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '删除主题？',
      message: '删除「${theme.name}」后，只会移除分类关系，\n照片文件仍会保留在图库中。',
      confirmLabel: '删除',
      isDestructive: true,
    );

    if (confirmed && context.mounted) {
      final isCurrentTheme = controller.theme?.id == theme.id;
      final success = isCurrentTheme
          ? await controller.deleteTheme()
          : await controller.deleteThemeById(theme.id!);
      if (context.mounted) {
        if (success) {
          if (isCurrentTheme) {
            Navigator.of(context).pop(true);
          } else {
            setState(() => _dataChanged = true);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除「${theme.name}」'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除失败'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _openViewer(
      BuildContext context, ThemeDetailController controller, int index) async {
    await controller.recordView(controller.photos[index]);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerPage(
          photos: controller.photos,
          initialIndex: index,
          themeName: controller.theme?.name ?? '',
        ),
      ),
    );
  }

  // Kept for compatibility with older navigation paths; grid long-press now
  // enters multi-select mode and never calls this single-photo action sheet.
  // ignore: unused_element
  void _showPhotoActions(BuildContext context, ThemeDetailController controller,
      PhotoModel photo) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('分享到 QQ、微信等'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _sharePhoto(context, photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('保存到系统相册'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final success = await controller.exportPhoto(photo);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(success ? '已保存到系统相册' : '保存失败，请检查权限')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('设为封面'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final success = await controller.setCoverPhoto(photo.id!);
                if (context.mounted) {
                  setState(() => _dataChanged = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '已设为封面' : '操作失败'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('移动到'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showMoveDialog(context, controller, photo);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.remove_circle_outline,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: Text(
                '从此分类移除',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeletePhoto(context, controller, photo);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveDialog(BuildContext context,
      ThemeDetailController controller, PhotoModel photo) async {
    final themes = await controller.getOtherThemes();
    if (!context.mounted) return;
    final selected = await showHierarchicalAlbumPicker(
      context,
      albums: themes,
      title: '移动到相册',
      excludedIds: {controller.theme!.id!},
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;
    final theme = themes.firstWhere((item) => item.id == selected.first);
    final success = await controller.movePhoto(photo.id!, theme.id!);
    if (!context.mounted) return;
    setState(() => _dataChanged = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '已移动到「${theme.name}」' : '移动失败'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _confirmDeletePhoto(BuildContext context,
      ThemeDetailController controller, PhotoModel photo) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '移除照片？',
      message: '照片只会从当前分类中移除，\n设备原图和其他分类不会受到影响。',
      confirmLabel: '移除',
      isDestructive: true,
    );

    if (confirmed && context.mounted) {
      final success = await controller.deletePhoto(photo.id!);
      if (context.mounted) {
        setState(() => _dataChanged = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '已从当前分类移除' : '移除失败'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _startImport(BuildContext context) async {
    final picker = ImagePicker();
    List<XFile>? pickedFiles;

    try {
      pickedFiles = await picker.pickMultiImage();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法访问照片，请检查权限设置'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (pickedFiles.isEmpty) return;
    if (!context.mounted) return;

    final sourcePaths = pickedFiles.map((f) => f.path).toList();
    final controller = _controller;

    // Start import (fire-and-forget) and show progress dialog.
    // The import updates controller state which drives the dialog UI.
    final importFuture = controller.importPhotos(sourcePaths);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ChangeNotifierProvider.value(
          value: controller,
          child: Consumer<ThemeDetailController>(
            builder: (context, ctrl, _) {
              // Auto-dismiss when import completes
              if (!ctrl.isImporting && ctrl.importProgress > 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                });
              }

              return AlertDialog(
                title: Text(ctrl.isImporting ? '正在导入照片' : '导入完成'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ctrl.isImporting) ...[
                      LinearProgressIndicator(
                        value: ctrl.importTotal > 0
                            ? ctrl.importProgress / ctrl.importTotal
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      '${ctrl.importProgress} / ${ctrl.importTotal}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    // Wait for import to fully complete
    final result = await importFuture;

    if (!context.mounted) return;

    // Show result
    final messages = <String>[];
    if (result.successCount > 0) {
      messages.add('已导入 ${result.successCount} 张照片');
    }
    if (result.skippedCount > 0) {
      messages.add('跳过 ${result.skippedCount} 张重复');
    }
    if (result.failCount > 0) {
      messages.add('${result.failCount} 张照片导入失败');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messages.join('，')),
        duration: const Duration(seconds: 2),
      ),
    );

    // Signal data changed for home page refresh
    setState(() => _dataChanged = true);
  }

  Future<void> _sharePhoto(BuildContext context, PhotoModel photo) async {
    try {
      File? file;
      if (photo.mediaId != null) {
        final entity = await AssetEntity.fromId(photo.mediaId!);
        file = entity == null ? null : await entity.file;
      } else if (photo.localPath.isNotEmpty) {
        final localFile = File(photo.localPath);
        if (await localFile.exists()) file = localFile;
      }
      if (file == null) throw const FileSystemException('照片不可用');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          title: '分享照片',
          text: '来自相册分类',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开分享面板')),
        );
      }
    }
  }

  Future<void> _exportAll(
      BuildContext context, ThemeDetailController controller) async {
    if (controller.photoCount == 0 || controller.isExporting) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在导出 ${controller.photoCount} 张照片…')),
    );
    final result = await controller.exportAllPhotos();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failCount == 0
              ? '已导出 ${result.successCount} 张照片到系统相册'
              : '导出完成：成功 ${result.successCount} 张，失败 ${result.failCount} 张'),
        ),
      );
    }
  }

  Future<void> _exportZip(
      BuildContext context, ThemeDetailController controller) async {
    if (controller.photoCount == 0 || controller.isArchiving) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在打包 ${controller.photoCount} 张照片…')),
    );
    try {
      final archive = await controller.createAlbumArchive();
      if (!context.mounted) return;
      final skipped =
          archive.skippedCount == 0 ? '' : '，跳过 ${archive.skippedCount} 张失效照片';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已打包 ${archive.includedCount} 张照片$skipped')),
      );
      await controller.shareAlbumArchive(archive);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建压缩包失败，请确认照片文件仍然可用')),
        );
      }
    }
  }

  Future<void> _showCreateSubAlbumDialog(
      BuildContext context, ThemeDetailController controller) async {
    final draft = await _showThemeEditor(context, isSubAlbum: true);
    if (draft == null || !mounted) return;
    final success = await controller.createSubAlbum(
      draft.name,
      colorValue: draft.colorValue,
      iconKey: draft.iconKey,
    );
    if (mounted) {
      _dataChanged = _dataChanged || success;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(success
                ? '已创建子相册「${draft.name}」'
                : (controller.error ?? '创建失败'))),
      );
    }
  }

  Future<void> _changePrivatePassword(
    BuildContext context,
    ThemeModel theme,
  ) async {
    final password = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PrivateAlbumPasswordSetupPage(albumName: theme.name),
      ),
    );
    if (password == null || !context.mounted) return;
    await context
        .read<PrivateAlbumController>()
        .setPassword(theme.id!, password);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('私密相册密码已修改'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  Future<_ThemeDraft?> _showThemeEditor(BuildContext context,
      {ThemeModel? theme, bool isSubAlbum = false}) async {
    final nameController = TextEditingController(text: theme?.name);
    var colorValue = theme?.colorValue ?? AppColors.coral.toARGB32();
    final iconKey = theme?.iconKey ?? 'album';
    final result = await showModalBottomSheet<_ThemeDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  theme == null
                      ? (isSubAlbum ? '创建一个子相册' : '创建一个小相册')
                      : '编辑小相册',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(isSubAlbum ? '子相册只保留一级，排版与主相册一致。' : '调整相册名称和边框颜色。',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: AppConstants.maxThemeNameLength,
                decoration: InputDecoration(
                  labelText: '相册名称',
                  hintText: isSubAlbum ? '例如：流浪地球' : '例如：旅行',
                  counterText: '',
                  prefixIcon: const Icon(Icons.edit_rounded),
                ),
              ),
              const SizedBox(height: 18),
              Text('选择颜色', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppColors.categoryPalette.map((color) {
                  final selected = color.toARGB32() == colorValue;
                  return GestureDetector(
                    onTap: () =>
                        setSheetState(() => colorValue = color.toARGB32()),
                    child: CircleAvatar(
                      radius: selected ? 22 : 19,
                      backgroundColor: color,
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                        sheetContext, _ThemeDraft(name, colorValue, iconKey));
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(theme == null ? '创建相册' : '保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    nameController.dispose();
    return result;
  }
}

class _ThemeDraft {
  final String name;
  final int colorValue;
  final String iconKey;
  const _ThemeDraft(this.name, this.colorValue, this.iconKey);
}
