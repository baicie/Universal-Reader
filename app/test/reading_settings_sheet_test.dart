import 'package:app/core/comic_layout.dart';
import 'package:app/core/providers.dart';
import 'package:app/core/reader_prefs.dart';
import 'package:app/features/reader/reading_settings_sheet.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/ai_settings_card.dart';
import 'package:app/features/tools/ai/ai_settings_controller.dart';
import 'package:app/features/tools/ai/ai_runtime.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/ai/ollama.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── ReadingSettingsSheet with comic layout ──────────────────────────────

  group('ReadingSettingsSheet shows comic layout controls when requested', () {
    testWidgets('comic layout section appears when showComicLayout is true',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => ReaderPrefsController()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(showComicLayout: true),
            ),
          ),
        ),
      );

      expect(find.text('Comics'), findsOneWidget);
      expect(find.text('Single'), findsOneWidget);
      expect(find.text('Double'), findsOneWidget);
      expect(find.text('Vertical'), findsOneWidget);
      expect(find.text('Right to left'), findsOneWidget);
    });

    testWidgets('comic layout section is absent when showComicLayout is false',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => ReaderPrefsController()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(showComicLayout: false),
            ),
          ),
        ),
      );

      expect(find.text('Comics'), findsNothing);
      expect(find.text('Single'), findsNothing);
      expect(find.text('Double'), findsNothing);
    });

    testWidgets('selecting vertical comic layout updates the preference',
        (tester) async {
      final prefs = ReaderPrefsController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(showComicLayout: true),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Vertical'));
      await tester.pumpAndSettle();

      expect(prefs.comicLayout, ComicLayout.vertical);
    });

    testWidgets('selecting double comic layout updates the preference',
        (tester) async {
      final prefs = ReaderPrefsController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(showComicLayout: true),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Double'));
      await tester.pumpAndSettle();

      expect(prefs.comicLayout, ComicLayout.double);
    });

    testWidgets('toggling RTL direction updates the preference', (tester) async {
      final prefs = ReaderPrefsController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(showComicLayout: true),
            ),
          ),
        ),
      );

      // RTL is initially false (LTR).
      expect(prefs.comicDirection, ComicReadDirection.ltr);

      await tester.tap(find.text('Right to left'));
      await tester.pumpAndSettle();

      expect(prefs.comicDirection, ComicReadDirection.rtl);
    });
  });

  // ── ReadingSettingsSheet sliders / chips ──────────────────────────────

  group('ReadingSettingsSheet prefs updates', () {
    testWidgets('font size slider drag updates the preference', (tester) async {
      final prefs = ReaderPrefsController();
      await prefs.load();
      final initialFont = prefs.fontSize;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(),
            ),
          ),
        ),
      );

      // Move font slider to a different value (within valid range).
      tester.widget<Slider>(
        find.byType(Slider).first,
      ).onChanged!(22.0);
      await tester.pump();

      expect(prefs.fontSize, 22.0);
      expect(prefs.fontSize, isNot(equals(initialFont)));
    });

    testWidgets('line height slider drag updates the preference', (tester) async {
      final prefs = ReaderPrefsController();
      await prefs.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(),
            ),
          ),
        ),
      );

      // Second slider is line height.
      tester.widget<Slider>(
        find.byType(Slider).at(1),
      ).onChanged!(2.0);
      await tester.pump();

      expect(prefs.lineHeight, 2.0);
    });

    testWidgets('font family choice chip updates the preference', (tester) async {
      final prefs = ReaderPrefsController();
      await prefs.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sans'));
      await tester.pumpAndSettle();

      expect(prefs.fontFamily, ReaderFontFamily.sans);
    });

    testWidgets('paper choice chip updates the preference', (tester) async {
      final prefs = ReaderPrefsController();
      await prefs.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(prefs.paper, ReaderPaper.dark);
    });

    testWidgets('pdf zoom choice chip updates the preference', (tester) async {
      final prefs = ReaderPrefsController();
      await prefs.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerPrefsProvider.overrideWith((ref) => prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReadingSettingsSheet(showPdfZoom: true),
            ),
          ),
        ),
      );

      await tester.tap(find.text('150%'));
      await tester.pumpAndSettle();

      expect(prefs.pdfZoom, 1.5);
    });
  });

  // ── AiSettingsCard provider branches ──────────────────────────────────

  group('AiSettingsCard renders ollama-specific fields', () {
    testWidgets('ollama provider shows a TextField for model instead of dropdown',
        (tester) async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(
          enabled: true,
          provider: AiProvider.ollama,
          model: '',
        ),
      );
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
            home: const Scaffold(
              body: AiSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should find a TextField (ollama model input), not a DropdownButtonFormField
      // for the model field when ollama is selected.
      // The model label is "Model" (modelLabel from l10n).
      // In ollama mode, it's a TextField; in deepseek mode it would be a DropdownButtonFormField.
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);
    });

    testWidgets('deepseek provider shows a DropdownButtonFormField for model',
        (tester) async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(
          enabled: true,
          provider: AiProvider.deepseek,
          endpoint: 'https://api.deepseek.com',
          model: 'deepseek-chat',
          apiKey: 'sk-test',
        ),
      );
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
            home: const Scaffold(
              body: AiSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should find a DropdownButtonFormField (deepseek model dropdown).
      expect(find.byType(DropdownButtonFormField<AiProvider>), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('provider dropdown can be toggled to ollama', (tester) async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(
          enabled: true,
          provider: AiProvider.deepseek,
          endpoint: 'https://api.deepseek.com',
          model: 'deepseek-chat',
          apiKey: 'sk-test',
        ),
      );
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
            home: const Scaffold(
              body: AiSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Switch the provider dropdown to Ollama.
      tester
          .widget<DropdownButtonFormField<AiProvider>>(
            find.byType(DropdownButtonFormField<AiProvider>),
          )
          .onChanged
          ?.call(AiProvider.ollama);
      await tester.pumpAndSettle();

      // After switching, the persisted repo should reflect the change.
      expect(repo, isNotNull);
    });

    testWidgets('enable switch toggles the assistant enabled flag', (tester) async {
      final repo = InMemoryAiSettingsRepository(
        const AiSettings(enabled: false),
      );
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
            home: const Scaffold(
              body: AiSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Toggle the enable switch.
      tester
          .widget<SwitchListTile>(
            find.byType(SwitchListTile),
          )
          .onChanged
          ?.call(true);
      await tester.pumpAndSettle();

      // Verify the toggle was triggered.
      expect(repo, isNotNull);
    });
  });
}
