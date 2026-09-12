import 'package:app/core/library_repository.dart';
import 'package:app/core/locale_controller.dart';
import 'package:app/core/providers.dart';
import 'package:app/core/reader_prefs.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/library/shelf_store.dart';
import 'package:app/features/tools/ai/ai_runtime.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/ai_settings_controller.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('libraryRepositoryProvider', () {
    test('throws StateError when the host has not overridden it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      try {
        container.read(libraryRepositoryProvider);
        fail('expected libraryRepositoryProvider to throw');
      } catch (e) {
        expect(e.toString(), contains('Bad state: Library repository must be overridden at startup'));
      }
    });
  });

  group('aiSettingsRepositoryProvider', () {
    test('throws StateError when the host has not overridden it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      try {
        container.read(aiSettingsRepositoryProvider);
        fail('expected aiSettingsRepositoryProvider to throw');
      } catch (e) {
        expect(e.toString(), contains('Bad state: AI settings repository must be overridden at startup'));
      }
    });
  });

  group('shelfRepositoryProvider', () {
    test('defaults to an in-memory shelf repository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(shelfRepositoryProvider),
        isA<InMemoryShelfRepository>(),
      );
    });
  });

  group('annotationRepositoryProvider', () {
    test('defaults to an in-memory annotation repository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(annotationRepositoryProvider),
        isA<InMemoryAnnotationRepository>(),
      );
    });
  });

  group('libraryProvider', () {
    test('wires the overridden repository into a PersistedLibraryController',
        () async {
      final repository = InMemoryLibraryRepository();
      final container = ProviderContainer(
        overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller =
          container.read(libraryProvider);
      await controller.waitUntilReady();
      expect(controller.documents, isEmpty);
      expect(controller.loading, isFalse);
    });

    test('honours the overridden shelf repository when toggling favorites',
        () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('doc-1.txt', [1, 2, 3]);
      final shelf = InMemoryShelfRepository();
      final container = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repository),
          shelfRepositoryProvider.overrideWithValue(shelf),
        ],
      );
      addTearDown(container.dispose);
      final controller =
          container.read(libraryProvider);
      await controller.waitUntilReady();
      await controller.toggleFavorite('doc-1.txt');
      expect((await shelf.load()).favoriteIds, contains('doc-1.txt'));
    });

    test('watches the annotation repository provider', () async {
      final container = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(InMemoryLibraryRepository()),
          annotationRepositoryProvider.overrideWithValue(
            InMemoryAnnotationRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller =
          container.read(libraryProvider);
      await controller.waitUntilReady();
      expect(controller.annotationRepository, isA<InMemoryAnnotationRepository>());
    });
  });

  group('aiSettingsProvider', () {
    test('wires the overridden repository into an AiSettingsController',
        () async {
      final container = ProviderContainer(
        overrides: [
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(aiSettingsProvider);
      expect(controller, isA<AiSettingsController>());
      while (controller.loading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(controller.loading, isFalse);
    });
  });

  group('themeProvider', () {
    test('defaults to ThemeMode.light', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeProvider), ThemeMode.light);
    });

    test('can be set to ThemeMode.dark by the host', () {
      final container = ProviderContainer(
        overrides: [themeProvider.overrideWith((_) => ThemeMode.dark)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeProvider), ThemeMode.dark);
    });
  });

  group('localeProvider', () {
    test('defaults to a fresh LocaleController', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(localeProvider), isA<LocaleController>());
    });
  });

  group('readerPrefsProvider', () {
    test('defaults to a fresh ReaderPrefsController', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(readerPrefsProvider), isA<ReaderPrefsController>());
    });
  });

  group('aiRuntimeProvider', () {
    test('defaults to a local AiRuntime backed by an in-memory conversation store',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final runtime = container.read(aiRuntimeProvider);
      expect(runtime, isA<AiRuntime>());
      expect(runtime.useGateway, isFalse, reason: 'default is local');
      expect(runtime.conversations, isA<InMemoryConversationRepository>());
    });
  });
}