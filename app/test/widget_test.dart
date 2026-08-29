import 'dart:convert';

import 'package:app/core/annotated_text.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/core/locale_controller.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_bookmarks_pane.dart';
import 'package:app/features/reader/reader_notes_pane.dart';
import 'package:app/features/reader/reader_search_pane.dart';
import 'package:app/features/reader/selection_confirm_bar.dart';
import 'package:app/features/tools/ai/ai_runtime.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/l10n/l10n.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';

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

  testWidgets('empty library does not invent seed books', (tester) async {
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
    expect(find.text('设计中的设计'), findsNothing);
    expect(find.text('书库还是空的'), findsOneWidget);
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
    expect(find.text('DeepSeek'), findsOneWidget);
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

  testWidgets('opens imported epub chapters in the reader', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('story.epub', minimalEpubBytes());
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
    await tester.tap(find.text('Fixture Book').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('hello from epub'), findsOneWidget);
    expect(find.textContaining('阅读器尚未接入'), findsNothing);
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

  testWidgets('paints a saved quote in the chapter body', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', utf8.encode('hello from notes'));
    final notes = InMemoryAnnotationRepository();
    await notes.save('notes.txt', [
      ReaderAnnotation(
        id: 'n1',
        note: 'keep',
        quote: 'hello from notes',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repository),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
          aiRuntimeProvider.overrideWithValue(
            AiRuntime.local(
              InMemoryConversationRepository(),
              annotations: notes,
            ),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('notes').first);
    await tester.pumpAndSettle();
    expect(find.byKey(annotatedQuoteKey), findsOneWidget);
  });

  testWidgets('opens an imported comic page', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'pages.cbz',
      zipNamedFiles({'page-01.png': tinyPngBytes()}),
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
    await tester.tap(find.text('pages').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comic-page')), findsOneWidget);
    expect(find.textContaining('阅读器尚未接入'), findsNothing);
  });

  testWidgets('adds a bookmark that can jump without leaving the book', (
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
    await tester.tap(find.byTooltip('添加书签'));
    await tester.pump();
    expect(find.byKey(bookmarksPanelKey), findsOneWidget);
    expect(find.textContaining('text|'), findsOneWidget);
    await tester.tap(find.textContaining('text|'));
    await tester.pump();
    expect(find.text('hello from notes'), findsOneWidget);
    await tester.tap(find.byTooltip('删除书签'));
    await tester.pump();
    expect(find.textContaining('text|'), findsNothing);
    expect(find.text('hello from notes'), findsOneWidget);
  });

  testWidgets('reader has no selection confirm without a quote', (
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
    expect(find.byKey(selectionConfirmKey), findsNothing);
  });

  testWidgets('selection confirm bar saves the quote', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SelectionConfirmBar(
            quote: 'hello from notes',
            saveLabel: '保存选区',
            onSave: () => saved = true,
            onDismiss: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(selectionConfirmKey), findsOneWidget);
    expect(find.text('hello from notes'), findsOneWidget);
    await tester.tap(find.text('保存选区'));
    expect(saved, isTrue);
  });

  testWidgets('opens a saved note and can delete it without leaving the book', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', utf8.encode('hello from notes'));
    final notes = InMemoryAnnotationRepository();
    await notes.save('notes.txt', [
      ReaderAnnotation(
        id: 'n1',
        note: 'keep',
        quote: 'hello from notes',
        locatorLabel: 'text|0',
        source: userNoteSource,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repository),
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
          aiRuntimeProvider.overrideWithValue(
            AiRuntime.local(
              InMemoryConversationRepository(),
              annotations: notes,
            ),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('notes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('笔记'));
    await tester.pump();
    expect(find.byKey(notesPanelKey), findsOneWidget);
    expect(find.text('hello from notes'), findsWidgets);
    await tester.tap(find.text('hello from notes').last);
    await tester.pump();
    expect(find.text('hello from notes'), findsWidgets);
    await tester.tap(find.byKey(const Key('delete-note-n1')));
    await tester.pump();
    expect(find.byKey(const Key('delete-note-n1')), findsNothing);
    expect(find.text('hello from notes'), findsOneWidget);
  });

  testWidgets('search hits jump inside the current book', (tester) async {
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
    await tester.tap(find.byTooltip('在这本书里搜索'));
    await tester.pump();
    expect(find.byKey(searchPanelKey), findsOneWidget);
    await tester.enterText(
      find.byKey(readerSearchFieldKey),
      'hello from notes',
    );
    await tester.pump();
    expect(find.byKey(const Key('search-hit-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-hit-0')));
    await tester.pump();
    expect(find.text('hello from notes'), findsWidgets);
    expect(find.textContaining('阅读器尚未接入'), findsNothing);
  });

  testWidgets('empty search does not invent hits', (tester) async {
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
    await tester.tap(find.byTooltip('在这本书里搜索'));
    await tester.pump();
    await tester.enterText(find.byKey(readerSearchFieldKey), '   ');
    await tester.pump();
    expect(find.byKey(const Key('search-hit-0')), findsNothing);
  });

  testWidgets('favorites section stays empty until a book is starred', (
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
    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('notes'), findsNothing);
    expect(find.text('设计中的设计'), findsNothing);
    expect(find.text('没有找到匹配的书籍'), findsOneWidget);
  });

  testWidgets('starring an imported book shows it only in favorites', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', utf8.encode('hello from notes'));
    await repository.importBytes('other.txt', utf8.encode('another book'));
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
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('notes'),
          matching: find.byType(BookCard),
        ),
        matching: find.byTooltip('加入收藏'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('notes'), findsWidgets);
    expect(find.text('other'), findsNothing);
    expect(find.text('设计中的设计'), findsNothing);
  });

  testWidgets('a new collection only lists books added to it', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', utf8.encode('hello from notes'));
    await repository.importBytes('other.txt', utf8.encode('another book'));
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
    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建收藏夹'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '今晚读',
    );
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('今晚读'), findsWidgets);
    final drawer = find.byType(Drawer);
    if (tester.any(drawer)) {
      Navigator.of(tester.element(drawer)).pop();
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('notes'),
          matching: find.byType(BookCard),
        ),
        matching: find.byTooltip('书籍操作'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加到「今晚读」'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今晚读').last);
    await tester.pumpAndSettle();
    expect(find.text('notes'), findsWidgets);
    expect(find.text('other'), findsNothing);
    expect(find.text('设计中的设计'), findsNothing);
  });

  testWidgets('deleting a book keeps the other book and invents nothing', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', utf8.encode('hello from notes'));
    await repository.importBytes('other.txt', utf8.encode('another book'));
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
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('notes'),
          matching: find.byType(BookCard),
        ),
        matching: find.byTooltip('书籍操作'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('从书库删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(find.text('notes'), findsNothing);
    expect(find.text('other'), findsWidgets);
    expect(find.text('设计中的设计'), findsNothing);
  });
}
