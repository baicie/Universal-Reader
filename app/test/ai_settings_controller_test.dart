import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/ai_settings_controller.dart';
import 'package:app/features/tools/ai/deepseek.dart';
import 'package:app/features/tools/ai/ollama.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiSettingsController', () {
    test('starts in the loading state with default settings', () {
      final controller = AiSettingsController(
        repository: InMemoryAiSettingsRepository(),
      );

      expect(controller.loading, isTrue);
      expect(controller.settings, const AiSettings());
    });

    test('load() resolves project defaults for an empty repository', () async {
      final controller = AiSettingsController(
        repository: InMemoryAiSettingsRepository(),
      );
      await controller.load();

      expect(controller.loading, isFalse);
      expect(controller.settings.endpoint, DeepSeek.endpoint);
      expect(controller.settings.model, DeepSeek.defaultModel);
    });

    test('load() notifies listeners once settings are ready', () async {
      final notifications = <int>[];
      final controller = AiSettingsController(
        repository: InMemoryAiSettingsRepository(),
      );
      controller.addListener(() => notifications.add(controller.loading ? 0 : 1));

      await controller.load();

      expect(notifications, [1]);
      expect(controller.loading, isFalse);
    });

    test('update() persists the new settings', () async {
      final repo = InMemoryAiSettingsRepository();
      final controller = AiSettingsController(repository: repo);
      await controller.load();

      const next = AiSettings(
        enabled: true,
        endpoint: 'https://example.invalid/',
        apiKey: 'sk-saved',
        model: 'deepseek-reasoner',
      );
      await controller.update(next);

      expect(controller.settings.enabled, isTrue);
      expect(controller.settings.model, 'deepseek-reasoner');
      expect(repo, isNotNull);
      // Re-read from the repository to confirm persistence.
      final reloaded = await repo.load();
      expect(reloaded.enabled, isTrue);
      expect(reloaded.endpoint, 'https://example.invalid/');
      expect(reloaded.apiKey, 'sk-saved');
      expect(reloaded.model, 'deepseek-reasoner');
    });

    test('update() notifies listeners with the new settings applied', () async {
      final controller = AiSettingsController(
        repository: InMemoryAiSettingsRepository(),
      );
      await controller.load();

      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.update(
        const AiSettings(enabled: true, model: 'deepseek-chat'),
      );

      expect(notifications, 1);
      expect(controller.settings.enabled, isTrue);
    });

    test('preserves settings returned by the repository as-is', () async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(
          enabled: true,
          endpoint: 'https://saved.example/',
          apiKey: 'sk-saved',
          model: 'deepseek-reasoner',
          provider: AiProvider.deepseek,
        ),
      );
      final controller = AiSettingsController(repository: repo);
      await controller.load();

      expect(controller.settings.endpoint, 'https://saved.example/');
      expect(controller.settings.apiKey, 'sk-saved');
      expect(controller.settings.model, 'deepseek-reasoner');
      // ready should be true because the saved record is complete.
      expect(controller.settings.ready, isTrue);
    });
  });
}
