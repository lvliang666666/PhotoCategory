import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/photo_model.dart';
import '../../data/services/ai_service.dart';
import '../../widgets/clay_card.dart';
import '../../widgets/media_thumbnail.dart';
import '../settings/ai_settings_page.dart';

class MomentsCaptionPage extends StatefulWidget {
  final List<PhotoModel> photos;
  final String? albumName;
  final String? albumDescription;

  const MomentsCaptionPage({
    super.key,
    required this.photos,
    this.albumName,
    this.albumDescription,
  });

  @override
  State<MomentsCaptionPage> createState() => _MomentsCaptionPageState();
}

class _MomentsCaptionPageState extends State<MomentsCaptionPage> {
  final _service = AiService();
  final _context = TextEditingController();
  final List<TextEditingController> _captionEditors = [];
  String _style = '自然日常';
  bool _generating = false;
  List<MomentsCaption> _captions = const [];

  static const _styles = ['自然日常', '文艺克制', '轻松幽默', '电影旁白'];

  @override
  void dispose() {
    _context.dispose();
    for (final editor in _captionEditors) {
      editor.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 朋友圈'),
        actions: [
          IconButton(
            tooltip: 'AI设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          Row(
            children: [
              Text('已选择 ${widget.photos.length} 张照片',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const Spacer(),
              Text('原图不上传',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                      )),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 94,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(
                  dimension: 94,
                  child: MediaThumbnail(photo: widget.photos[index]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ClayCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('补充当时发生的事情',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'DeepSeek不能直接看照片。写一句场景或感受，生成结果会更准确。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _context,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: '例如：这是毕业旅行最后一天，想写得自然一些，不要太煽情。',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('文案风格',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _styles
                      .map((style) => ChoiceChip(
                            label: Text(style),
                            selected: _style == style,
                            onSelected: (_) => setState(() => _style = style),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_generating ? '正在生成…' : '生成三条文案'),
                  ),
                ),
              ],
            ),
          ),
          if (_captions.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('选择并编辑文案',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 10),
            ...List.generate(_captions.length, _buildCaptionCard),
          ],
        ],
      ),
    );
  }

  Widget _buildCaptionCard(int index) {
    final caption = _captions[index];
    final editor = _captionEditors[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClayCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 17, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(caption.style,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: editor,
              minLines: 2,
              maxLines: 8,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _copy(editor.text),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('复制'),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: () => _share(editor.text),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('复制并分享'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    setState(() => _generating = true);
    try {
      final captions = await _service.generateMomentsCaptions(
        photos: widget.photos,
        style: _style,
        extraContext: _context.text,
        albumName: widget.albumName,
        albumDescription: widget.albumDescription,
      );
      for (final editor in _captionEditors) {
        editor.dispose();
      }
      _captionEditors
        ..clear()
        ..addAll(
            captions.map((item) => TextEditingController(text: item.text)));
      if (mounted) setState(() => _captions = captions);
    } on AiServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: error.message.contains('设置')
              ? SnackBarAction(label: '去设置', onPressed: _openSettings)
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _copy(String value) async {
    final text = value.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _message('文案已复制');
  }

  Future<void> _share(String value) async {
    final text = value.trim();
    if (text.isEmpty) return;
    final files = <XFile>[];
    for (final photo in widget.photos) {
      final file = File(photo.localPath);
      if (await file.exists()) files.add(XFile(file.path));
    }
    if (!mounted) return;
    if (files.isEmpty) {
      _message('所选照片文件当前不可用');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _message('文案已复制；进入朋友圈后可直接粘贴');
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        text: text,
        title: '朋友圈照片',
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiSettingsPage()),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
