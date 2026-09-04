import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/services/library_backup_service.dart';
import '../../widgets/clay_card.dart';
import 'photo_source_controller.dart';

class LibraryBackupPage extends StatefulWidget {
  const LibraryBackupPage({super.key});

  @override
  State<LibraryBackupPage> createState() => _LibraryBackupPageState();
}

class _LibraryBackupPageState extends State<LibraryBackupPage> {
  final LibraryBackupService _service = LibraryBackupService();
  bool _busy = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('完整相册包')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          ClayCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.inventory_2_outlined),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        '把整个照片空间装进一个包',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '备份包包含导入的照片、相册与子相册、独立封面、描述、标签、收藏、照片故事和最近浏览记录。应用锁密码不会写入备份。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.55,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ClayCard(
            child: Column(
              children: [
                ListTile(
                  enabled: !_busy,
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('导出完整相册包'),
                  subtitle: const Text('生成 ZIP 后可保存到文件或发送到其他设备'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: !_busy,
                  leading: Icon(
                    Icons.settings_backup_restore_rounded,
                    color: scheme.tertiary,
                  ),
                  title: const Text('从完整相册包恢复'),
                  subtitle: const Text('校验备份后替换当前相册资料'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : _confirmRestore,
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 22),
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              _status ?? '正在处理…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: .42),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: scheme.onErrorContainer),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    '备份包包含你的照片和私人文字，请保存在可信位置。恢复不会删除手机系统图库中的原图。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() {
      _busy = true;
      _status = '正在收集相册资料并打包照片…';
    });
    try {
      final result = await _service.exportAndShare();
      if (!mounted) return;
      final missing = result.missingPhotoCount == 0
          ? ''
          : '，${result.missingPhotoCount} 张失效照片未包含文件';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已生成完整备份：${result.albumCount} 个相册、${result.photoCount} 张照片$missing',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showError('导出失败', error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _confirmRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.settings_backup_restore_rounded),
        title: const Text('恢复完整相册包？'),
        content: const Text(
          '恢复会用备份包中的相册、照片、标签、收藏和文字记录替换当前应用内的全部相册资料。\n\n'
          '手机系统图库中的原图不会被删除，应用锁密码也不会改变。请确认当前资料已经备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('选择备份并恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _status = '请选择完整相册备份包…';
    });
    try {
      final result = await _service.pickAndRestore();
      if (!mounted) return;
      if (result == null) return;
      final missing = result.missingPhotoCount == 0
          ? ''
          : '\n另有 ${result.missingPhotoCount} 条失效照片记录未包含文件。';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline_rounded),
          title: const Text('恢复完成'),
          content: Text(
            '已恢复 ${result.albumCount} 个相册和 ${result.photoCount} 张照片。$missing',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('查看相册'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.read<PhotoSourceController>().notifyLibraryRestored();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _showError('恢复失败，当前资料未更改', error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  void _showError(String title, Object error) {
    final message = switch (error) {
      PlatformException(:final message?) => message,
      InvalidLibraryBackupException(:final message) => message,
      FileSystemException(:final message) => message,
      _ => error.toString(),
    };
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
