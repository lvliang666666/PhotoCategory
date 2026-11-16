import 'package:flutter/material.dart';

import '../../data/models/tag_model.dart';
import '../../data/models/virtual_album_rules.dart';

/// Shared rule editor form used by both the create flow (embedded in the
/// home page album sheet) and the standalone "edit rules" page.
///
/// The widget is stateless on purpose: the parent owns the [rules] value and
/// receives every change through [onChanged], so the same instance can live
/// inside a larger form or drive a full page.
class VirtualAlbumRulesEditor extends StatelessWidget {
  final List<TagModel> tags;
  final VirtualAlbumRules rules;
  final ValueChanged<VirtualAlbumRules> onChanged;

  const VirtualAlbumRulesEditor({
    super.key,
    required this.tags,
    required this.rules,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('包含标签（至少选一个条件）',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          Text('还没有标签。可先在“设置 → 标签管理”中创建，再回来编辑规则。',
              style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              final selected = rules.tagIds.contains(tag.id);
              return FilterChip(
                label: Text(tag.name),
                selected: selected,
                onSelected: (_) {
                  final ids = {...rules.tagIds};
                  selected ? ids.remove(tag.id) : ids.add(tag.id!);
                  onChanged(_copyWith(rules, tagIds: ids));
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('拍摄日期范围'),
          subtitle: Text(rules.startDate == null && rules.endDate == null
              ? '不限'
              : '${_dateText(rules.startDate)} 至 ${_dateText(rules.endDate)}'),
          trailing: const Icon(Icons.date_range),
          onTap: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(1970),
              lastDate: DateTime.now(),
              initialDateRange: rules.startDate != null && rules.endDate != null
                  ? DateTimeRange(start: rules.startDate!, end: rules.endDate!)
                  : null,
            );
            if (range != null) {
              onChanged(_copyWith(
                rules,
                startDate: range.start,
                endDate: range.end,
              ));
            }
          },
        ),
        if (rules.startDate != null || rules.endDate != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _copyWith(rules, clearDates: true),
              child: const Text('清除日期'),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('仅收藏'),
          value: rules.favorite,
          onChanged: (value) => onChanged(_copyWith(rules, favorite: value)),
        ),
      ],
    );
  }

  VirtualAlbumRules _copyWith(
    VirtualAlbumRules source, {
    Set<int>? tagIds,
    DateTime? startDate,
    DateTime? endDate,
    bool? favorite,
    bool clearDates = false,
  }) {
    return VirtualAlbumRules(
      tagIds: tagIds ?? source.tagIds,
      startDate: clearDates ? null : (startDate ?? source.startDate),
      endDate: clearDates ? null : (endDate ?? source.endDate),
      favorite: favorite ?? source.favorite,
    );
  }

  String _dateText(DateTime? date) => date == null
      ? '不限'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
}

/// Standalone page for editing the rules of an existing virtual album.
class VirtualAlbumRulesPage extends StatefulWidget {
  final List<TagModel> tags;
  final VirtualAlbumRules initialRules;
  final String albumName;

  const VirtualAlbumRulesPage({
    super.key,
    required this.tags,
    required this.initialRules,
    required this.albumName,
  });

  @override
  State<VirtualAlbumRulesPage> createState() => _VirtualAlbumRulesPageState();
}

class _VirtualAlbumRulesPageState extends State<VirtualAlbumRulesPage> {
  late VirtualAlbumRules _rules;

  @override
  void initState() {
    super.initState();
    _rules = widget.initialRules;
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_rules.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text('编辑规则 · ${widget.albumName}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          Text('符合以下条件的照片会自动出现在这个相册中。',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: VirtualAlbumRulesEditor(
                tags: widget.tags,
                rules: _rules,
                onChanged: (value) => setState(() => _rules = value),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canSave
                  ? () => Navigator.of(context).pop(_rules)
                  : null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('保存规则'),
            ),
          ),
        ],
      ),
    );
  }
}
