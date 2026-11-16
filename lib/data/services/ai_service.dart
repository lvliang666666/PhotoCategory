import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_model.dart';

class AiConfig {
  static const defaultBaseUrl = 'https://api.deepseek.com';
  static const defaultModel = 'deepseek-v4-flash';

  final String baseUrl;
  final String model;
  final bool hasApiKey;

  const AiConfig({
    required this.baseUrl,
    required this.model,
    required this.hasApiKey,
  });
}

class MomentsCaption {
  final String style;
  final String text;

  const MomentsCaption({required this.style, required this.text});
}

/// Persistent "personal traits" that shape generated captions so they read
/// like the user wrote them. Stored locally, injected into the system prompt
/// when enabled.
class AiPersona {
  final bool enabled;
  final String identity;
  final String tone;
  final String elements;
  final String avoid;

  const AiPersona({
    this.enabled = false,
    this.identity = '',
    this.tone = '',
    this.elements = '',
    this.avoid = '',
  });

  bool get hasContent =>
      identity.trim().isNotEmpty ||
      tone.trim().isNotEmpty ||
      elements.trim().isNotEmpty ||
      avoid.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'identity': identity,
        'tone': tone,
        'elements': elements,
        'avoid': avoid,
      };

  factory AiPersona.fromJson(Map<String, dynamic> json) => AiPersona(
        enabled: json['enabled'] == true,
        identity: json['identity']?.toString() ?? '',
        tone: json['tone']?.toString() ?? '',
        elements: json['elements']?.toString() ?? '',
        avoid: json['avoid']?.toString() ?? '',
      );
}

class AiServiceException implements Exception {
  final String message;

  const AiServiceException(this.message);

  @override
  String toString() => message;
}

class AiService {
  static const _baseUrlKey = 'ai_base_url';
  static const _modelKey = 'ai_model';
  static const _personaKey = 'ai_persona';
  static const _secureApiKey = 'deepseek_api_key';
  static const _secureChannel =
      MethodChannel('com.photostorer.photo_storer/secure_storage');

  Future<AiPersona> loadPersona() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_personaKey);
    if (raw == null || raw.isEmpty) return const AiPersona();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? AiPersona.fromJson(decoded)
          : const AiPersona();
    } catch (_) {
      return const AiPersona();
    }
  }

  Future<void> savePersona(AiPersona persona) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_personaKey, jsonEncode(persona.toJson()));
  }

  /// Builds the system-prompt section describing the user's persona.
  /// Empty (or disabled) personas produce an empty string.
  static String buildPersonaPromptSection(AiPersona persona) {
    if (!persona.enabled || !persona.hasContent) return '';
    final lines = <String>[];
    final identity = persona.identity.trim();
    final tone = persona.tone.trim();
    final elements = persona.elements.trim();
    final avoid = persona.avoid.trim();
    if (identity.isNotEmpty) lines.add('身份背景：$identity');
    if (tone.isNotEmpty) lines.add('语气习惯：$tone');
    if (elements.isNotEmpty) lines.add('常用元素：$elements');
    if (avoid.isNotEmpty) lines.add('避免出现：$avoid');
    if (lines.isEmpty) return '';
    return '用户的个人特征（文案必须符合这个人设，像用户本人写的）：\n'
        '${lines.join('\n')}';
  }

  /// Lets the user describe themselves loosely and get a structured persona
  /// draft back, which the settings page fills into the editable fields.
  Future<String> generatePersonaDraft(String rawDescription) async {
    final description = rawDescription.trim();
    if (description.isEmpty) {
      throw const AiServiceException('请先随便写几句关于自己的描述');
    }
    final config = await loadConfig();
    final apiKey = await _readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiServiceException('请先在“设置 → AI服务”中填写 API Key');
    }
    return _complete(
      baseUrl: config.baseUrl,
      model: config.model,
      apiKey: apiKey,
      systemPrompt: '你是朋友圈人设整理助手。把用户随手写的自我描述整理成四行，'
          '每行格式严格为「标签：内容」，标签依次为：身份背景、语气习惯、常用元素、避免出现。'
          '用户没提到的维度写「未提及」。不要输出其他任何内容。',
      userPrompt: description,
      maxTokens: 300,
      jsonOutput: false,
    );
  }

  Future<AiConfig> loadConfig() async {
    final preferences = await SharedPreferences.getInstance();
    final apiKey = await _readApiKey();
    return AiConfig(
      baseUrl: preferences.getString(_baseUrlKey) ?? AiConfig.defaultBaseUrl,
      model: preferences.getString(_modelKey) ?? AiConfig.defaultModel,
      hasApiKey: apiKey?.isNotEmpty == true,
    );
  }

  Future<void> saveConfig({
    required String baseUrl,
    required String model,
    String? replacementApiKey,
  }) async {
    final normalizedUrl = _normalizeBaseUrl(baseUrl);
    final normalizedModel = model.trim();
    if (normalizedModel.isEmpty) {
      throw const AiServiceException('模型名称不能为空');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlKey, normalizedUrl);
    await preferences.setString(_modelKey, normalizedModel);
    if (replacementApiKey?.trim().isNotEmpty == true) {
      await _secureChannel.invokeMethod<void>('write', {
        'key': _secureApiKey,
        'value': replacementApiKey!.trim(),
      });
    }
  }

  Future<void> clearApiKey() async {
    await _secureChannel.invokeMethod<void>('delete', {'key': _secureApiKey});
  }

  Future<void> testConnection({
    required String baseUrl,
    required String model,
    String? temporaryApiKey,
  }) async {
    final key = temporaryApiKey?.trim().isNotEmpty == true
        ? temporaryApiKey!.trim()
        : await _readApiKey();
    if (key == null || key.isEmpty) {
      throw const AiServiceException('请先填写 API Key');
    }
    await _complete(
      baseUrl: _normalizeBaseUrl(baseUrl),
      model: model.trim(),
      apiKey: key,
      systemPrompt: '你是连接测试助手，只回复“连接成功”。',
      userPrompt: '测试连接',
      maxTokens: 32,
      jsonOutput: false,
    );
  }

  Future<List<MomentsCaption>> generateMomentsCaptions({
    required List<PhotoModel> photos,
    required String style,
    required String extraContext,
    String? albumName,
    String? albumDescription,
  }) async {
    if (photos.isEmpty) {
      throw const AiServiceException('请至少选择一张照片');
    }
    final config = await loadConfig();
    final apiKey = await _readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiServiceException('请先在“设置 → AI服务”中填写 API Key');
    }

    final photoDetails = photos.asMap().entries.map((entry) {
      final photo = entry.value;
      final taken = photo.takenAt == null
          ? '未知'
          : DateTime.fromMillisecondsSinceEpoch(photo.takenAt!)
              .toLocal()
              .toString()
              .split('.')
              .first;
      final story = photo.storyText?.trim();
      return '${entry.key + 1}. 文件名：${photo.displayName}；拍摄时间：$taken；'
          '尺寸：${photo.width ?? '?'}×${photo.height ?? '?'}；'
          '照片故事：${story?.isNotEmpty == true ? story : '无'}';
    }).join('\n');

    final personaSection =
        buildPersonaPromptSection(await loadPersona());

    final response = await _complete(
      baseUrl: config.baseUrl,
      model: config.model,
      apiKey: apiKey,
      systemPrompt: '''你是一位自然、克制的中文朋友圈文案编辑。
根据用户提供的照片元数据、照片故事和补充说明生成文案。不得声称看到了照片中未提供的信息，不编造人物、地点或事件。
${personaSection.isEmpty ? '' : '$personaSection\n'}
只输出合法 JSON，格式为：{"captions":[{"style":"简短自然","text":"..."},{"style":"文艺情绪","text":"..."},{"style":"轻松表达","text":"..."}]}。
每条文案应彼此不同，适合直接发布，不添加解释、Markdown 或代码块。''',
      userPrompt: '''照片数量：${photos.length}
相册：${albumName?.trim().isNotEmpty == true ? albumName : '未指定'}
相册描述：${albumDescription?.trim().isNotEmpty == true ? albumDescription : '无'}
用户偏好风格：$style
用户补充：${extraContext.trim().isEmpty ? '无' : extraContext.trim()}

$photoDetails''',
      maxTokens: 700,
      jsonOutput: true,
    );
    return _parseCaptions(response);
  }

  Future<String?> _readApiKey() async {
    try {
      return await _secureChannel
          .invokeMethod<String>('read', {'key': _secureApiKey});
    } on PlatformException catch (error) {
      throw AiServiceException(error.message ?? '无法读取安全保存的 API Key');
    }
  }

  String _normalizeBaseUrl(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const AiServiceException('API 地址必须是有效的 HTTPS 地址');
    }
    return normalized;
  }

  Future<String> _complete({
    required String baseUrl,
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required bool jsonOutput,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final endpoint = Uri.parse('$baseUrl/chat/completions');
      final request = await client.postUrl(endpoint);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      final body = <String, Object?>{
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'stream': false,
        'max_tokens': maxTokens,
        if (jsonOutput) 'response_format': {'type': 'json_object'},
        if (Uri.parse(baseUrl).host.endsWith('deepseek.com'))
          'thinking': {'type': 'disabled'},
      };
      request.write(jsonEncode(body));
      final response =
          await request.close().timeout(const Duration(seconds: 60));
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'AI请求失败（${response.statusCode}）';
        try {
          final decoded = jsonDecode(text) as Map<String, dynamic>;
          message = (decoded['error'] as Map<String, dynamic>?)?['message']
                  ?.toString() ??
              message;
        } catch (_) {}
        throw AiServiceException(message);
      }
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      final message = choices?.isNotEmpty == true
          ? (choices!.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>?
          : null;
      final content = message?['content']?.toString().trim();
      if (content == null || content.isEmpty) {
        throw const AiServiceException('AI没有返回文案，请重试');
      }
      return content;
    } on AiServiceException {
      rethrow;
    } on SocketException {
      throw const AiServiceException('无法连接 AI 服务，请检查网络和 API 地址');
    } on TimeoutException {
      throw const AiServiceException('AI响应超时，请稍后重试');
    } on FormatException {
      throw const AiServiceException('AI返回的数据格式无法识别');
    } finally {
      client.close(force: true);
    }
  }

  List<MomentsCaption> _parseCaptions(String content) {
    try {
      var jsonText = content.trim();
      final start = jsonText.indexOf('{');
      final end = jsonText.lastIndexOf('}');
      if (start >= 0 && end > start) {
        jsonText = jsonText.substring(start, end + 1);
      }
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      final captions = (decoded['captions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => MomentsCaption(
                style: item['style']?.toString().trim().isNotEmpty == true
                    ? item['style'].toString().trim()
                    : 'AI文案',
                text: item['text']?.toString().trim() ?? '',
              ))
          .where((item) => item.text.isNotEmpty)
          .take(3)
          .toList();
      if (captions.isNotEmpty) return captions;
    } catch (_) {}
    throw const AiServiceException('AI返回的文案格式不完整，请重新生成');
  }
}
