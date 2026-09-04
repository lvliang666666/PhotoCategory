import 'package:flutter/material.dart';

import '../data/models/theme_model.dart';

Future<Set<int>?> showHierarchicalAlbumPicker(
  BuildContext context, {
  required List<ThemeModel> albums,
  String title = '选择相册',
  bool allowMultiple = false,
  Set<int> initialSelection = const {},
  Set<int> excludedIds = const {},
}) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HierarchicalAlbumPicker(
      albums: albums,
      title: title,
      allowMultiple: allowMultiple,
      initialSelection: initialSelection,
      excludedIds: excludedIds,
    ),
  );
}

class _HierarchicalAlbumPicker extends StatefulWidget {
  final List<ThemeModel> albums;
  final String title;
  final bool allowMultiple;
  final Set<int> initialSelection;
  final Set<int> excludedIds;

  const _HierarchicalAlbumPicker({
    required this.albums,
    required this.title,
    required this.allowMultiple,
    required this.initialSelection,
    required this.excludedIds,
  });

  @override
  State<_HierarchicalAlbumPicker> createState() =>
      _HierarchicalAlbumPickerState();
}

class _HierarchicalAlbumPickerState extends State<_HierarchicalAlbumPicker> {
  late final Set<int> _selected = {...widget.initialSelection};
  ThemeModel? _currentParent;

  List<ThemeModel> get _parents => widget.albums
      .where((album) => !album.isSystem && album.parentId == null)
      .toList();

  List<ThemeModel> _children(int parentId) =>
      widget.albums.where((album) => album.parentId == parentId).toList();

  void _choose(ThemeModel album) {
    final id = album.id;
    if (id == null || widget.excludedIds.contains(id)) return;
    if (!widget.allowMultiple) {
      Navigator.pop(context, {id});
      return;
    }
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final parent = _currentParent;
    final items = parent == null ? _parents : _children(parent.id!);
    return FractionallySizedBox(
      heightFactor: .72,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: .25),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          ListTile(
            leading: parent == null
                ? const Icon(Icons.account_tree_outlined)
                : IconButton(
                    tooltip: '返回主相册',
                    onPressed: () => setState(() => _currentParent = null),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
            title: Text(parent == null ? widget.title : parent.name),
            subtitle: Text(parent == null
                ? '先选择主相册，再选择其中的子相册'
                : '正在查看「${parent.name}」的子相册'),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                if (parent != null)
                  _albumTile(
                    parent,
                    title: '仅选择「${parent.name}」',
                    icon: Icons.photo_album_outlined,
                  ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('这里还没有可选择的相册')),
                  ),
                for (final album in items)
                  if (parent == null && _children(album.id!).isNotEmpty)
                    ListTile(
                      leading: _albumIcon(album),
                      title: Text(album.name),
                      subtitle: Text('${_children(album.id!).length} 个子相册'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => _currentParent = album),
                    )
                  else
                    _albumTile(album),
              ],
            ),
          ),
          if (widget.allowMultiple)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected),
                    child: Text('确定选择（${_selected.length}）'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _albumTile(
    ThemeModel album, {
    String? title,
    IconData? icon,
  }) {
    final selected = album.id != null && _selected.contains(album.id);
    final disabled = album.id != null && widget.excludedIds.contains(album.id);
    return ListTile(
      enabled: !disabled,
      leading: icon == null ? _albumIcon(album) : Icon(icon),
      title: Text(title ?? album.name),
      subtitle: album.isPrivate ? const Text('私密相册') : null,
      trailing: widget.allowMultiple
          ? Checkbox(
              value: selected,
              onChanged: disabled ? null : (_) => _choose(album),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: () => _choose(album),
    );
  }

  Widget _albumIcon(ThemeModel album) => CircleAvatar(
        backgroundColor: Color(album.colorValue).withValues(alpha: .2),
        child: Icon(
          album.isPrivate ? Icons.lock_rounded : Icons.photo_album_rounded,
          color: Color(album.colorValue),
        ),
      );
}
