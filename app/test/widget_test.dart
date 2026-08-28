import 'dart:convert';

import 'package:app/core/library_repository.dart';
import 'package:app/core/locale_controller.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('renders the library shell from a repository', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            InMemoryLibraryRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Universal Reader'), findsOneWidget);
    expect(find.text('全部书籍'), findsOneWidget);
    expect(find.text('阅读助手'), findsNothing);
  });

  testWidgets('settings expose a disabled reading assistant', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            InMemoryLibraryRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('阅读助手'), findsOneWidget);
    expect(find.text('启用阅读助手'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
  });

  testWidgets('can render the library shell in English', (tester) async {
    final locales = LocaleController()..language = AppLanguage.en;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            InMemoryLibraryRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
          localeProvider.overrideWith((ref) => locales),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('All books'), findsOneWidget);
    expect(find.text('全部书籍'), findsNothing);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Reading assistant'), findsOneWidget);
  });

  testWidgets('opens imported plain text in the reader', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'notes.txt',
      utf8.encode('第一章\n\nhello from notes'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repository),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('notes').first);
    await tester.pumpAndSettle();
    expect(find.text('hello from notes'), findsOneWidget);
    expect(find.textContaining('白是一种包容'), findsNothing);
  });

  testWidgets('unknown reader ids do not fall back to another book', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            InMemoryLibraryRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    final context = tester.element(find.byType(LibraryPage));
    GoRouter.of(context).go('/reader/missing-book');
    await tester.pumpAndSettle();
    expect(find.text('设计中的设计'), findsNothing);
    expect(find.text('找不到这本书的原文件。'), findsOneWidget);
  });

  testWidgets('reading settings expose a body font size control', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', utf8.encode('hello from notes'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repository),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('notes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('阅读设置'));
    await tester.pumpAndSettle();
    expect(find.text('正文字号'), findsOneWidget);
  });
}
