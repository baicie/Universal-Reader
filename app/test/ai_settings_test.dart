import 'dart:convert';

import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/deepseek.dart';
import 'package:app/features/tools/ai/model_client.dart';
import 'package:app/features/tools/ai/ollama.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('blank settings fill DeepSeek project defaults', () {
    final settings = const AiSettings().withProjectDefaults();

    expect(settings.endpoint, DeepSeek.endpoint);
    expect(settings.model, DeepSeek.defaultModel);
    expect(settings.enabled, isFalse);
    expect(settings.ready, isFalse);
  });

  test('DeepSeek assistant is ready only with an API key', () {
    expect(
      const AiSettings(
        enabled: true,
        endpoint: DeepSeek.endpoint,
        model: DeepSeek.defaultModel,
      ).ready,
      isFalse,
    );
    expect(
      const AiSettings(
        enabled: true,
        endpoint: DeepSeek.endpoint,
        model: DeepSeek.defaultModel,
        apiKey: 'sk-test',
      ).ready,
      isTrue,
    );
    expect(
      const AiSettings(
        enabled: true,
        endpoint: DeepSeek.endpoint,
        model: DeepSeek.defaultModel,
      ).isReady(serverHasKey: true),
      isTrue,
    );
  });

  test('project defaults do not overwrite a saved model or key', () {
    const saved = AiSettings(
      endpoint: 'https://example.invalid/deepseek',
      model: 'deepseek-reasoner',
      apiKey: 'sk-saved',
    );

    final resolved = saved.withProjectDefaults(
      endpoint: 'https://api.deepseek.com',
      model: 'deepseek-chat',
      apiKey: 'sk-project',
    );

    expect(resolved.endpoint, 'https://example.invalid/deepseek');
    expect(resolved.model, 'deepseek-reasoner');
    expect(resolved.apiKey, 'sk-saved');
  });

  test('project API key fills a blank settings key', () {
    final resolved = const AiSettings(
      enabled: true,
      model: 'deepseek-chat',
    ).withProjectDefaults(apiKey: 'sk-from-project');

    expect(resolved.apiKey, 'sk-from-project');
    expect(resolved.ready, isTrue);
  });

  test('Ollama is ready without an API key', () {
    expect(
      const AiSettings(enabled: true, provider: AiProvider.ollama).ready,
      isTrue,
    );
  });

  test('Ollama blank settings fill the ollama defaults', () {
    const settings = AiSettings(provider: AiProvider.ollama);
    final resolved = settings.withProjectDefaults();
    expect(resolved.endpoint, Ollama.endpoint);
    expect(resolved.model, Ollama.defaultModel);
    expect(resolved.apiKey, isEmpty);
  });

  test('Ollama does not require a server key either', () {
    const settings = AiSettings(
      enabled: true,
      provider: AiProvider.ollama,
    );
    expect(settings.isReady(serverHasKey: false), isTrue);
  });

  test('disabled settings are never ready regardless of fields', () {
    const settings = AiSettings(
      enabled: false,
      endpoint: 'https://x',
      model: 'm',
      apiKey: 'sk',
    );
    expect(settings.ready, isFalse);
  });

  test('DeepSeek chat completions URL uses the official v1 path', () {
    expect(
      OpenAiCompatibleClient.chatCompletionsUrl(DeepSeek.endpoint),
      'https://api.deepseek.com/v1/chat/completions',
    );
    expect(
      OpenAiCompatibleClient.chatCompletionsUrl('https://api.deepseek.com/v1'),
      'https://api.deepseek.com/v1/chat/completions',
    );
  });

  group('AiSettings copyWith', () {
    test('replaces only the specified fields', () {
      const base = AiSettings(
        enabled: false,
        endpoint: 'https://x',
        apiKey: 'sk',
        model: 'm',
        provider: AiProvider.deepseek,
      );
      final next = base.copyWith(enabled: true, model: 'm2');
      expect(next.enabled, isTrue);
      expect(next.endpoint, 'https://x');
      expect(next.apiKey, 'sk');
      expect(next.model, 'm2');
      expect(next.provider, AiProvider.deepseek);
    });

    test('switching to ollama keeps the other fields untouched', () {
      const base = AiSettings(
        enabled: true,
        endpoint: 'https://api.deepseek.com',
        apiKey: 'sk',
        model: 'deepseek-chat',
      );
      final next = base.copyWith(provider: AiProvider.ollama);
      expect(next.provider, AiProvider.ollama);
      expect(next.endpoint, 'https://api.deepseek.com');
    });
  });

  group('AiSettings JSON', () {
    test('round-trips through toJson / fromJson', () {
      const original = AiSettings(
        enabled: true,
        endpoint: 'https://example.invalid/',
        apiKey: 'sk-test',
        model: 'deepseek-reasoner',
        provider: AiProvider.ollama,
      );
      final encoded = jsonEncode(original.toJson());
      final decoded = AiSettings.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.enabled, original.enabled);
      expect(decoded.endpoint, original.endpoint);
      expect(decoded.apiKey, original.apiKey);
      expect(decoded.model, original.model);
      expect(decoded.provider, original.provider);
    });

    test('fromJson defaults provider to deepseek when missing or unknown',
        () {
      expect(
        AiSettings.fromJson({'enabled': false}).provider,
        AiProvider.deepseek,
      );
      expect(
        AiSettings.fromJson({'provider': 'mystery'}).provider,
        AiProvider.deepseek,
      );
    });

    test('fromJson handles missing fields gracefully', () {
      final s = AiSettings.fromJson(const {});
      expect(s.enabled, isFalse);
      expect(s.endpoint, '');
      expect(s.apiKey, '');
      expect(s.model, '');
      expect(s.provider, AiProvider.deepseek);
    });
  });

  group('SharedPreferencesAiSettingsRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns defaults when nothing is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesAiSettingsRepository(prefs);
      final loaded = await repo.load();
      expect(loaded.enabled, isFalse);
      expect(loaded.endpoint, '');
    });

    test('persists and reloads settings', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesAiSettingsRepository(prefs);
      const settings = AiSettings(
        enabled: true,
        endpoint: 'https://x',
        apiKey: 'sk',
        model: 'm',
        provider: AiProvider.ollama,
      );
      await repo.save(settings);
      final loaded = await repo.load();
      expect(loaded.enabled, isTrue);
      expect(loaded.endpoint, 'https://x');
      expect(loaded.apiKey, 'sk');
      expect(loaded.model, 'm');
      expect(loaded.provider, AiProvider.ollama);
    });

    test('falls back to defaults when stored JSON is corrupt', () async {
      SharedPreferences.setMockInitialValues({
        'universal_reader.ai.v1': 'not-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesAiSettingsRepository(prefs);
      final loaded = await repo.load();
      expect(loaded.enabled, isFalse);
      expect(loaded.endpoint, '');
    });

    test('falls back to defaults when stored JSON is not an object', () async {
      SharedPreferences.setMockInitialValues({
        'universal_reader.ai.v1': '[1,2,3]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesAiSettingsRepository(prefs);
      final loaded = await repo.load();
      expect(loaded.endpoint, '');
    });

    test('treats an empty stored value as defaults', () async {
      SharedPreferences.setMockInitialValues({'universal_reader.ai.v1': ''});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesAiSettingsRepository(prefs);
      expect((await repo.load()).enabled, isFalse);
    });
  });

  group('InMemoryAiSettingsRepository', () {
    test('starts with the configured defaults', () async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(enabled: true, model: 'm'),
      );
      final loaded = await repo.load();
      expect(loaded.enabled, isTrue);
      expect(loaded.model, 'm');
    });

    test('persists the most recent save', () async {
      final repo = InMemoryAiSettingsRepository();
      await repo.save(const AiSettings(enabled: true, model: 'm1'));
      await repo.save(const AiSettings(enabled: true, model: 'm2'));
      expect((await repo.load()).model, 'm2');
    });
  });
}
