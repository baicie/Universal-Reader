import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/annotated_text.dart';
import '../../core/comic_document.dart';
import '../../core/foliate_session.dart';
import '../../core/locator_codec.dart';
import '../../core/models.dart';
import '../../core/pdf_document.dart';
import '../../core/providers.dart';
import '../../core/reader_chapter_state.dart';
import '../../core/reader_chrome_panels.dart';
import '../../core/reader_derived.dart';
import '../../core/reader_runtime.dart';
import '../../core/reader_text.dart';
import '../../core/reading_surface.dart';
import '../../core/reflow_nav.dart';
import '../../core/text_document.dart';
import '../../l10n/l10n.dart';
import '../library/annotation_store.dart';
import '../tools/reader_ai_panel.dart';
import 'open_reader.dart';
import 'reader_app_bar.dart';
import 'reader_bookmarks.dart';
import 'reader_bottom_overlay.dart';
import 'reader_notes.dart';
import 'reader_reading_pane.dart';
import 'reader_search.dart';
import 'reader_selection.dart';
import 'reader_side_panel.dart';
import 'reading_settings_sheet.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  bool chrome = true;
  bool ask = false;
  ReaderChromePanels panels = const ReaderChromePanels();
  late double progress;
  bool loading = true;
  ReaderDocument? opened;
  List<TocItem> tocItems = const [];
  String body = '';
  List<int>? fileBytes;
  List<ReaderAnnotation> notes = const [];
  String? pendingQuote;
  FoliateSession? foliateSession;
  String? foliateFragment;
  int foliateFragmentEpoch = 0;
  String? foliateScrollQuote;
  int foliateScrollQuoteEpoch = 0;
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
      body = readerCurrentBody(reader);
      fileBytes = bytes;
      notes = loadedNotes;
      foliateSession = reader is HtmlChapteredDocument
          ? FoliateSession.open(reader)
          : null;
      if (foliateSession != null && reader is HtmlChapteredDocument) {
        foliateSession!.goToPage(
          reflowPageIndexForProgress(
            progress: progress,
            chapterCount: reader.chapterCount,
            chapterIndex: reader.chapterIndex,
            pageCount: foliateSession!.pageCount,
          ),
        );
      }
      loading = false;
    });
  }

  Future<void> _goTo(
    Locator locator, {
    bool syncProgress = true,
    String? fragment,
    String? scrollQuote,
  }) async {
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
    final resolvedFragment =
        fragment ?? (locator is EpubLocator ? locator.fragment : null);
    if (!mounted) return;
    setState(() {
      body = readerCurrentBody(reader);
      foliateSession = session;
      foliateFragment = resolvedFragment;
      if (resolvedFragment != null) foliateFragmentEpoch++;
      foliateScrollQuote = scrollQuote;
      if (scrollQuote != null) foliateScrollQuoteEpoch++;
      if (syncProgress &&
          reader is ChapteredDocument &&
          reader.chapterCount > 0) {
        progress = reader.chapterIndex / reader.chapterCount;
        ref.read(libraryProvider).updateProgress(widget.id, progress);
      }
    });
  }

  Future<void> _goToToc(TocItem item) async {
    final locator = item.locator;
    if (locator is EpubLocator) {
      final fragment = locator.fragment;
      final session = foliateSession;
      if (session != null &&
          fragment != null &&
          reflowSameHref(session.href, locator.href)) {
        if (!mounted) return;
        setState(() {
          foliateFragment = fragment;
          foliateFragmentEpoch++;
        });
        return;
      }
    }
    await _goTo(locator);
  }

  Future<void> _onSearchHit(SearchResult hit) async {
    final quote = reflowScrollQuote(searchQuery);
    final locator = hit.locator;
    if (locator is EpubLocator &&
        foliateSession != null &&
        reflowSameHref(foliateSession!.href, locator.href)) {
      if (quote == null || !mounted) return;
      setState(() {
        foliateScrollQuote = quote;
        foliateScrollQuoteEpoch++;
      });
      return;
    }
    await _goTo(locator, scrollQuote: quote);
  }

  Future<void> _onNoteOpen(ReaderAnnotation note) async {
    final jump = noteJump(note);
    final locator = jump.locator;
    if (locator == null) return;
    final quote = jump.scrollQuote;
    if (locator is EpubLocator &&
        foliateSession != null &&
        reflowSameHref(foliateSession!.href, locator.href)) {
      if (quote == null || !mounted) return;
      setState(() {
        foliateScrollQuote = quote;
        foliateScrollQuoteEpoch++;
      });
      return;
    }
    await _goTo(locator, scrollQuote: quote);
  }

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
      panels = panels.toggle(PanelKind.bookmarks);
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
    final session = foliateSession;
    if (session != null && session.applyRelocated(event)) {
      if (!mounted) return;
      setState(() {});
      _syncReflowProgress();
      return;
    }
    final type = event['type'];
    if (type == 'next') {
      _turnReflow(next: true);
    } else if (type == 'prev' || type == 'previous') {
      _turnReflow(next: false);
    } else if (type == 'link') {
      if (session == null) return;
      _onReflowLink(session, event['href'] as String? ?? '');
    }
  }

  Future<void> _onReflowLink(FoliateSession session, String raw) async {
    final target = reflowInternalHref(currentHref: session.href, raw: raw);
    if (target == null) {
      // External link - try to launch it
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        try {
          final uri = Uri.parse(trimmed);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (_) {
          // Invalid URL or launch failed - ignore
        }
      }
      return;
    }
    final fragment = reflowHrefFragment(raw);
    if (reflowSameHref(session.href, target)) {
      if (fragment == null || !mounted) return;
      setState(() {
        foliateFragment = fragment;
        foliateFragmentEpoch++;
      });
      return;
    }
    await _goTo(EpubLocator(href: target), fragment: fragment);
  }

  Future<void> _turnReflow({required bool next}) async {
    final reader = opened;
    final session = foliateSession;
    if (reader is! HtmlChapteredDocument || session == null) return;
    final turn = next
        ? reflowNext(
            pageIndex: session.pageIndex,
            pageCount: session.pageCount,
            chapterIndex: reader.chapterIndex,
            chapterCount: reader.chapterCount,
          )
        : reflowPrevious(
            pageIndex: session.pageIndex,
            pageCount: session.pageCount,
            chapterIndex: reader.chapterIndex,
            chapterCount: reader.chapterCount,
          );
    switch (turn) {
      case ReflowTurnStay():
        return;
      case ReflowTurnPage(:final pageIndex):
        session.goToPage(pageIndex);
        if (!mounted) return;
        setState(() {});
        _syncReflowProgress();
      case ReflowTurnChapter(:final chapterIndex, :final lastPage):
        await _goToChapter(chapterIndex, lastPage: lastPage);
    }
  }

  Future<void> _goToChapter(int index, {bool lastPage = false}) async {
    final reader = opened;
    if (reader is! ChapteredDocument) return;
    if (index < 0 || index >= reader.chapterCount) return;
    final at = reader.chapterCount <= 1 ? 0.0 : index / reader.chapterCount;
    await _goTo(reader.locatorForProgress(at));
    if (lastPage) {
      foliateSession?.goToLastPage();
      if (mounted) setState(() {});
    }
    _syncReflowProgress();
  }

  void _syncReflowProgress() {
    final reader = opened;
    final session = foliateSession;
    if (reader is! ChapteredDocument || reader.chapterCount <= 0) return;
    final pagePart = session == null || session.pageCount <= 1
        ? 0.0
        : session.pageIndex / session.pageCount;
    progress = ((reader.chapterIndex + pagePart) / reader.chapterCount).clamp(
      0,
      1,
    );
    ref.read(libraryProvider).updateProgress(widget.id, progress);
  }

  Future<void> _seekProgress(double value) async {
    setState(() => progress = value);
    ref.read(libraryProvider).updateProgress(widget.id, value);
    final reader = opened;
    if (reader is! ChapteredDocument) return;
    if (reader is HtmlChapteredDocument) {
      await _goTo(reader.locatorForProgress(value), syncProgress: false);
      final session = foliateSession;
      if (session != null) {
        session.goToPage(
          reflowPageIndexForProgress(
            progress: value,
            chapterCount: reader.chapterCount,
            chapterIndex: reader.chapterIndex,
            pageCount: session.pageCount,
          ),
        );
        if (mounted) setState(() {});
      }
      return;
    }
    await reader.goTo(reader.locatorForProgress(value));
    if (!mounted) return;
    setState(() {
      body = readerCurrentBody(reader);
    });
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
    final sideOpen = panels.anyOpen;
    final derived = ReaderDerived.build(
      opened: opened,
      tocItems: tocItems,
      body: body,
      l10n: l10n,
    );
    final currentIndex = derived.currentIndex;
    final chapterCount = derived.chapterCount;
    final currentHref = derived.currentHref;
    final currentTitle = derived.currentTitle;
    final heading = derived.heading;
    final paragraphs = derived.paragraphs;
    final title = document?.metadata.title ?? widget.id;
    final formatLabel = document?.metadata.format.label ?? '';
    final chapterState = resolveReaderChapterState(
      loading: loading,
      opened: opened,
      document: document,
      isTruncated: opened is ChapteredDocument &&
          (opened as ChapteredDocument).truncated,
    );

    return Scaffold(
      backgroundColor: paper,
      appBar: chrome
          ? ReaderAppBar(
              title: title,
              ask: ask,
              showSearch: panels.showSearch,
              showNotes: panels.showNotes,
              bookmarks: panels.bookmarks,
              toc: panels.toc,
              onAskToggle: () => setState(() {
                ask = !ask;
                chrome = true;
              }),
              onSearchToggle: () => setState(() {
                panels = panels.toggle(PanelKind.search);
                chrome = true;
              }),
              onNotesToggle: () => setState(
                  () => panels = panels.toggle(PanelKind.notes)),
              onBookmarksToggle: () => setState(
                  () => panels = panels.toggle(PanelKind.bookmarks)),
              onTocToggle: () =>
                  setState(() => panels = panels.toggle(PanelKind.toc)),
              onAddBookmark: _addBookmark,
              onOpenSettings: _openReadingSettings,
              onBack: () => context.go('/'),
            )
          : null,
      body: CallbackShortcuts(
        bindings: {
          if (opened is HtmlChapteredDocument) ...{
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              _turnReflow(next: true);
            },
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
              _turnReflow(next: false);
            },
            const SingleActivator(LogicalKeyboardKey.pageDown): () {
              _turnReflow(next: true);
            },
            const SingleActivator(LogicalKeyboardKey.pageUp): () {
              _turnReflow(next: false);
            },
          },
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: () {
              if (pendingQuote != null && pendingQuote!.trim().isNotEmpty) {
                return;
              }
              setState(() => chrome = !chrome);
            },
            child: Stack(
              children: [
                Row(
                  children: [
                    if (sideOpen)
                      ReaderSidePanel(
                        background: tocBg,
                        ink: ink,
                        muted: muted,
                        accent: accent,
                        showSearch: panels.showSearch,
                        showNotes: panels.showNotes,
                        showBookmarks: panels.bookmarks,
                        showToc: panels.toc,
                        searchQuery: searchQuery,
                        searchHits: searchHits,
                        notes: notes,
                        tocItems: tocItems,
                        currentHref: currentHref,
                        currentFragment: foliateFragment,
                        currentIndex: currentIndex,
                        foliateSession: foliateSession,
                        onSearchQuery: _searchBook,
                        onSearchOpen: _onSearchHit,
                        onNoteOpen: _onNoteOpen,
                        onNoteDelete: (note) => _removeMark(note.id),
                        onBookmarkOpen: (mark) {
                          final locator = decodeLocator(mark.locatorLabel);
                          if (locator != null) _goTo(locator);
                        },
                        onBookmarkDelete: (mark) => _removeMark(mark.id),
                        onTocOpen: _goToToc,
                      ),
                    Expanded(
                      child: ReaderReadingPane(
                        opened: opened,
                        chrome: chrome,
                        fileBytes: fileBytes,
                        foliateSession: foliateSession,
                        foliateFragment: foliateFragment,
                        foliateFragmentEpoch: foliateFragmentEpoch,
                        foliateScrollQuote: foliateScrollQuote,
                        foliateScrollQuoteEpoch: foliateScrollQuoteEpoch,
                        tocItems: tocItems,
                        notes: notes,
                        surface: surface,
                        inkColor: ink,
                        mutedColor: muted,
                        heading: heading,
                        showHeading: currentTitle.trim().isNotEmpty,
                        paragraphs: paragraphs,
                        currentIndex: currentIndex,
                        chapterCount: chapterCount,
                        formatLabel: formatLabel,
                        chapterState: chapterState,
                        comicLayout: prefs.comicLayout,
                        comicDirection: prefs.comicDirection,
                        pdfZoom: prefs.pdfZoom,
                        pageParagraphsFor: _pageParagraphs,
                        annotatedQuoteKey: annotatedQuoteKey,
                        onComicTurn: (index) => _goTo(ComicLocator(page: index + 1)),
                        onToggleChrome: () => setState(() => chrome = !chrome),
                        onFoliateSelection: _onFoliateSelection,
                        onFoliateHostEvent: _onFoliateHostEvent,
                        onFoliateNext: () => _turnReflow(next: true),
                        onFoliatePrevious: () => _turnReflow(next: false),
                        onSelectionChanged: (quote) =>
                            setState(() => pendingQuote = quote),
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
                    height: wide
                        ? null
                        : MediaQuery.sizeOf(context).height * 0.45,
                    child: ReaderAiPanel(
                      document: opened!,
                      settings: ref.watch(aiSettingsProvider).settings,
                      onJump: (locator) => _goTo(locator),
                    ),
                  ),
                ReaderBottomOverlay(
                  pendingQuote: pendingQuote,
                  saveLabel: l10n.saveSelection,
                  chrome: chrome,
                  sideOpen: sideOpen,
                  askAndWide: ask && wide,
                  paper: paper,
                  muted: muted,
                  ink: ink,
                  progress: progress,
                  progressLabel: _progressLabel(
                    l10n: l10n,
                    formatLabel: formatLabel,
                    currentIndex: currentIndex,
                  ),
                  onSaveSelection: _saveSelection,
                  onDismissSelection: () => setState(() => pendingQuote = null),
                  onSeekProgress: _seekProgress,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _progressLabel({
    required AppLocalizations l10n,
    required String formatLabel,
    required int currentIndex,
  }) {
    final chaptered = opened is ChapteredDocument
        ? opened as ChapteredDocument
        : null;
    final chapterCount = chaptered?.chapterCount ?? tocItems.length;
    if (tocItems.isNotEmpty &&
        chapterCount > 0 &&
        tocItems.length != chapterCount) {
      final index = (chaptered?.chapterIndex ?? currentIndex).clamp(
        0,
        chapterCount - 1,
      );
      return l10n.readerSection(index + 1, chapterCount);
    }
    final pages = reflowChromePages(
      pageIndex: foliateSession?.pageIndex,
      pageCount: foliateSession?.pageCount,
    );
    if (pages != null) {
      return l10n.readerSection(pages.current, pages.total);
    }
    if (tocItems.isEmpty) return formatLabel;
    return l10n.readerSection(currentIndex + 1, tocItems.length);
  }

  Future<void> _openReadingSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ReadingSettingsSheet(
        showComicLayout: opened is ComicReaderDocument,
        showPdfZoom: opened is PdfReaderDocument,
      ),
    );
  }

  List<String> _pageParagraphs(HtmlChapteredDocument reader) {
    return splitTextParagraphs(_pageText(reader));
  }

  String _pageText(HtmlChapteredDocument reader) {
    final session = foliateSession;
    final source = reader.currentChapterText;
    if (session == null || source.isEmpty) return source;
    final page = session.currentPage;
    final start = page.startOffset.clamp(0, source.length);
    final end = page.endOffset.clamp(start, source.length);
    return source.substring(start, end);
  }
}
