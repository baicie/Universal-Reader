import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/annotated_text.dart';
import '../../core/comic_document.dart';
import '../../core/foliate_session.dart';
import '../../core/locator_codec.dart';
import '../../core/models.dart';
import '../../core/pdf_document.dart';
import '../../core/providers.dart';
import '../../core/reader_runtime.dart';
import '../../core/reading_surface.dart';
import '../../core/text_document.dart';
import '../../l10n/l10n.dart';
import '../../widgets/eyebrow.dart';
import '../library/annotation_store.dart';
import '../tools/reader_ai_panel.dart';
import 'open_reader.dart';
import 'reader_bookmarks.dart';
import 'reader_bookmarks_pane.dart';
import 'reader_notes_pane.dart';
import 'reader_search.dart';
import 'reader_search_pane.dart';
import 'reader_selection.dart';
import 'reading_settings_sheet.dart';
import 'renderers/isolated_comic_view.dart';
import 'renderers/isolated_foliate_view.dart';
import 'renderers/isolated_pdf_view.dart';
import 'selection_confirm_bar.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  bool chrome = true;
  bool toc = false;
  bool bookmarks = false;
  bool showNotes = false;
  bool showSearch = false;
  bool ask = false;
  late double progress;
  bool loading = true;
  ReaderDocument? opened;
  List<TocItem> tocItems = const [];
  String body = '';
  List<int>? fileBytes;
  List<ReaderAnnotation> notes = const [];
  String? pendingQuote;
  FoliateSession? foliateSession;
  String searchQuery = '';
  List<SearchResult> searchHits = const [];

  @override
  void initState() {
    super.initState();
    progress =
        ref
            .read(libraryProvider)
            .documentById(widget.id)
            ?.readingState
            .progress ??
        0;
    Future.microtask(_open);
  }

  Future<void> _open() async {
    final library = ref.read(libraryProvider);
    await library.waitUntilReady();
    if (!mounted) return;
    final document = library.documentById(widget.id);
    if (document == null) {
      setState(() {
        opened = UnavailableReaderDocument(
          metadata: DocumentMetadata(
            id: widget.id,
            title: widget.id,
            author: '',
            format: DocumentFormat.unknown,
            type: DocumentType.reflow,
          ),
        );
        loading = false;
      });
      return;
    }
    final bytes = await library.readFile(widget.id);
    final loadedNotes = await ref
        .read(aiRuntimeProvider)
        .annotations
        .load(widget.id);
    if (!mounted) return;
    final reader = openReaderDocument(
      metadata: document.metadata,
      bytes: bytes,
    );
    if (reader is ChapteredDocument && progress > 0) {
      await reader.goTo(reader.locatorForProgress(progress));
    }
    final items = await reader.getToc();
    if (!mounted) return;
    setState(() {
      opened = reader;
      tocItems = items;
      body = _bodyFor(reader);
      fileBytes = bytes;
      notes = loadedNotes;
      foliateSession = reader is HtmlChapteredDocument
          ? FoliateSession.open(reader)
          : null;
      loading = false;
    });
  }

  String _bodyFor(ReaderDocument reader) {
    if (reader is ChapteredDocument) return reader.currentChapterText;
    return '';
  }

  Future<void> _goTo(Locator locator) async {
    final reader = opened;
    if (reader == null) return;
    await reader.goTo(locator);
    FoliateSession? session;
    if (reader is HtmlChapteredDocument) {
      session = FoliateSession.open(reader);
      if (locator is EpubLocator && locator.cfi != null) {
        session.goToCfi(locator.cfi!);
      }
    }
    if (!mounted) return;
    setState(() {
      body = _bodyFor(reader);
      foliateSession = session;
      if (reader is ChapteredDocument && reader.chapterCount > 0) {
        progress = reader.chapterIndex / reader.chapterCount;
        ref.read(libraryProvider).updateProgress(widget.id, progress);
      }
    });
  }

  Future<void> _goToToc(TocItem item) => _goTo(item.locator);

  Future<Locator> _bookmarkLocator() async {
    final reader = opened;
    if (reader == null) return const TextLocator(offset: 0);
    final current = await reader.currentLocator();
    final session = foliateSession;
    if (current is EpubLocator && session != null) {
      return EpubLocator(
        href: current.href,
        cfi: session.currentCfi,
        progression: session.progression,
      );
    }
    return current;
  }

  Future<void> _addBookmark() async {
    if (opened == null || loading) return;
    final mark = bookmarkAt(locator: await _bookmarkLocator());
    await ref.read(aiRuntimeProvider).annotations.append(widget.id, mark);
    if (!mounted) return;
    setState(() {
      notes = [...notes, mark];
      bookmarks = true;
      chrome = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).bookmarkAdded)),
    );
  }

  Future<void> _removeMark(String noteId) async {
    final next = await ref
        .read(aiRuntimeProvider)
        .annotations
        .remove(widget.id, noteId);
    if (!mounted) return;
    setState(() => notes = next);
  }

  Future<void> _searchBook(String query) async {
    final reader = opened;
    setState(() => searchQuery = query);
    if (reader == null) {
      setState(() => searchHits = const []);
      return;
    }
    final hits = await hitsForQuery(reader, query);
    if (!mounted) return;
    setState(() => searchHits = hits);
  }

  Future<void> _saveSelection() async {
    final quote = pendingQuote;
    if (quote == null) return;
    final note = noteFromSelection(
      quote,
      locatorLabel: encodeLocator(await _bookmarkLocator()),
    );
    if (note == null) {
      setState(() => pendingQuote = null);
      return;
    }
    await ref.read(aiRuntimeProvider).annotations.append(widget.id, note);
    if (!mounted) return;
    setState(() {
      notes = [...notes, note];
      pendingQuote = null;
    });
  }

  void _onFoliateSelection(FoliateSelection selection) {
    setState(() => pendingQuote = selection.quote);
  }

  void _onFoliateHostEvent(Map<String, Object?> event) {
    final type = event['type'];
    final session = foliateSession;
    if (session == null) return;
    if (type == 'next' && session.next()) {
      setState(() {});
    } else if ((type == 'prev' || type == 'previous') && session.previous()) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final prefs = ref.watch(readerPrefsProvider);
    final surface = ReadingSurface.resolve(
      fontSize: prefs.fontSize,
      lineHeight: prefs.lineHeight,
      fontFamily: prefs.fontFamily,
      paper: prefs.paper,
      brightness: theme.brightness,
    );
    final document = ref.watch(libraryProvider).documentById(widget.id);
    final dark = surface.isDark;
    final paper = surface.background;
    final ink = surface.color;
    final muted = surface.muted;
    final tocBg = dark ? const Color(0xFF24231F) : const Color(0xFFF0EADF);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final sideOpen = toc || bookmarks || showNotes || showSearch;
    final currentIndex = opened is ChapteredDocument
        ? (opened as ChapteredDocument).chapterIndex
        : 0;
    final currentTitle = tocItems.isEmpty
        ? ''
        : tocItems[currentIndex.clamp(0, tocItems.length - 1)].title;
    final heading = currentTitle.trim().isEmpty
        ? l10n.untitledSection
        : currentTitle;
    final paragraphs = body
        .split(RegExp(r'\n+'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
    final title = document?.metadata.title ?? widget.id;
    final formatLabel = document?.metadata.format.label ?? '';

    return Scaffold(
      backgroundColor: paper,
      appBar: chrome
          ? AppBar(
              backgroundColor: paper,
              foregroundColor: ink,
              leading: IconButton(
                tooltip: l10n.backToLibrary,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: l10n.askThisPage,
                  icon: Icon(
                    ask ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    color: ask ? accent : ink,
                  ),
                  onPressed: () => setState(() {
                    ask = !ask;
                    chrome = true;
                  }),
                ),
                IconButton(
                  tooltip: l10n.searchInBook,
                  icon: Icon(Icons.search, color: showSearch ? accent : ink),
                  onPressed: () => setState(() {
                    showSearch = !showSearch;
                    chrome = true;
                  }),
                ),
                IconButton(
                  tooltip: l10n.notesTitle,
                  icon: Icon(
                    showNotes
                        ? Icons.sticky_note_2
                        : Icons.sticky_note_2_outlined,
                    color: showNotes ? accent : ink,
                  ),
                  onPressed: () => setState(() => showNotes = !showNotes),
                ),
                IconButton(
                  key: addBookmarkButtonKey,
                  tooltip: l10n.addBookmark,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  onPressed: _addBookmark,
                ),
                IconButton(
                  tooltip: l10n.bookmarks,
                  icon: Icon(
                    bookmarks ? Icons.bookmarks : Icons.bookmarks_outlined,
                    color: bookmarks ? accent : ink,
                  ),
                  onPressed: () => setState(() => bookmarks = !bookmarks),
                ),
                IconButton(
                  tooltip: l10n.tableOfContents,
                  icon: Icon(
                    toc ? Icons.menu_book : Icons.menu_book_outlined,
                    color: toc ? accent : ink,
                  ),
                  onPressed: () => setState(() => toc = !toc),
                ),
                IconButton(
                  tooltip: l10n.readingSettings,
                  icon: const Icon(Icons.text_fields),
                  onPressed: _openReadingSettings,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () {
          if (pendingQuote != null && pendingQuote!.trim().isNotEmpty) return;
          setState(() => chrome = !chrome);
        },
        child: Stack(
          children: [
            Row(
              children: [
                if (sideOpen)
                  Material(
                    color: tocBg,
                    child: GestureDetector(
                      onTap: () {},
                      child: SizedBox(
                        width: 240,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 16, 24),
                          children: [
                            if (showSearch) ...[
                              ReaderSearchPane(
                                title: l10n.searchInBook,
                                hint: l10n.searchInBookHint,
                                emptyLabel: l10n.noSearchResults,
                                query: searchQuery,
                                hits: searchHits,
                                onQuery: _searchBook,
                                onOpen: (hit) => _goTo(hit.locator),
                              ),
                              if (showNotes || bookmarks || toc)
                                const SizedBox(height: 28),
                            ],
                            if (showNotes) ...[
                              ReaderNotesPane(
                                title: l10n.notesTitle,
                                emptyLabel: l10n.noNotes,
                                deleteLabel: l10n.deleteNote,
                                notes: notesOf(notes),
                                onOpen: (note) {
                                  final locator = decodeLocator(
                                    note.locatorLabel,
                                  );
                                  if (locator != null) _goTo(locator);
                                },
                                onDelete: (note) => _removeMark(note.id),
                              ),
                              if (bookmarks || toc) const SizedBox(height: 28),
                            ],
                            if (bookmarks) ...[
                              ReaderBookmarksPane(
                                title: l10n.bookmarks,
                                emptyLabel: l10n.noBookmarks,
                                deleteLabel: l10n.deleteBookmark,
                                bookmarks: bookmarksOf(notes),
                                onOpen: (mark) {
                                  final locator = decodeLocator(
                                    mark.locatorLabel,
                                  );
                                  if (locator != null) _goTo(locator);
                                },
                                onDelete: (mark) => _removeMark(mark.id),
                              ),
                              if (toc) const SizedBox(height: 28),
                            ],
                            if (toc) ...[
                              Eyebrow(l10n.tableOfContents),
                              const SizedBox(height: 12),
                              if (tocItems.isEmpty)
                                Text(
                                  l10n.untitledSection,
                                  style: TextStyle(color: muted, height: 1.4),
                                ),
                              for (var i = 0; i < tocItems.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: InkWell(
                                    onTap: () => _goToToc(tocItems[i]),
                                    child: Text(
                                      tocItems[i].title.trim().isEmpty
                                          ? l10n.untitledSection
                                          : tocItems[i].title,
                                      style: TextStyle(
                                        fontWeight: i == currentIndex
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: i == currentIndex ? accent : ink,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          chrome ? 32 : 48,
                          28,
                          chrome ? 112 : 48,
                        ),
                        child: _readerBody(
                          l10n: l10n,
                          document: document,
                          muted: muted,
                          heading: heading,
                          showHeading: currentTitle.trim().isNotEmpty,
                          paragraphs: paragraphs,
                          currentIndex: currentIndex,
                          surface: surface,
                          formatLabel: formatLabel,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (ask && opened != null)
              Positioned(
                top: wide ? 0 : null,
                left: wide ? null : 0,
                right: 0,
                bottom: chrome ? 72 : 0,
                width: wide ? 320 : null,
                height: wide ? null : MediaQuery.sizeOf(context).height * 0.45,
                child: ReaderAiPanel(
                  document: opened!,
                  settings: ref.watch(aiSettingsProvider).settings,
                  onJump: (locator) => _goTo(locator),
                ),
              ),
            if (pendingQuote != null && pendingQuote!.trim().isNotEmpty)
              Positioned(
                left: sideOpen ? 240 : 0,
                right: ask && wide ? 320 : 0,
                bottom: chrome ? 72 : 0,
                child: GestureDetector(
                  onTap: () {},
                  child: SelectionConfirmBar(
                    quote: pendingQuote!,
                    saveLabel: l10n.saveSelection,
                    onSave: _saveSelection,
                    onDismiss: () => setState(() => pendingQuote = null),
                  ),
                ),
              ),
            if (chrome)
              Positioned(
                left: sideOpen ? 240 : 0,
                right: ask && wide ? 320 : 0,
                bottom: 0,
                child: Material(
                  color: paper,
                  child: SafeArea(
                    top: false,
                    child: GestureDetector(
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: progress.clamp(0, 1),
                              onChanged: (value) {
                                setState(() => progress = value);
                                ref
                                    .read(libraryProvider)
                                    .updateProgress(widget.id, value);
                                final reader = opened;
                                if (reader is ChapteredDocument) {
                                  reader.goTo(reader.locatorForProgress(value));
                                  body = _bodyFor(reader);
                                  if (reader is HtmlChapteredDocument) {
                                    foliateSession = FoliateSession.open(
                                      reader,
                                    );
                                  }
                                }
                              },
                            ),
                            Row(
                              children: [
                                Text(
                                  tocItems.isEmpty
                                      ? formatLabel
                                      : l10n.readerSection(
                                          currentIndex + 1,
                                          tocItems.length,
                                        ),
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReadingSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const ReadingSettingsSheet(),
    );
  }

  Widget _readerBody({
    required AppLocalizations l10n,
    required LibraryDocument? document,
    required Color muted,
    required String heading,
    required bool showHeading,
    required List<String> paragraphs,
    required int currentIndex,
    required ReadingSurface surface,
    required String formatLabel,
  }) {
    final fontSize = surface.fontSize;
    final ink = surface.color;
    final bodyStyle = TextStyle(
      color: ink,
      fontSize: fontSize,
      height: surface.lineHeight,
      fontFamily: surface.flutterFontFamily,
    );
    if (loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.readerLoading, style: TextStyle(color: muted)),
          ],
        ),
      );
    }
    if (opened is CorruptReaderDocument) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Text(l10n.readerCorruptFile, style: bodyStyle),
      );
    }
    if (opened is UnavailableReaderDocument) {
      final format = document?.metadata.format;
      final missingFile =
          document == null || (format?.isReaderEngineFormat ?? false);
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Text(
          missingFile
              ? l10n.readerMissingFile
              : l10n.readerUnavailable(document.metadata.format.label),
          style: bodyStyle,
        ),
      );
    }
    final truncated =
        opened is ChapteredDocument && (opened as ChapteredDocument).truncated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tocItems.isEmpty
              ? formatLabel
              : l10n.readerSection(currentIndex + 1, tocItems.length),
          style: TextStyle(
            color: muted,
            letterSpacing: 2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (showHeading) ...[
          Text(
            heading,
            style: TextStyle(
              color: ink,
              fontSize: fontSize * 2,
              fontWeight: FontWeight.w600,
              height: 1.15,
              fontFamily: surface.flutterFontFamily,
            ),
          ),
          const SizedBox(height: 28),
        ],
        if (truncated) ...[
          Text(
            l10n.readerTruncated,
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 22),
        ],
        _visualSurface(surface: surface, paragraphs: paragraphs),
      ],
    );
  }

  Widget _visualSurface({
    required ReadingSurface surface,
    required List<String> paragraphs,
  }) {
    final fallback = _annotatedBody(surface: surface, paragraphs: paragraphs);
    final reader = opened;
    if (reader is ComicReaderDocument) {
      return IsolatedComicView(document: reader);
    }
    if (reader is PdfReaderDocument) {
      return IsolatedPdfView(
        document: reader,
        bytes: fileBytes,
        fallback: fallback,
      );
    }
    if (reader is HtmlChapteredDocument) {
      return IsolatedFoliateView(
        document: reader,
        session: foliateSession,
        surface: surface,
        fallback: fallback,
        onSelection: _onFoliateSelection,
        onHostEvent: _onFoliateHostEvent,
      );
    }
    return fallback;
  }

  Widget _annotatedBody({
    required ReadingSurface surface,
    required List<String> paragraphs,
  }) {
    final style = TextStyle(
      color: surface.color,
      fontSize: surface.fontSize,
      height: surface.lineHeight,
      fontFamily: surface.flutterFontFamily,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 22),
          _annotatedParagraph(paragraphs[i], style),
        ],
      ],
    );
  }

  Widget _annotatedParagraph(String text, TextStyle style) {
    final spans = annotatePlainText(text, notesOf(notes), style: style);
    final highlighted = spans.any(
      (span) => span is TextSpan && span.style?.backgroundColor != null,
    );
    return SelectableText.rich(
      TextSpan(children: spans, style: style),
      key: highlighted ? annotatedQuoteKey : null,
      onSelectionChanged: (selection, _) {
        if (!selection.isValid || selection.isCollapsed) return;
        final start = selection.start;
        final end = selection.end;
        if (start < 0 || end > text.length || start >= end) return;
        final quote = text.substring(start, end);
        if (quote.trim().isEmpty) return;
        setState(() => pendingQuote = quote);
      },
    );
  }
}
