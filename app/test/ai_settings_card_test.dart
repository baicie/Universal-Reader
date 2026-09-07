import 'package:app/core/providers.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/ai_settings_card.dart';
import 'package:app/features/tools/ai/ai_runtime.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/ai/deepseek.dart';
import 'package:app/features/tools/ai/ollama.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a widget tree with AiSettingsCard wired to the given repository
/// and runtime, inside a [MaterialApp] with stub localizations.
Future<void> pumpSettingsCard(
  WidgetTester tester, {
  required AiSettingsRepository repository,
  required AiRuntime runtime,
  Widget? child,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiSettingsRepositoryProvider.overrideWithValue(repository),
        aiRuntimeProvider.overrideWithValue(runtime),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: child ?? const AiSettingsCard(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('AiSettingsCard endpoint field', () {
    testWidgets('endpoint TextField is shown when useGateway is false',
        (tester) async {
      await pumpSettingsCard(
        tester,
        repository: InMemoryAiSettingsRepository(
          const AiSettings(
            enabled: true,
            provider: AiProvider.deepseek,
            endpoint: DeepSeek.endpoint,
            model: DeepSeek.defaultModel,
            apiKey: 'sk-test',
          ),
        ),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      // The endpoint field label must be present.
      expect(find.text(AppLocalizations.of(tester.element(find.byType(Scaffold))).endpointLabel),
          findsOneWidget);
    });

    testWidgets('endpoint TextField is hidden when useGateway is true',
        (tester) async {
      await pumpSettingsCard(
        tester,
        repository: InMemoryAiSettingsRepository(
          const AiSettings(
            enabled: true,
            provider: AiProvider.deepseek,
            endpoint: '',
            model: 'deepseek-chat',
            apiKey: '',
          ),
        ),
        runtime: AiRuntime(
          useGateway: true,
          baseUrl: 'http://localhost:8787',
          serverHasKey: false,
          conversations: InMemoryConversationRepository(),
        ),
      );

      // With gateway mode, the endpoint field must not be rendered.
      expect(find.text(AppLocalizations.of(tester.element(find.byType(Scaffold))).endpointLabel),
          findsNothing);
    });
  });

  group('AiSettingsCard gateway note', () {
    testWidgets('gateway note is shown when useGateway is true',
        (tester) async {
      await pumpSettingsCard(
        tester,
        repository: InMemoryAiSettingsRepository(const AiSettings()),
        runtime: AiRuntime(
          useGateway: true,
          baseUrl: 'http://localhost:8787',
          serverHasKey: false,
          conversations: InMemoryConversationRepository(),
        ),
      );

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.assistantGatewayNote), findsOneWidget);
    });

    testWidgets('gateway note is NOT shown when useGateway is false',
        (tester) async {
      await pumpSettingsCard(
        tester,
        repository: InMemoryAiSettingsRepository(const AiSettings()),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.assistantGatewayNote), findsNothing);
    });
  });

  group('AiSettingsCard apiKey field', () {
    testWidgets('apiKey hint uses the optional label when serverHasKey is true',
        (tester) async {
      await pumpSettingsCard(
        tester,
        repository: InMemoryAiSettingsRepository(
          const AiSettings(
            enabled: true,
            provider: AiProvider.deepseek,
            endpoint: DeepSeek.endpoint,
            model: DeepSeek.defaultModel,
            apiKey: '',
          ),
        ),
        runtime: AiRuntime(
          useGateway: false,
          baseUrl: '',
          serverHasKey: true,
          conversations: InMemoryConversationRepository(),
        ),
      );

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.apiKeyOptionalHint), findsOneWidget);
    });

    testWidgets('apiKey hint uses the required label when serverHasKey is false',
        (tester) async {
      await pumpSettingsCard(
        tester,
        repository: InMemoryAiSettingsRepository(
          const AiSettings(
            enabled: true,
            provider: AiProvider.deepseek,
            endpoint: DeepSeek.endpoint,
            model: DeepSeek.defaultModel,
            apiKey: '',
          ),
        ),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.apiKeyHint), findsOneWidget);
    });

    testWidgets('apiKey TextField is NOT shown for the ollama provider',
        (tester) async {
      await pumpSettingsCard(
        tester,
        repository: InMemoryAiSettingsRepository(
          const AiSettings(
            enabled: true,
            provider: AiProvider.ollama,
            model: Ollama.defaultModel,
          ),
        ),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      // apiKeyLabel is rendered in the TextField label; the hint text is either
      // apiKeyHint or apiKeyOptionalHint — neither should appear for ollama.
      expect(find.text(l10n.apiKeyHint), findsNothing);
      expect(find.text(l10n.apiKeyOptionalHint), findsNothing);
    });
  });

  group('AiSettingsCard provider dropdown', () {
    testWidgets('switching from deepseek to ollama clears endpoint and model',
        (tester) async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(
          enabled: true,
          provider: AiProvider.deepseek,
          endpoint: DeepSeek.endpoint,
          model: 'deepseek-chat',
          apiKey: 'sk-test',
        ),
      );
      await pumpSettingsCard(
        tester,
        repository: repo,
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      // Switch to ollama.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiSettingsRepositoryProvider.overrideWithValue(repo),
            aiRuntimeProvider.overrideWithValue(
              AiRuntime.local(InMemoryConversationRepository()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AiSettingsCard()),
          ),
        ),
      );
      await tester.pump();

      tester
          .widget<DropdownButtonFormField<AiProvider>>(
            find.byType(DropdownButtonFormField<AiProvider>),
          )
          .onChanged
          ?.call(AiProvider.ollama);
      await tester.pumpAndSettle();

      final saved = await repo.load();
      expect(saved.provider, AiProvider.ollama);
      // The card's onChanged for provider resets endpoint and model to empty.
      expect(saved.endpoint, isEmpty);
      expect(saved.model, isEmpty);
    });

    testWidgets('switching from ollama to deepseek resets endpoint and model',
        (tester) async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(
          enabled: true,
          provider: AiProvider.ollama,
          model: 'llama3.2',
        ),
      );
      await pumpSettingsCard(
        tester,
        repository: repo,
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      tester
          .widget<DropdownButtonFormField<AiProvider>>(
            find.byType(DropdownButtonFormField<AiProvider>),
          )
          .onChanged
          ?.call(AiProvider.deepseek);
      await tester.pumpAndSettle();

      final saved = await repo.load();
      expect(saved.provider, AiProvider.deepseek);
      expect(saved.endpoint, isEmpty);
      expect(saved.model, isEmpty);
    });
  });

  group('AiSettingsCard ollama model TextField', () {
    testWidgets('ollama model TextField fires onChanged on text entry',
        (tester) async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(
          enabled: true,
          provider: AiProvider.ollama,
          model: '',
        ),
      );
      await pumpSettingsCard(
        tester,
        repository: repo,
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      // Find the model TextField (ollama mode → TextField, not Dropdown).
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      final modelField = textFields.firstWhere(
        (f) => f.decoration?.labelText ==
            AppLocalizations.of(tester.element(find.byType(Scaffold))).modelLabel,
      );

      modelField.onChanged?.call('llama3.2:latest');
      await tester.pumpAndSettle();

      final saved = await repo.load();
      expect(saved.model, 'llama3.2:latest');
    });
  });

  group('AiSettingsCard deepseek model dropdown', () {
    testWidgets('deepseek dropdown renders with the saved model selected',
        (tester) async {
      // The DropdownButtonFormField<String> reflects the saved model.
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(
          enabled: true,
          provider: AiProvider.deepseek,
          endpoint: DeepSeek.endpoint,
          model: 'custom-model-42',
          apiKey: 'sk-test',
        ),
      );
      await pumpSettingsCard(
        tester,
        repository: repo,
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget);

      // The selected model is rendered as a Text child of the dropdown button.
      // Flutter's DropdownButton composes the selected item's child into the
      // tree, so the saved model text must be visible.
      expect(
        find.descendant(of: dropdownFinder, matching: find.text('custom-model-42')),
        findsOneWidget,
      );
    });

    testWidgets('deepseek model dropdown selection fires update',
        (tester) async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(
          enabled: true,
          provider: AiProvider.deepseek,
          endpoint: DeepSeek.endpoint,
          model: 'deepseek-chat',
          apiKey: 'sk-test',
        ),
      );
      await pumpSettingsCard(
        tester,
        repository: repo,
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );

      // Switch to deepseek-reasoner.
      dropdown.onChanged?.call('deepseek-reasoner');
      await tester.pumpAndSettle();

      final saved = await repo.load();
      expect(saved.model, 'deepseek-reasoner');
    });
  });

  group('AiSettingsCard _sync', () {
    testWidgets(
        'TextEditingControllers are pre-filled from repository on first load',
        (tester) async {
      await pumpSettingsCard(
        tester,
        repository: InMemoryAiSettingsRepository(
          const AiSettings(
            enabled: true,
            provider: AiProvider.deepseek,
            endpoint: 'https://custom.endpoint.example/',
            model: 'custom-model',
            apiKey: 'sk-synced',
          ),
        ),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      // The card pre-fills the endpoint field from the repository.
      final endpointField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(endpointField.controller?.text, 'https://custom.endpoint.example/');
    });
  });

  group('AiSettingsCard privacy note', () {
    testWidgets('privacy note is always rendered', (tester) async {
      await pumpSettingsCard(
        tester,
        repository: InMemoryAiSettingsRepository(const AiSettings()),
        runtime: AiRuntime.local(InMemoryConversationRepository()),
      );

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.assistantPrivacyNote), findsOneWidget);
    });
  });
}
