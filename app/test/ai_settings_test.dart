import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/deepseek.dart';
import 'package:app/features/tools/ai/model_client.dart';
import 'package:app/features/tools/ai/ollama.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
