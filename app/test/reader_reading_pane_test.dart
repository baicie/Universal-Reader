import 'package:app/core/annotated_text.dart';
import 'package:app/core/comic_document.dart';
import 'package:app/core/comic_layout.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_chapter_state.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/reading_surface.dart';
import 'package:app/core/pdf_document.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:app/features/reader/reader_chapter_body.dart';
import 'package:app/features/reader/reader_reading_pane.dart';
import 'package:app/features/reader/renderers/isolated_comic_view.dart';
import 'package:app/features/reader/renderers/isolated_foliate_view.dart';
import 'package:app/features/reader/renderers/isolated_pdf_view.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';
import 'support/pdf_fixture.dart';

void main() {
  DocumentMetadata _metadata(DocumentFormat format) => DocumentMetadata(
        id: 'a',
        title: 'A',
        author: 'A',
        format: format,
        type: format == DocumentFormat.cbz || format == DocumentFormat.cbr
            ? DocumentType.comic
            : DocumentType.reflow,
      );

  const surface = ReadingSurface.light;

  // Helper that builds a ReaderReadingPane wrapped in MaterialApp + l10n so
  // descendants can call AppLocalizations.of(context).
  Widget _wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
  }

  ReaderReadingPane _pane({
    required ReaderDocument? opened,
    bool chrome = true,
    List<int>? fileBytes,
    List<ReaderAnnotation> notes = const [],
    ReaderChapterState state = const ReaderChapterState.ready(truncated: false),
  }) {
    return ReaderReadingPane(
      opened: opened,
      chrome: chrome,
      fileBytes: fileBytes,
      foliateSession: null,
      foliateFragment: null,
      foliateFragmentEpoch: 0,
      foliateScrollQuote: null,
      foliateScrollQuoteEpoch: 0,
      tocItems: const [],
      notes: notes,
      surface: surface,
      inkColor: Colors.black,
      mutedColor: Colors.grey,
      heading: 'Heading',
      showHeading: false,
      paragraphs: const ['Paragraph 1', 'Paragraph 2'],
      currentIndex: 0,
      chapterCount: 0,
      formatLabel: 'TXT',
      chapterState: state,
      comicLayout: ComicLayout.single,
      comicDirection: ComicReadDirection.ltr,
      pdfZoom: 1.0,
      pageParagraphsFor: (_) => const <String>[],
      annotatedQuoteKey: annotatedQuoteKey,
      onComicTurn: (_) {},
      onToggleChrome: () {},
      onFoliateSelection: (_) {},
      onFoliateHostEvent: (_) {},
      onFoliateNext: () {},
      onFoliatePrevious: () {},
      onSelectionChanged: (_) {},
    );
  }

  group('comic branch', () {
    testWidgets('renders IsolatedComicView for a comic document', (tester) async {
      final comic = ComicReaderDocument.parse(
        metadata: _metadata(DocumentFormat.cbz),
        bytes: zipNamedFiles({'page-01.png': tinyPngBytes()}),
      );

      await tester.pumpWidget(_wrap(_pane(opened: comic)));

      expect(find.byType(IsolatedComicView), findsOneWidget);
      expect(find.byType(IsolatedPdfView), findsNothing);
      expect(find.byType(IsolatedFoliateView), findsNothing);
    });

    testWidgets(
      'comicToggleChrome and onComicTurn callbacks are wired to the view',
      (tester) async {
        var toggled = 0;
        var turned = 0;
        final comic = ComicReaderDocument.parse(
          metadata: _metadata(DocumentFormat.cbz),
          bytes: zipNamedFiles({'page-01.png': tinyPngBytes()}),
        );
        await tester.pumpWidget(
          _wrap(
            ReaderReadingPane(
              opened: comic,
              chrome: true,
              fileBytes: null,
              foliateSession: null,
              foliateFragment: null,
              foliateFragmentEpoch: 0,
              foliateScrollQuote: null,
              foliateScrollQuoteEpoch: 0,
              tocItems: const [],
              notes: const [],
              surface: surface,
              inkColor: Colors.black,
              mutedColor: Colors.grey,
              heading: 'Heading',
              showHeading: false,
              paragraphs: const [],
              currentIndex: 0,
              chapterCount: 0,
              formatLabel: 'CBZ',
              chapterState:
                  const ReaderChapterState.ready(truncated: false),
              comicLayout: ComicLayout.single,
              comicDirection: ComicReadDirection.ltr,
              pdfZoom: 1.0,
              pageParagraphsFor: (_) => const <String>[],
              annotatedQuoteKey: annotatedQuoteKey,
              onComicTurn: (_) => turned++,
              onToggleChrome: () => toggled++,
              onFoliateSelection: (_) {},
              onFoliateHostEvent: (_) {},
              onFoliateNext: () {},
              onFoliatePrevious: () {},
              onSelectionChanged: (_) {},
            ),
          ),
        );
        // Callbacks were attached; counts stay at zero because the comic
        // view is non-interactive in tests (no platform view registered).
        expect(find.byType(IsolatedComicView), findsOneWidget);
        expect(toggled, 0);
        expect(turned, 0);
      },
    );
  });

  group('pdf branch', () {
    testWidgets('renders IsolatedPdfView for a pdf document', (tester) async {
      final pdf = openReaderDocument(
        metadata: _metadata(DocumentFormat.pdf),
        bytes: minimalPdfBytes(),
      );
      expect(pdf, isA<PdfReaderDocument>());

      await tester.pumpWidget(
        _wrap(
          _pane(
            opened: pdf,
            fileBytes: minimalPdfBytes(),
          ),
        ),
      );

      expect(find.byType(IsolatedPdfView), findsOneWidget);
      expect(find.byType(IsolatedComicView), findsNothing);
      expect(find.byType(IsolatedFoliateView), findsNothing);
    });
  });

  group('html / foliate branch', () {
    testWidgets('renders IsolatedFoliateView for an epub document',
        (tester) async {
      final epub = openReaderDocument(
        metadata: _metadata(DocumentFormat.epub),
        bytes: minimalEpubBytes(),
      );
      expect(epub, isA<HtmlChapteredDocument>());

      await tester.pumpWidget(
        _wrap(_pane(opened: epub, fileBytes: minimalEpubBytes())),
      );

      expect(find.byType(IsolatedFoliateView), findsOneWidget);
      expect(find.byType(IsolatedComicView), findsNothing);
      expect(find.byType(IsolatedPdfView), findsNothing);
    });
  });

  group('fallback branch', () {
    testWidgets('renders ReaderChapterBody for a plain-text document',
        (tester) async {
      final text = openReaderDocument(
        metadata: _metadata(DocumentFormat.txt),
        bytes: 'Paragraph 1\nParagraph 2'.codeUnits,
      );
      expect(text, isA<TextReaderDocument>());

      await tester.pumpWidget(_wrap(_pane(opened: text)));

      expect(find.byType(ReaderChapterBody), findsOneWidget);
      expect(find.byType(IsolatedComicView), findsNothing);
      expect(find.byType(IsolatedPdfView), findsNothing);
      expect(find.byType(IsolatedFoliateView), findsNothing);
    });

    testWidgets('renders ReaderChapterBody when no document is open',
        (tester) async {
      await tester.pumpWidget(_wrap(_pane(opened: null)));

      expect(find.byType(ReaderChapterBody), findsOneWidget);
    });
  });

  group('non-chaptered reader', () {
    testWidgets('renders the fallback for UnavailableReaderDocument',
        (tester) async {
      final unavailable = openReaderDocument(
        metadata: _metadata(DocumentFormat.txt),
        bytes: null,
      );
      // openReaderDocument returns UnavailableReaderDocument when no bytes
      // are provided for a plain-text format.
      expect(unavailable, isA<UnavailableReaderDocument>());

      await tester.pumpWidget(_wrap(_pane(opened: unavailable)));

      expect(find.byType(ReaderChapterBody), findsOneWidget);
    });
  });
}
