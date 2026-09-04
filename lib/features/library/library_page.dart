import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/clay_assets.dart';
import '../../data/models/photo_filter.dart';
import '../../data/repositories/photo_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_thumbnail.dart';
import '../../widgets/hierarchical_album_picker.dart';
import '../../widgets/clay_card.dart';
import '../ai/moments_caption_page.dart';
import '../photo_viewer/photo_viewer_page.dart';
import 'library_controller.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryController()..initialize(),
      child: Consumer<LibraryController>(
        builder: (context, controller, _) => Scaffold(
          appBar: controller.isSelecting
              ? _selectionAppBar(context, controller)
              : AppBar(
                  title: const Text('照片图库'),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(22),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text('只展示你主动选择并导入的照片',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                  ),
                ),
          body: Column(
            children: [
              if (!controller.isSelecting) ...[
                _searchBar(context, controller),
                _smartAlbums(controller),
                _loadSummary(controller),
                if (!controller.filter.isEmpty) _activeFilters(controller),
              ],
              Expanded(child: _content(context, controller)),
              if (controller.isSelecting) _batchBar(context, controller),
            ],
          ),
          floatingActionButton: controller.isSelecting
              ? null
              : _floatingTools(context, controller),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
      ),
    );
  }

  PreferredSizeWidget _selectionAppBar(
      BuildContext context, LibraryController controller) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: controller.clearSelection,
      ),
      title: Text('已选择 ${controller.selectedIds.length} 张'),
      actions: [
        TextButton(onPressed: controller.selectAll, child: const Text('全选')),
      ],
    );
  }

  Widget _searchBar(BuildContext context, LibraryController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索文件名',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    controller.setQuery('');
                    setState(() {});
                  },
                ),
              Badge(
                isLabelVisible: controller.filter.activeCount > 0,
                label: Text('${controller.filter.activeCount}'),
                child: IconButton(
                  tooltip: '筛选',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => _showFilterSheet(context, controller),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        onChanged: (value) {
          controller.setQuery(value);
          setState(() {});
        },
      ),
    );
  }

  Widget _smartAlbums(LibraryController controller) {
    const labels = {
      SmartAlbum.all: '全部',
      SmartAlbum.favorites: '收藏',
      SmartAlbum.recentViews: '最近浏览',
      SmartAlbum.recentlyAdded: '最近添加',
    };
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: labels.entries
            .map((entry) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: controller.smartAlbum == entry.key,
                    onSelected: (_) => controller.selectSmartAlbum(entry.key),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _loadSummary(LibraryController controller) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
        child: Row(children: [
          Text(
            '已加载 ${controller.photos.length} / ${controller.totalCount} 张',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Text(
            '仅手动导入',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ]),
      );

  Widget _activeFilters(LibraryController controller) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.filter_alt_outlined, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text('已启用 ${controller.filter.activeCount} 个筛选条件')),
            TextButton(
                onPressed: controller.clearFilter, child: const Text('一键清除')),
          ],
        ),
      );

  Widget _content(BuildContext context, LibraryController controller) {
    if (controller.isLoading && controller.photos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null && controller.photos.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        subtitle: controller.error!,
        actionLabel: '重试',
        onAction: controller.initialize,
      );
    }
    if (controller.photos.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: controller.filter.isEmpty ? '暂无照片' : '没有找到匹配的照片',
        subtitle:
            controller.filter.isEmpty ? '点击右下角加号，从手机相册导入照片。' : '试试减少筛选条件。',
        actionLabel: controller.filter.isEmpty ? null : '清除筛选',
        onAction: controller.filter.isEmpty ? null : controller.clearFilter,
      );
    }
    return RefreshIndicator(
      onRefresh: () => controller.initialize(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 600) {
            controller.loadMore();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: controller.photos.length + (controller.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == controller.photos.length) {
              return const Center(child: CircularProgressIndicator());
            }
            final photo = controller.photos[index];
            final selected = controller.selectedIds.contains(photo.id);
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onLongPress: photo.id == null
                        ? null
                        : () => controller.toggleSelection(photo.id!),
                    onTap: () async {
                      if (controller.isSelecting && photo.id != null) {
                        controller.toggleSelection(photo.id!);
                        return;
                      }
                      await controller.recordView(photo);
                      if (!context.mounted) return;
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PhotoViewerPage(
                          photos: controller.photos,
                          initialIndex: index,
                          themeName: '图库',
                        ),
                      ));
                    },
                    child: Hero(
                      tag: photo.heroTag,
                      transitionOnUserGestures: true,
                      child: MediaThumbnail(photo: photo),
                    ),
                  ),
                ),
                if (controller.isSelecting)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white.withValues(alpha: .72),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 17, color: Colors.white)
                          : null,
                    ),
                  ),
                if (!photo.isAvailable)
                  const Positioned(
                    left: 6,
                    bottom: 6,
                    child: Chip(label: Text('不可用')),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _floatingTools(BuildContext context, LibraryController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClayActionButton(
          assetPath: ClayAssets.refreshButton,
          tooltip: '刷新当前照片',
          size: 50,
          zoom: 1.72,
          loading: controller.isLoading,
          onPressed: controller.isLoading || controller.isImporting
              ? null
              : controller.refresh,
        ),
        const SizedBox(height: 6),
        ClayActionButton(
          assetPath: ClayAssets.addPurple,
          tooltip: '从手机相册批量导入',
          size: 52,
          zoom: 1.34,
          loading: controller.isImporting,
          onPressed: controller.isImporting
              ? null
              : () => _startImport(context, controller),
        ),
      ],
    );
  }

  Future<void> _startImport(
      BuildContext context, LibraryController controller) async {
    List<XFile> selected;
    try {
      selected = await ImagePicker().pickMultiImage();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开手机照片选择器')),
        );
      }
      return;
    }
    if (selected.isEmpty || !context.mounted) return;

    final result = await controller.importPhotos(
      selected.map((photo) => photo.path).toList(),
    );
    if (!context.mounted) return;
    final message = result.failCount == 0
        ? '已导入 ${result.successCount} 张照片'
        : '导入完成：成功 ${result.successCount} 张，失败 ${result.failCount} 张';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Widget _batchBar(BuildContext context, LibraryController controller) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: ClayCard(
            radius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _batchButton(
                    Icons.photo_album_rounded,
                    '分类',
                    controller.isOperating
                        ? null
                        : () => _showRelationSheet(context, controller,
                            isTag: false)),
                _batchButton(
                    Icons.label_rounded,
                    '标签',
                    controller.isOperating
                        ? null
                        : () => _showRelationSheet(context, controller,
                            isTag: true)),
                _batchButton(
                    Icons.favorite_rounded,
                    '收藏',
                    controller.isOperating
                        ? null
                        : () => _showFavoriteSheet(context, controller)),
                _batchButton(
                    Icons.auto_awesome_rounded,
                    '朋友圈',
                    controller.isOperating
                        ? null
                        : () => _openMomentsCaption(context, controller)),
                _batchButton(
                    Icons.share_rounded,
                    '分享',
                    controller.isOperating
                        ? null
                        : () => _shareSelected(context, controller)),
                _batchButton(
                    Icons.delete_outline_rounded,
                    '删除',
                    controller.isOperating
                        ? null
                        : () => _deleteSelected(context, controller),
                    color: Theme.of(context).colorScheme.error),
              ],
            )),
      ),
    );
  }

  Widget _batchButton(IconData icon, String label, VoidCallback? onPressed,
          {Color? color}) =>
      Expanded(
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 21),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5)),
          ]),
        ),
      );

  Future<void> _showFilterSheet(
      BuildContext context, LibraryController controller) async {
    var draft = controller.filter;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          builder: (_, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Text('筛选照片', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text('分类'),
              Wrap(
                spacing: 8,
                children: controller.categories
                    .where((c) => !c.isSystem)
                    .map((category) {
                  final selected = draft.categoryIds.contains(category.id);
                  return FilterChip(
                    label: Text(category.name),
                    selected: selected,
                    onSelected: (_) => setSheetState(() {
                      final ids = {...draft.categoryIds};
                      selected
                          ? ids.remove(category.id)
                          : ids.add(category.id!);
                      draft = draft.copyWith(categoryIds: ids);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text('标签'),
              Wrap(
                spacing: 8,
                children: controller.tags.map((tag) {
                  final selected = draft.tagIds.contains(tag.id);
                  return FilterChip(
                    label: Text(tag.name),
                    selected: selected,
                    onSelected: (_) => setSheetState(() {
                      final ids = {...draft.tagIds};
                      selected ? ids.remove(tag.id) : ids.add(tag.id!);
                      draft = draft.copyWith(tagIds: ids);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text('图片格式'),
              Wrap(
                spacing: 8,
                children: ['jpeg', 'png', 'webp', 'heic', 'gif'].map((format) {
                  final selected = draft.formats.contains(format);
                  return FilterChip(
                    label: Text(format.toUpperCase()),
                    selected: selected,
                    onSelected: (_) => setSheetState(() {
                      final formats = {...draft.formats};
                      selected ? formats.remove(format) : formats.add(format);
                      draft = draft.copyWith(formats: formats);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text('画面方向'),
              SegmentedButton<String>(
                emptySelectionAllowed: true,
                segments: const [
                  ButtonSegment(value: 'landscape', label: Text('横图')),
                  ButtonSegment(value: 'portrait', label: Text('竖图')),
                  ButtonSegment(value: 'square', label: Text('方图')),
                ],
                selected: draft.orientation == null ? {} : {draft.orientation!},
                onSelectionChanged: (value) => setSheetState(() {
                  draft = value.isEmpty
                      ? draft.copyWith(clearOrientation: true)
                      : draft.copyWith(orientation: value.first);
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('仅收藏'),
                value: draft.favorite == true,
                onChanged: (value) => setSheetState(() {
                  draft = value
                      ? draft.copyWith(favorite: true)
                      : draft.copyWith(clearFavorite: true);
                }),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('拍摄日期范围'),
                subtitle: Text(draft.startDate == null
                    ? '不限'
                    : '${_dateText(draft.startDate!)} 至 ${_dateText(draft.endDate ?? draft.startDate!)}'),
                trailing: const Icon(Icons.date_range),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1970),
                    lastDate: DateTime.now(),
                  );
                  if (range != null) {
                    setSheetState(() => draft = draft.copyWith(
                          startDate: range.start,
                          endDate: range.end,
                        ));
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setSheetState(() => draft = const PhotoFilter()),
                    child: const Text('清除'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      controller.applyFilter(draft);
                    },
                    child: const Text('应用筛选'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRelationSheet(
      BuildContext pageContext, LibraryController controller,
      {required bool isTag}) async {
    final items = isTag
        ? controller.tags
        : controller.categories.where((c) => !c.isSystem).toList();
    if (items.isEmpty) {
      _message(pageContext, isTag ? '请先在设置中创建标签' : '请先创建分类');
      return;
    }
    if (!isTag) {
      final selected = await showHierarchicalAlbumPicker(
        pageContext,
        albums: controller.categories,
        title: '批量管理分类',
        allowMultiple: true,
      );
      if (selected == null || selected.isEmpty || !pageContext.mounted) return;
      final action = await showModalBottomSheet<bool>(
        context: pageContext,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('添加到所选分类'),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: const Text('从所选分类移除'),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      );
      if (action == null || !pageContext.mounted) return;
      final result = action
          ? await controller.addSelectedCategories(selected.toList())
          : await controller.removeSelectedCategories(selected.toList());
      if (pageContext.mounted) _showBatchResult(pageContext, result);
      return;
    }
    final selected = <int>{};
    await showModalBottomSheet(
      context: pageContext,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(isTag ? '批量管理标签' : '批量管理分类',
                  style: Theme.of(context).textTheme.titleLarge),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: items.map((item) {
                    final id = isTag
                        ? (item as dynamic).id as int
                        : (item as dynamic).id as int;
                    final name = (item as dynamic).name as String;
                    return CheckboxListTile(
                      value: selected.contains(id),
                      title: Text(name),
                      onChanged: (_) => setState(() {
                        selected.contains(id)
                            ? selected.remove(id)
                            : selected.add(id);
                      }),
                    );
                  }).toList(),
                ),
              ),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(sheetContext);
                          final result = isTag
                              ? await controller
                                  .removeSelectedTags(selected.toList())
                              : await controller
                                  .removeSelectedCategories(selected.toList());
                          if (pageContext.mounted) {
                            _showBatchResult(
                              pageContext,
                              result,
                              onRetry: () async {
                                final retry = isTag
                                    ? await controller
                                        .removeSelectedTags(selected.toList())
                                    : await controller.removeSelectedCategories(
                                        selected.toList());
                                if (pageContext.mounted) {
                                  _showBatchResult(pageContext, retry);
                                }
                              },
                            );
                          }
                        },
                  child: const Text('移除'),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(sheetContext);
                          final result = isTag
                              ? await controller
                                  .addSelectedTags(selected.toList())
                              : await controller
                                  .addSelectedCategories(selected.toList());
                          if (pageContext.mounted) {
                            _showBatchResult(
                              pageContext,
                              result,
                              onRetry: () async {
                                final retry = isTag
                                    ? await controller
                                        .addSelectedTags(selected.toList())
                                    : await controller.addSelectedCategories(
                                        selected.toList());
                                if (pageContext.mounted) {
                                  _showBatchResult(pageContext, retry);
                                }
                              },
                            );
                          }
                        },
                  child: const Text('添加'),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showFavoriteSheet(
      BuildContext context, LibraryController controller) async {
    final value = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.favorite),
          title: const Text('设为收藏'),
          onTap: () => Navigator.pop(context, true),
        ),
        ListTile(
          leading: const Icon(Icons.favorite_border),
          title: const Text('取消收藏'),
          onTap: () => Navigator.pop(context, false),
        ),
      ])),
    );
    if (value != null) {
      final result = await controller.setSelectedFavorite(value);
      if (context.mounted) {
        _showBatchResult(
          context,
          result,
          onRetry: () async {
            final retry = await controller.setSelectedFavorite(value);
            if (context.mounted) _showBatchResult(context, retry);
          },
        );
      }
    }
  }

  Future<void> _shareSelected(
      BuildContext context, LibraryController controller) async {
    final files = <XFile>[];
    for (final photo in controller.selectedPhotos) {
      if (photo.localPath.isNotEmpty) {
        files.add(XFile(photo.localPath));
      }
    }
    if (files.isEmpty) {
      if (context.mounted) _message(context, '所选照片当前不可用');
      return;
    }
    await SharePlus.instance.share(ShareParams(files: files, title: '分享照片'));
  }

  Future<void> _openMomentsCaption(
      BuildContext context, LibraryController controller) async {
    final photos = List.of(controller.selectedPhotos);
    if (photos.isEmpty) {
      _message(context, '请先选择照片');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentsCaptionPage(photos: photos),
      ),
    );
  }

  Future<void> _deleteSelected(
      BuildContext context, LibraryController controller) async {
    final count = controller.selectedIds.length;
    final confirmed = await ConfirmDialog.show(
      context,
      title: '永久删除 $count 张照片？',
      message: '将删除本应用保存的照片副本和整理记录，无法撤销。\n手机系统图库中的原始照片不会受到影响。',
      confirmLabel: '删除',
      isDestructive: true,
    );
    if (!confirmed) return;
    final result = await controller.deleteSelected();
    if (!context.mounted) return;
    _message(
      context,
      '已删除 ${result.successCount} 张，失败 ${result.failCount} 张',
      onRetry: result.failCount > 0
          ? () => _deleteSelected(context, controller)
          : null,
    );
  }

  void _showBatchResult(BuildContext context, BatchOperationResult result,
          {VoidCallback? onRetry}) =>
      _message(
        context,
        '成功 ${result.successCount} 张，失败 ${result.failCount} 张',
        onRetry: result.failCount > 0 ? onRetry : null,
      );

  void _message(BuildContext context, String text, {VoidCallback? onRetry}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text),
        action: onRetry == null
            ? null
            : SnackBarAction(label: '重试失败项', onPressed: onRetry),
      ));

  String _dateText(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
