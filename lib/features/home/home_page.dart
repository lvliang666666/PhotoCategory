import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/security/private_album_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/clay_assets.dart';
import '../../data/models/tag_model.dart';
import '../../data/models/theme_model.dart';
import '../../data/models/virtual_album_rules.dart';
import '../../data/repositories/tag_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/clay_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/theme_card.dart';
import '../theme_detail/theme_detail_page.dart';
import '../theme_detail/virtual_album_rules_page.dart';
import '../private_album/private_album_password_pages.dart';
import 'home_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeController>().loadThemes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showPrivateAlbums =
        context.watch<PrivateAlbumController>().showPrivateAlbums;
    return PopScope(
      canPop: !_isReordering,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isReordering) {
          setState(() => _isReordering = false);
        }
      },
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: _HomeHero(
                searchController: _searchController,
                query: _query,
                onQueryChanged: (value) =>
                    setState(() => _query = value.trim()),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                onCreateAlbum: () => _createTheme(context),
              ),
            ),
            Expanded(
              child: Consumer<HomeController>(
                builder: (context, controller, _) {
                  if (controller.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (controller.error != null && controller.themes.isEmpty) {
                    return EmptyState(
                      icon: Icons.refresh_rounded,
                      title: controller.error!,
                      subtitle: '轻触重试，我们会重新读取你的相册。',
                      actionLabel: '重试',
                      onAction: controller.loadThemes,
                    );
                  }
                  final themes = controller.searchThemes(
                    _query,
                    includePrivate: showPrivateAlbums,
                  );
                  if (themes.isEmpty) {
                    return EmptyState(
                      icon: _query.isEmpty
                          ? Icons.photo_album_rounded
                          : Icons.search_off_rounded,
                      title: _query.isEmpty ? '还没有小相册' : '没有找到相关分类',
                      subtitle: _query.isEmpty
                          ? '创建一个分类，开始收藏生活里的片段。'
                          : '换个关键词试试，或清除搜索内容。',
                      actionLabel: _query.isEmpty ? '创建分类' : '清除搜索',
                      onAction: _query.isEmpty
                          ? () => _createTheme(context)
                          : () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                    );
                  }
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _isReordering
                        ? () => setState(() => _isReordering = false)
                        : null,
                    child: RefreshIndicator(
                      onRefresh: controller.loadThemes,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: AppConstants.homeGridColumns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.02,
                        ),
                        itemCount: themes.length,
                        itemBuilder: (context, index) {
                          final theme = themes[index];
                          return _buildReorderableThemeCard(
                            context,
                            controller,
                            theme,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableThemeCard(
    BuildContext context,
    HomeController controller,
    ThemeModel theme,
  ) {
    Widget card({bool feedback = false}) => ThemeCard(
          theme: theme,
          photoCount: controller.photoCounts[theme.id!] ?? 0,
          coverPath: controller.coverPaths[theme.id!],
          coverMediaId: controller.coverMediaIds[theme.id!],
          subAlbumCount: controller.subAlbumCounts[theme.id!] ?? 0,
          pathLabel: theme.isSubAlbum
              ? '${controller.parentNameOf(theme) ?? '主相册'} / ${theme.name}'
              : null,
          onTap: feedback
              ? () {}
              : () {
                  if (_isReordering) {
                    setState(() => _isReordering = false);
                  } else {
                    _openTheme(context, theme.id!);
                  }
                },
          onMore: feedback ? null : () => _showThemeActions(context, theme),
        );

    if (_query.isNotEmpty) return card();
    return DragTarget<ThemeModel>(
      onWillAcceptWithDetails: (details) => details.data.id != theme.id,
      onAcceptWithDetails: (details) =>
          controller.moveTheme(details.data.id!, theme.id!),
      builder: (context, candidates, _) => AnimatedScale(
        scale: candidates.isNotEmpty ? 1.035 : (_isReordering ? .98 : 1),
        duration: const Duration(milliseconds: 160),
        child: LongPressDraggable<ThemeModel>(
          data: theme,
          delay: const Duration(milliseconds: 320),
          onDragStarted: () => setState(() => _isReordering = true),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: (MediaQuery.sizeOf(context).width - 46) / 2,
              height: (MediaQuery.sizeOf(context).width - 46) / 2,
              child:
                  Transform.rotate(angle: -.025, child: card(feedback: true)),
            ),
          ),
          childWhenDragging: Opacity(opacity: .34, child: card()),
          child: card(),
        ),
      ),
    );
  }

  Future<void> _openTheme(BuildContext context, int themeId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ThemeDetailPage(themeId: themeId)),
    );
    if (!context.mounted) return;
    await context.read<HomeController>().loadThemes();
  }

  Future<void> _createTheme(BuildContext context) async {
    final draft = await _showAlbumEditor(context);
    if (draft == null || !context.mounted) return;
    String? privatePassword;
    if (draft.isPrivate) {
      privatePassword = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PrivateAlbumPasswordSetupPage(
            albumName: draft.name,
          ),
        ),
      );
      if (privatePassword == null || !context.mounted) return;
    }
    final controller = context.read<HomeController>();
    final created = await controller.createThemeModel(
      draft.name,
      colorValue: draft.colorValue,
      iconKey: draft.iconKey,
      isPrivate: draft.isPrivate,
      isVirtual: draft.isVirtual,
      virtualRules: draft.virtualRules?.encode(),
    );
    if (!context.mounted) return;
    if (created == null) {
      if (mounted) _message(controller.error ?? '创建分类失败');
      return;
    }
    if (draft.isPrivate && privatePassword != null) {
      try {
        await context
            .read<PrivateAlbumController>()
            .setPassword(created.id!, privatePassword);
      } catch (_) {
        await controller.deleteTheme(created.id!);
        if (mounted) _message('私密密码保存失败，相册未创建');
      }
    }
  }

  Future<_AlbumDraft?> _showAlbumEditor(BuildContext context,
      {ThemeModel? theme}) async {
    final name = TextEditingController(text: theme?.name);
    var colorValue = theme?.colorValue ?? AppColors.coral.toARGB32();
    final iconKey = theme?.iconKey ?? 'album';
    var isPrivate = theme?.isPrivate ?? false;
    var isVirtual = theme?.isVirtual ?? false;
    var virtualRules = VirtualAlbumRules.decode(theme?.virtualRules);
    List<TagModel> tags = const [];
    if (theme == null || theme.isVirtual) {
      try {
        tags = await TagRepository().getTags();
      } catch (_) {
        tags = const [];
      }
    }
    if (!context.mounted) return null;
    final result = await showModalBottomSheet<_AlbumDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            4,
            AppSpacing.xl,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(theme == null ? '创建一个小相册' : '装扮这个小相册',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('给照片一个温暖又好找的家。',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              TextField(
                controller: name,
                autofocus: true,
                maxLength: AppConstants.maxThemeNameLength,
                decoration: const InputDecoration(
                  labelText: '分类名称',
                  hintText: '例如：夏日旅行',
                  counterText: '',
                  prefixIcon: Icon(Icons.edit_rounded),
                ),
              ),
              const SizedBox(height: 20),
              if (theme == null) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.lock_outline_rounded),
                  title: const Text('私密相册'),
                  subtitle: const Text('封面正常展示，进入相册时验证密码'),
                  value: isPrivate,
                  onChanged: (value) => setSheetState(() => isPrivate = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.auto_awesome_motion_outlined),
                  title: const Text('虚拟相册'),
                  subtitle: const Text('按规则自动收集照片，不手动添加'),
                  value: isVirtual,
                  onChanged: (value) => setSheetState(() {
                    isVirtual = value;
                    if (value) isPrivate = false;
                  }),
                ),
                const SizedBox(height: 8),
              ],
              if (isVirtual) ...[
                const _FieldLabel('收集规则'),
                const SizedBox(height: 10),
                VirtualAlbumRulesEditor(
                  tags: tags,
                  rules: virtualRules,
                  onChanged: (value) =>
                      setSheetState(() => virtualRules = value),
                ),
                if (virtualRules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('请至少设置一个条件（标签 / 日期 / 仅收藏）',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                const SizedBox(height: 12),
              ],
              const _FieldLabel('选择颜色'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppColors.categoryPalette.map((color) {
                  final selected = color.toARGB32() == colorValue;
                  return InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () =>
                        setSheetState(() => colorValue = color.toARGB32()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: selected ? 43 : 38,
                      height: selected ? 43 : 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.white.withValues(alpha: .7),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 20, color: Colors.white)
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
                    if (name.text.trim().isEmpty) {
                      _message('分类名称不能为空');
                      return;
                    }
                    if (isVirtual && virtualRules.isEmpty) {
                      _message('虚拟相册至少需要一个收集条件');
                      return;
                    }
                    Navigator.pop(
                        sheetContext,
                        _AlbumDraft(
                          name.text.trim(),
                          colorValue,
                          iconKey,
                          isPrivate,
                          isVirtual: isVirtual,
                          virtualRules:
                              isVirtual ? virtualRules : null,
                        ));
                  },
                  icon: Icon(
                      theme == null ? Icons.add_rounded : Icons.check_rounded),
                  label: Text(theme == null ? '创建分类' : '保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    return result;
  }

  void _showThemeActions(BuildContext context, ThemeModel theme) {
    if (theme.isSystem) {
      _message('系统相册不可修改');
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(theme.name),
                subtitle: const Text('管理这个小相册'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('编辑名称和颜色'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editTheme(theme);
                },
              ),
              if (theme.isVirtual)
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('编辑收集规则'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editVirtualRules(context, theme);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.softError),
                title: const Text('删除相册',
                    style: TextStyle(color: AppColors.softError)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteTheme(context, theme);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editTheme(ThemeModel theme) async {
    final draft = await _showAlbumEditor(context, theme: theme);
    if (draft == null || !mounted) return;
    final controller = context.read<HomeController>();
    final success = await controller.renameTheme(
      theme.id!,
      draft.name,
      colorValue: draft.colorValue,
      iconKey: draft.iconKey,
    );
    if (!success && mounted) _message(controller.error ?? '编辑分类失败');
  }

  Future<void> _editVirtualRules(
      BuildContext context, ThemeModel theme) async {
    List<TagModel> tags = const [];
    try {
      tags = await TagRepository().getTags();
    } catch (_) {
      tags = const [];
    }
    if (!context.mounted) return;
    final rules = await Navigator.of(context).push<VirtualAlbumRules>(
      MaterialPageRoute(
        builder: (_) => VirtualAlbumRulesPage(
          tags: tags,
          initialRules: VirtualAlbumRules.decode(theme.virtualRules),
          albumName: theme.name,
        ),
      ),
    );
    if (rules == null || !context.mounted) return;
    final success = await context
        .read<HomeController>()
        .updateVirtualAlbumRules(theme.id!, rules.encode());
    if (mounted) {
      _message(success ? '规则已更新' : '规则保存失败');
    }
  }

  Future<void> _confirmDeleteTheme(
      BuildContext context, ThemeModel theme) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '确定删除这个相册吗？',
      message: '「${theme.name}」中的照片不会从手机中删除，只会移除分类关系。',
      confirmLabel: '删除相册',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final success = await context.read<HomeController>().deleteTheme(theme.id!);
    if (mounted) _message(success ? '已删除「${theme.name}」' : '删除失败');
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _HomeHero extends StatelessWidget {
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final VoidCallback onCreateAlbum;

  const _HomeHero({
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onClear,
    required this.onCreateAlbum,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClayCard(
      radius: 30,
      color: dark
          ? scheme.surface
          : Color.lerp(scheme.surface, AppColors.butter, .08),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              bottom: 30,
              child: _DecorativeBlob(
                size: 92,
                color: AppColors.butter.withValues(alpha: dark ? .14 : .5),
              ),
            ),
            Positioned(
              left: -38,
              bottom: -54,
              child: _DecorativeBlob(
                size: 112,
                color: AppColors.mint.withValues(alpha: dark ? .13 : .58),
              ),
            ),
            Positioned(
              right: 18,
              bottom: -56,
              child: _DecorativeBlob(
                size: 126,
                color: AppColors.coral.withValues(alpha: dark ? .12 : .48),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '我的相册',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        button: true,
                        label: '创建分类',
                        child: Tooltip(
                          message: '创建分类',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onCreateAlbum,
                            child: const ClayAssetIcon(
                              assetPath: ClayAssets.add,
                              size: 54,
                              zoom: 2.05,
                              cacheWidth: 192,
                              radius: 19,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  TextField(
                    controller: searchController,
                    onChanged: onQueryChanged,
                    decoration: InputDecoration(
                      hintText: '搜索照片或分类',
                      prefixIcon: const Icon(Icons.search_rounded, size: 27),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: onClear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      fillColor: scheme.surface.withValues(alpha: .9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700));
}

class _AlbumDraft {
  final String name;
  final int colorValue;
  final String iconKey;
  final bool isPrivate;
  final bool isVirtual;
  final VirtualAlbumRules? virtualRules;
  const _AlbumDraft(
    this.name,
    this.colorValue,
    this.iconKey,
    this.isPrivate, {
    this.isVirtual = false,
    this.virtualRules,
  });
}
