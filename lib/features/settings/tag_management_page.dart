import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/tag_model.dart';
import '../../data/repositories/tag_repository.dart';
import '../../widgets/confirm_dialog.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  final _repository = TagRepository();
  List<TagModel> _tags = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tags = await _repository.getTags();
    if (mounted) setState(() => _tags = tags);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('标签管理')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editTag(),
          icon: const Icon(Icons.add),
          label: const Text('新建标签'),
        ),
        body: _tags.isEmpty
            ? const Center(child: Text('还没有标签，点击右下角创建'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _tags.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tag = _tags[index];
                  return Card(
                    child: ListTile(
                      leading:
                          CircleAvatar(backgroundColor: Color(tag.colorValue)),
                      title: Text(tag.name),
                      subtitle: Text(
                          '创建于 ${DateTime.fromMillisecondsSinceEpoch(tag.createdAt * 1000).toLocal().toString().split(' ').first}'),
                      onTap: () => _editTag(tag),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTag(tag),
                      ),
                    ),
                  );
                },
              ),
      );

  Future<void> _editTag([TagModel? tag]) async {
    final controller = TextEditingController(text: tag?.name);
    var color = tag?.colorValue ?? AppConstants.defaultCategoryColor;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tag == null ? '新建标签' : '编辑标签'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: AppConstants.maxThemeNameLength,
              decoration: const InputDecoration(hintText: '标签名称'),
            ),
            Wrap(
              spacing: 10,
              children: _colors
                  .map((value) => GestureDetector(
                        onTap: () => setDialogState(() => color = value),
                        child: CircleAvatar(
                          backgroundColor: Color(value),
                          child: color == value
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ))
                  .toList(),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('标签名称不能为空')));
                    return;
                  }
                  try {
                    tag == null
                        ? await _repository.createTag(name, color)
                        : await _repository.updateTag(tag.id!, name, color);
                    if (dialogContext.mounted)
                      Navigator.pop(dialogContext, true);
                  } on DuplicateTagNameException {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('标签名称已存在')));
                  }
                },
                child: const Text('保存')),
          ],
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _deleteTag(TagModel tag) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '删除标签「${tag.name}」？',
      message: '只会删除标签和照片的关联，不会删除任何原图。',
      confirmLabel: '删除',
      isDestructive: true,
    );
    if (confirmed) {
      await _repository.deleteTag(tag.id!);
      await _load();
    }
  }

  static const _colors = [
    0xFFE53935,
    0xFF8E24AA,
    0xFF3949AB,
    0xFF1E88E5,
    0xFF00897B,
    0xFF43A047,
    0xFFF9A825,
    0xFFFB8C00,
  ];
}
