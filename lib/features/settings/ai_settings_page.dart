import 'package:flutter/material.dart';

import '../../data/services/ai_service.dart';
import '../../widgets/clay_card.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _service = AiService();
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _hasApiKey = false;
  bool _hideApiKey = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await _service.loadConfig();
      _baseUrl.text = config.baseUrl;
      _model.text = config.model;
      _hasApiKey = config.hasApiKey;
    } on AiServiceException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 服务')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
              children: [
                ClayCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DeepSeek API',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                SizedBox(height: 3),
                                Text('用于生成朋友圈文案'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _apiKey,
                        obscureText: _hideApiKey,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText: _hasApiKey ? '已安全保存；留空表示不更换' : 'sk-...',
                          prefixIcon: const Icon(Icons.key_rounded),
                          suffixIcon: IconButton(
                            tooltip: _hideApiKey ? '显示' : '隐藏',
                            onPressed: () =>
                                setState(() => _hideApiKey = !_hideApiKey),
                            icon: Icon(_hideApiKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _baseUrl,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'API 地址',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _model,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '模型',
                          prefixIcon: Icon(Icons.memory_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('保存设置'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _testing ? null : _test,
                            icon: _testing
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering_rounded),
                            label: const Text('测试连接'),
                          ),
                        ],
                      ),
                      if (_hasApiKey) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _deleteApiKey,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('删除已保存的 API Key'),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const ClayCard(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('照片与隐私',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 8),
                      Text(
                        'DeepSeek 默认模型不能直接读取照片。本应用不会把照片原图上传给 AI，只会发送所选照片的文件名、日期、照片故事、相册描述和你主动填写的场景说明。',
                      ),
                      SizedBox(height: 8),
                      Text(
                          'API Key 使用 Android Keystore 加密，仅保存在当前手机和当前应用的数据空间中。'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _baseUrl.text = AiConfig.defaultBaseUrl;
                    _model.text = AiConfig.defaultModel;
                  },
                  child: const Text('恢复 DeepSeek 默认地址和模型'),
                ),
              ],
            ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveConfig(
        baseUrl: _baseUrl.text,
        model: _model.text,
        replacementApiKey: _apiKey.text,
      );
      _apiKey.clear();
      final config = await _service.loadConfig();
      if (!mounted) return;
      setState(() => _hasApiKey = config.hasApiKey);
      _message('AI设置已保存');
    } on AiServiceException catch (error) {
      if (mounted) _message(error.message);
    } on Exception {
      if (mounted) _message('保存AI设置失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await _service.testConnection(
        baseUrl: _baseUrl.text,
        model: _model.text,
        temporaryApiKey: _apiKey.text,
      );
      if (mounted) _message('连接成功');
    } on AiServiceException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _deleteApiKey() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除 API Key？'),
            content: const Text('删除后将无法生成 AI 文案，直到重新填写。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _service.clearApiKey();
    if (!mounted) return;
    setState(() => _hasApiKey = false);
    _message('API Key 已删除');
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}
