import 'package:flutter_test/flutter_test.dart';
import 'package:photo_storer/data/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiPersona persistence', () {
    test('savePersona/loadPersona 往返保留字段', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AiService();
      const persona = AiPersona(
        enabled: true,
        identity: '二胎爸爸，程序员',
        tone: '口语化、偶尔自嘲',
        elements: '喜欢引用歌词',
        avoid: '不提工作细节',
      );
      await service.savePersona(persona);

      final loaded = await service.loadPersona();
      expect(loaded.enabled, isTrue);
      expect(loaded.identity, '二胎爸爸，程序员');
      expect(loaded.tone, '口语化、偶尔自嘲');
      expect(loaded.elements, '喜欢引用歌词');
      expect(loaded.avoid, '不提工作细节');
    });

    test('无存储时返回默认 persona', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AiService();
      final persona = await service.loadPersona();
      expect(persona.enabled, isFalse);
      expect(persona.hasContent, isFalse);
    });

    test('损坏的存储内容安全回退为默认值', () async {
      SharedPreferences.setMockInitialValues({
        'ai_persona': '{broken json',
      });
      final service = AiService();
      final persona = await service.loadPersona();
      expect(persona.enabled, isFalse);
      expect(persona.hasContent, isFalse);
    });
  });

  group('buildPersonaPromptSection', () {
    test('disabled 时返回空串', () {
      const persona = AiPersona(
        enabled: false,
        identity: '程序员',
      );
      expect(AiService.buildPersonaPromptSection(persona), '');
    });

    test('enabled 但全空时返回空串', () {
      const persona = AiPersona(enabled: true);
      expect(AiService.buildPersonaPromptSection(persona), '');
    });

    test('enabled 时拼接非空字段，跳过空字段', () {
      const persona = AiPersona(
        enabled: true,
        identity: '二胎爸爸',
        avoid: '不提工作',
      );
      final section = AiService.buildPersonaPromptSection(persona);
      expect(section, contains('身份背景：二胎爸爸'));
      expect(section, contains('避免出现：不提工作'));
      expect(section, isNot(contains('语气习惯')));
      expect(section, isNot(contains('常用元素')));
      expect(section, contains('像用户本人写的'));
    });

    test('全部字段都注入', () {
      const persona = AiPersona(
        enabled: true,
        identity: '身份',
        tone: '语气',
        elements: '元素',
        avoid: '禁忌',
      );
      final section = AiService.buildPersonaPromptSection(persona);
      expect(section, contains('身份背景：身份'));
      expect(section, contains('语气习惯：语气'));
      expect(section, contains('常用元素：元素'));
      expect(section, contains('避免出现：禁忌'));
    });
  });
}
