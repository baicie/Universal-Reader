import 'dart:convert';

import 'package:app/core/annotated_text.dart';
import 'package:app/core/epub_document.dart';
import 'package:app/core/foliate_session.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/core/locale_controller.dart';
import 'package:app/core/locator_codec.dart';
import 'package:app/core/models.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_bookmarks_pane.dart';
import 'package:app/features/reader/reader_notes_pane.dart';
import 'package:app/features/reader/reader_search_pane.dart';
import 'package:app/features/reader/renderers/isolated_foliate_view.dart';
import 'package:app/features/reader/selection_confirm_bar.dart';
import 'package:app/features/tools/ai/ai_runtime.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/l10n/l10n.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/epub_fixture.dart';
import 'support/fb2_fixture.dart';
import 'support/image_fixture.dart';
import 'support/pdf_fixture.dart';

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

  testWidgets('epub nested toc entry scrolls to the chapter fragment', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('story.epub', nestedNavEpubBytes());
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
    await tester.tap(find.byTooltip('目录'));
    await tester.pumpAndSettle();
    expect(find.text('注释'), findsOneWidget);
    expect(find.text('幽灵章'), findsNothing);
    await tester.tap(find.text('注释'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IsolatedFoliateView>(find.byType(IsolatedFoliateView))
          .fragment,
      'note',
    );
    expect(find.textContaining('hello from epub'), findsOneWidget);
    expect(find.text('设计中的设计'), findsNothing);
  });

  testWidgets('fb2 nested toc shows both navigable chapters', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('book.fb2', fb2NestedSectionBytes());
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
    await tester.tap(find.text('FB2 Book').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('目录'));
    await tester.pumpAndSettle();
    // The fixture produces two navigable chapters: "Part I" and "Part II".
    expect(find.text('Part I'), findsWidgets);
    expect(find.text('Part II'), findsOneWidget);
    // Tapping the second chapter navigates the reader.
    await tester.tap(find.text('Part II'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
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

  testWidgets('opens the book even when the annotation store throws on load', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('story.epub', minimalEpubBytes());
    final broken = _ThrowingAnnotationRepository();
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
              annotations: broken,
            ),
          ),
        ],
        child: const UniversalReaderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Fixture Book').first);
    await tester.pumpAndSettle();
    // The reader should still render the book body despite the broken store.
    expect(find.textContaining('hello from epub'), findsOneWidget);
  });

  testWidgets(
    'shows the missing-file surface when the repository cannot read the book',
    (tester) async {
      final repository = _MissingFileRepository();
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
      // Reader must not crash; it should show the missing-file message
      // rather than the book body.
      expect(find.textContaining('hello from epub'), findsNothing);
      expect(find.textContaining('文件'), findsWidgets);
    },
  );

  testWidgets('epub tap turns pages then the next chapter', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'story.epub',
      minimalEpubBytes(
        firstBody:
            '${List.filled(170, 'alpha-page').join(' ')} ${List.filled(50, 'beta-page').join(' ')}',
        secondBody: 'omega-chapter',
      ),
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
    await tester.tap(find.text('Fixture Book').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('alpha-page'), findsOneWidget);
    expect(find.textContaining('beta-page'), findsNothing);
    expect(find.textContaining('omega-chapter'), findsNothing);
    final pages = FoliateSession.open(
      EpubReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'story',
          title: 'Fixture Book',
          author: '',
          format: DocumentFormat.epub,
          type: DocumentType.reflow,
        ),
        bytes: minimalEpubBytes(
          firstBody:
              '${List.filled(170, 'alpha-page').join(' ')} ${List.filled(50, 'beta-page').join(' ')}',
          secondBody: 'omega-chapter',
        ),
      ),
    );
    expect(pages.pageCount, greaterThan(1));
    expect(find.text('1 / ${pages.pageCount}'), findsOneWidget);
    expect(
      tester
          .widget<IsolatedFoliateView>(find.byType(IsolatedFoliateView))
          .pageIndex,
      0,
    );
    final surface = tester.getRect(find.byKey(const Key('foliate-surface')));
    await tester.tapAt(Offset(surface.right - 8, surface.center.dy));
    await tester.pumpAndSettle();
    expect(find.textContaining('beta-page'), findsOneWidget);
    expect(find.textContaining('omega-chapter'), findsNothing);
    expect(find.text('2 / ${pages.pageCount}'), findsOneWidget);
    expect(
      tester
          .widget<IsolatedFoliateView>(find.byType(IsolatedFoliateView))
          .pageIndex,
      1,
    );
    await tester.tapAt(Offset(surface.right - 8, surface.center.dy));
    await tester.pumpAndSettle();
    expect(find.textContaining('omega-chapter'), findsOneWidget);
    final after = tester.getRect(find.byKey(const Key('foliate-surface')));
    await tester.tapAt(Offset(after.right - 8, after.center.dy));
    await tester.pumpAndSettle();
    expect(find.textContaining('omega-chapter'), findsOneWidget);
    expect(find.text('设计中的设计'), findsNothing);
  });

  testWidgets('epub arrow key turns the current page', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'story.epub',
      minimalEpubBytes(
        firstBody:
            '${List.filled(170, 'alpha-page').join(' ')} ${List.filled(50, 'beta-page').join(' ')}',
        secondBody: 'omega-chapter',
      ),
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
    await tester.tap(find.text('Fixture Book').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('beta-page'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.textContaining('beta-page'), findsOneWidget);
    expect(find.textContaining('omega-chapter'), findsNothing);
    expect(find.text('设计中的设计'), findsNothing);
  });

  testWidgets('epub progress slider opens the later chapter page', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'story.epub',
      minimalEpubBytes(
        firstBody:
            '${List.filled(170, 'alpha-page').join(' ')} ${List.filled(50, 'beta-page').join(' ')}',
        secondBody: 'omega-chapter',
      ),
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
    await tester.tap(find.text('Fixture Book').first);
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.9);
    await tester.pumpAndSettle();
    expect(find.textContaining('omega-chapter'), findsOneWidget);
    expect(find.text('设计中的设计'), findsNothing);
  });

  testWidgets('epub resume at saved progress jumps past the first chapter', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('story.epub', minimalEpubBytes());
    await repository.writeReadingState(
      id: 'story.epub',
      progress: 0.9,
      lastOpened: DateTime(2026, 9, 8),
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
    await tester.tap(find.text('Fixture Book').first);
    await tester.pumpAndSettle();
    // A saved progress > 0 must take the reader straight to the second chapter,
    // so the first chapter body should no longer be on screen.
    expect(find.textContaining('hello from epub'), findsNothing);
    expect(find.textContaining('second chapter text'), findsOneWidget);
  });

  testWidgets('plain text seek slider writes the new progress', (tester) async {
    final repository = InMemoryLibraryRepository();
    // Two blank-line-separated sections give TextReaderDocument two chapters.
    await repository.importBytes(
      'notes.txt',
      utf8.encode('first section\n\nsecond section content'),
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
    // _seekProgress exercises the non-HtmlChapteredDocument ChapteredDocument
    // path in ReaderPage (plain text / pdf / comic).
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.9);
    await tester.pumpAndSettle();
    final after = (await repository.load()).singleWhere(
      (item) => item.metadata.id == 'notes.txt',
    );
    expect(after.readingState.progress, 0.9);
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

  testWidgets('opens imported gb18030 text in the reader', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('chapter.txt', const [
      181,
      218,
      210,
      187,
      213,
      194,
    ]);
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
    await tester.tap(find.text('chapter').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('第一章'), findsOneWidget);
    expect(find.textContaining('阅读器尚未接入'), findsNothing);
    expect(find.textContaining('设计中的设计'), findsNothing);
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
    expect(find.text('找不到这本书的原文件。'), findsNWidgets(2));
  });

  testWidgets('reading settings expose body type and paper controls', (
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
    expect(find.text('行距'), findsOneWidget);
    expect(find.text('衬线'), findsOneWidget);
    expect(find.text('跟随应用'), findsOneWidget);
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

  testWidgets('opens imported pdf pages in the reader', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'scan.pdf',
      minimalPdfBytes(pages: ['hello from pdf']),
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
    await tester.tap(find.text('scan').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('hello from pdf'), findsOneWidget);
    expect(find.textContaining('阅读器尚未接入'), findsNothing);
    expect(find.text('设计中的设计'), findsNothing);
  });

  testWidgets('pdf page fills the reading surface', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'scan.pdf',
      minimalPdfBytes(pages: ['hello from pdf']),
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
    await tester.tap(find.text('scan').first);
    await tester.pumpAndSettle();
    final surface = tester.getRect(find.byKey(const Key('pdf-surface')));
    final frame = tester.getSize(find.byType(Scaffold).last);
    expect(surface.width, greaterThan(680));
    expect(surface.width, frame.width);
    expect(find.textContaining('hello from pdf'), findsOneWidget);
    expect(find.text('设计中的设计'), findsNothing);
  });

  testWidgets('library search field filters imported books by title', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('alpha.txt', utf8.encode('first body'));
    await repository.importBytes('beta.txt', utf8.encode('second body'));
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
    expect(find.text('alpha'), findsWidgets);
    expect(find.text('beta'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('library-search-field')),
      'beta',
    );
    await tester.pumpAndSettle();

    // Search field still shows "beta" so we expect 'alpha' to vanish from
    // the shelf (only the field itself remains with the query string).
    expect(find.text('alpha'), findsNothing);
    expect(find.text('beta'), findsWidgets);
  });

  testWidgets('library search field is case-insensitive', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('alpha.txt', utf8.encode('any body'));
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

    // The file_name is also the metadata.id and surfaces in the search text.
    await tester.enterText(
      find.byKey(const Key('library-search-field')),
      'ALPHA',
    );
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsAtLeastNWidgets(1));
  });

  testWidgets('clearing the library search field restores every book', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('alpha.txt', utf8.encode('first body'));
    await repository.importBytes('beta.txt', utf8.encode('second body'));
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

    await tester.enterText(
      find.byKey(const Key('library-search-field')),
      'beta',
    );
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsNothing);

    await tester.enterText(find.byKey(const Key('library-search-field')), '');
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsWidgets);
    expect(find.text('beta'), findsWidgets);
  });

  testWidgets('library search field hides books that match nothing', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('alpha.txt', utf8.encode('first body'));
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

    await tester.enterText(
      find.byKey(const Key('library-search-field')),
      'zzz-no-such-book',
    );
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsNothing);
  });

  testWidgets('pdf reading settings zoom the current page', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'scan.pdf',
      minimalPdfBytes(pages: ['hello from pdf']),
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
    await tester.tap(find.text('scan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('阅读设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('150%'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('页面缩放'))).pop();
    await tester.pumpAndSettle();
    final zoom = tester.widget<Transform>(find.byKey(const Key('pdf-zoom')));
    expect(zoom.transform.getMaxScaleOnAxis(), 1.5);
    expect(find.textContaining('hello from pdf'), findsOneWidget);
  });

  testWidgets('comic double page shows a pair then the leftover last page', (
    tester,
  ) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'pages.cbz',
      zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'page-02.png': tinyPngBytes(),
        'page-03.png': tinyPngBytes(),
      }),
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
    await tester.tap(find.byTooltip('阅读设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('双页'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('漫画阅读'))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comic-page-left')), findsOneWidget);
    expect(find.byKey(const Key('comic-page-right')), findsOneWidget);
    final surface = tester.getRect(find.byKey(const Key('comic-surface')));
    await tester.tapAt(Offset(surface.right - 8, surface.center.dy));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comic-page-left')), findsOneWidget);
    expect(find.byKey(const Key('comic-page-right')), findsNothing);
    expect(find.text('设计中的设计'), findsNothing);
  });

  testWidgets('comic vertical layout stacks this book only', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'pages.cbz',
      zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'page-02.png': tinyPngBytes(),
      }),
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
    await tester.tap(find.byTooltip('阅读设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('竖滑'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('漫画阅读'))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comic-vertical')), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('设计中的设计'), findsNothing);
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

  testWidgets('epub note jumps to the quote in that chapter', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes(
      'story.epub',
      minimalEpubBytes(secondBody: 'unique-needle-in-chapter-two'),
    );
    final notes = InMemoryAnnotationRepository();
    await notes.save('story.epub', [
      ReaderAnnotation(
        id: 'n1',
        note: 'keep',
        quote: 'unique-needle-in-chapter-two',
        locatorLabel: encodeLocator(const EpubLocator(href: 'OEBPS/ch2.xhtml')),
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
    await tester.tap(find.text('Fixture Book').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('hello from epub'), findsOneWidget);
    expect(find.textContaining('unique-needle-in-chapter-two'), findsNothing);
    await tester.tap(find.byTooltip('笔记'));
    await tester.pump();
    expect(find.byKey(notesPanelKey), findsOneWidget);
    await tester.tap(find.text('unique-needle-in-chapter-two').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('unique-needle-in-chapter-two'), findsWidgets);
    expect(
      tester
          .widget<IsolatedFoliateView>(find.byType(IsolatedFoliateView))
          .scrollQuote,
      'unique-needle-in-chapter-two',
    );
    expect(find.text('设计中的设计'), findsNothing);
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

  testWidgets('editing a book title updates the shelf card', (tester) async {
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
    await tester.tap(find.text('编辑书名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-book-title')), '设计笔记');
    await tester.enterText(find.byKey(const Key('edit-book-author')), '某作者');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('设计笔记'), findsWidgets);
    expect(find.text('某作者'), findsWidgets);
    expect(find.text('notes'), findsNothing);
    expect(find.text('other'), findsWidgets);
    expect(find.text('设计中的设计'), findsNothing);
    final renamed = (await repository.load()).singleWhere(
      (item) => item.metadata.id == 'notes.txt',
    );
    expect(renamed.metadata.title, '设计笔记');
    expect(renamed.metadata.author, '某作者');
  });

  testWidgets('epub bookmark with CFI locator jumps to the right page', (tester) async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('story.epub', minimalEpubBytes());
    // Open the document to discover chapter 2's normalized href.
    final doc = EpubReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'story.epub',
        title: 'Fixture Book',
        author: '',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
      bytes: minimalEpubBytes(),
    );
    await doc.goTo(EpubLocator(href: doc.parsed.chapters[1].href));
    final ch2Href = doc.currentChapterHref;
    // A bookmark in chapter 2 whose locator encodes a CFI pointer; opening it
    // should exercise _goTo's `EpubLocator.cfi != null` branch.
    final bookmarkLocator = EpubLocator(
      href: ch2Href,
      cfi: 'epubcfi($ch2Href:0)',
    );
    final notes = InMemoryAnnotationRepository();
    await notes.save(
      'story.epub',
      [
        ReaderAnnotation(
          id: 'bm-1',
          note: '',
          quote: 'second chapter text',
          locatorLabel: encodeLocator(bookmarkLocator),
          source: bookmarkSource,
          createdAt: DateTime(2026, 9, 8),
        ),
      ],
    );
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
    await tester.tap(find.text('Fixture Book').first);
    await tester.pumpAndSettle();
    // Tap the bookmarks icon in the app bar to open the bookmarks panel.
    // The panel is fed from annotations loaded at open time, so the
    // pre-saved bookmark is the only one shown.
    await tester.tap(find.byTooltip('书签'));
    await tester.pumpAndSettle();
    expect(find.byKey(bookmarksPanelKey), findsOneWidget);
    final encodedLabel = encodeLocator(bookmarkLocator);
    expect(find.text(encodedLabel), findsOneWidget);
    await tester.tap(find.text(encodedLabel));
    await tester.pumpAndSettle();
    // Chapter 2's content should now be on screen (not chapter 1).
    expect(find.textContaining('second chapter text'), findsOneWidget);
    expect(find.textContaining('hello from epub'), findsNothing);
  });
}

class _ThrowingAnnotationRepository implements AnnotationRepository {
  @override
  Future<List<ReaderAnnotation>> load(String documentId) async {
    throw StateError('annotation store unreadable');
  }

  @override
  Future<void> save(String documentId, List<ReaderAnnotation> notes) async {
    throw StateError('annotation store unwritable');
  }
}

class _MissingFileRepository extends InMemoryLibraryRepository {
  @override
  Future<List<int>?> readFile(String id) async {
    throw StateError('file read failed');
  }
}
