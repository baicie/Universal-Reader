import 'package:flutter/material.dart';

import '../../core/annotated_text.dart';
import '../../core/comic_document.dart';
import '../../core/comic_layout.dart';
import '../../core/foliate_session.dart';
import '../../core/pdf_document.dart';
import '../../core/reader_runtime.dart';
import '../../core/reading_surface.dart';
import 'reader_annotated_body.dart';
import 'reader_bookmarks.dart';
import 'reader_chapter_body.dart';
import '../library/annotation_store.dart';
import 'renderers/isolated_comic_view.dart';
import 'renderers/isolated_foliate_view.dart';
import 'renderers/isolated_pdf_view.dart';

/// Reading-area pane for [ReaderPage]. Dispatches to the correct
/// renderer based on the document's runtime type and owns the
/// chrome-aware bottom padding shared by the three isolated views.
///
/// All state and IO callbacks are passed in by the parent so this widget
/// stays a pure view over the data it receives.
class ReaderReadingPane extends StatelessWidget {
  const ReaderReadingPane({
    super.key,
    required this.opened,
    required this.chrome,
    required this.fileBytes,
    required this.foliateSession,
    required this.foliateFragment,
    required this.foliateFragmentEpoch,
    required this.foliateScrollQuote,
    required this.foliateScrollQuoteEpoch,
    required this.tocItems,
    required this.notes,
    required this.surface,
    required this.inkColor,
    required this.mutedColor,
    required this.heading,
    required this.showHeading,
    required this.paragraphs,
    required this.currentIndex,
    required this.chapterCount,
    required this.formatLabel,
    required this.chapterState,
    required this.comicLayout,
    required this.comicDirection,
    required this.pdfZoom,
    required this.pageParagraphsFor,
    required this.annotatedQuoteKey,
    required this.onComicTurn,
    required this.onToggleChrome,
    required this.onFoliateSelection,
    required this.onFoliateHostEvent,
    required this.onFoliateNext,
    required this.onFoliatePrevious,
    required this.onSelectionChanged,
  });

  /// The currently opened reader document (may be null while loading).
  final ReaderDocument? opened;
  final bool chrome;

  // Foliate / HTML-chaptered state, forwarded to IsolatedFoliateView.
  final List<int>? fileBytes;
  final FoliateSession? foliateSession;
  final String? foliateFragment;
  final int foliateFragmentEpoch;
  final String? foliateScrollQuote;
  final int foliateScrollQuoteEpoch;
  final List<TocItem> tocItems;
  final List<ReaderAnnotation> notes;

  // Visual + content inputs for the fallback (plain-text) path.
  final ReadingSurface surface;
  final Color inkColor;
  final Color mutedColor;
  final String heading;
  final bool showHeading;
  final List<String> paragraphs;
  final int currentIndex;
  final int chapterCount;
  final String formatLabel;
  final ReaderChapterState chapterState;

  // Renderer preferences (already resolved in the parent via Riverpod).
  final ComicLayout comicLayout;
  final ComicReadDirection comicDirection;
  final double pdfZoom;

  /// Builds the paragraph list for the HTML-chaptered fallback. Kept as a
  /// callback because the per-page slice depends on the live foliate
  /// session, which lives in the parent state.
  final List<String> Function(HtmlChapteredDocument reader) pageParagraphsFor;

  /// Highlight key for the annotation overlay.
  final ValueKey<String> annotatedQuoteKey;

  // Callbacks.
  final void Function(int pageIndex) onComicTurn;
  final VoidCallback onToggleChrome;
  final ValueChanged<FoliateSelection> onFoliateSelection;
  final ValueChanged<Map<String, Object?>> onFoliateHostEvent;
  final VoidCallback onFoliateNext;
  final VoidCallback onFoliatePrevious;
  final ValueChanged<String?> onSelectionChanged;

  Widget _annotatedBody({required List<String> ps}) {
    final style = TextStyle(
      color: surface.color,
      fontSize: surface.fontSize,
      height: surface.lineHeight,
      fontFamily: surface.flutterFontFamily,
    );
    return ReaderAnnotatedBody(
      paragraphs: ps,
      style: style,
      notes: notesOf(notes),
      highlightKey: annotatedQuoteKey,
      onSelectionChanged: onSelectionChanged,
    );
  }

  EdgeInsets _chromeBottomPadding() =>
      EdgeInsets.only(bottom: chrome ? 72 : 0);

  @override
  Widget build(BuildContext context) {
    final reader = opened;
    if (reader is ComicReaderDocument) {
      return Padding(
        padding: _chromeBottomPadding(),
        child: IsolatedComicView(
          document: reader,
          layout: comicLayout,
          direction: comicDirection,
          onTurn: onComicTurn,
          onToggleChrome: onToggleChrome,
        ),
      );
    }
    if (reader is PdfReaderDocument) {
      return Padding(
        padding: _chromeBottomPadding(),
        child: IsolatedPdfView(
          document: reader,
          bytes: fileBytes,
          zoom: pdfZoom,
          fallback: _annotatedBody(ps: paragraphs),
        ),
      );
    }
    if (reader is HtmlChapteredDocument) {
      return Padding(
        padding: _chromeBottomPadding(),
        child: IsolatedFoliateView(
          document: reader,
          session: foliateSession,
          surface: surface,
          fallback: _annotatedBody(ps: pageParagraphsFor(reader)),
          quotes: quoteHighlights(notes),
          fragment: foliateFragment,
          fragmentEpoch: foliateFragmentEpoch,
          scrollQuote: foliateScrollQuote,
          scrollQuoteEpoch: foliateScrollQuoteEpoch,
          pageIndex: foliateSession?.pageIndex ?? 0,
          onSelection: onFoliateSelection,
          onHostEvent: onFoliateHostEvent,
          onNext: onFoliateNext,
          onPrevious: onFoliatePrevious,
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            28,
            chrome ? 32 : 48,
            28,
            chrome ? 112 : 48,
          ),
          child: ReaderChapterBody(
            state: chapterState,
            surface: surface,
            surfaceColor: inkColor,
            mutedColor: mutedColor,
            heading: heading,
            showHeading: showHeading,
            hasToc: tocItems.isNotEmpty,
            currentIndex: currentIndex,
            chapterCount: chapterCount,
            formatLabel: formatLabel,
            child: _annotatedBody(ps: paragraphs),
          ),
        ),
      ),
    );
  }
}
