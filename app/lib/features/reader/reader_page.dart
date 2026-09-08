import 'package:flutter/material.dart';
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
import '../../core/reader_progress_label.dart';
import '../../core/reader_runtime.dart';
import '../../core/reader_state.dart';
import '../../core/reader_text.dart';
import '../../core/reading_surface.dart';
import '../../core/reflow_nav.dart';
import '../../core/text_document.dart';
import '../../l10n/l10n.dart';
import '../library/annotation_store.dart';
import 'open_reader.dart';
import 'reader_app_bar.dart';
import 'reader_bookmarks.dart';
import 'reader_chrome_overlay.dart';
import 'reader_gesture_shell.dart';
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
  ReaderRuntime runtime = const ReaderRuntime();
  double progress = 0;

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
      _setRuntime(
        runtime.loaded(
          document: UnavailableReaderDocument(
            metadata: DocumentMetadata(
              id: widget.id,
              title: widget.id,
              author: '',
              format: DocumentFormat.unknown,
              type: DocumentType.reflow,
            ),
          ),
          body: '',
          toc: const <TocItem>[],
          progress: progress,
        ),
      );
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
    final session = reader is HtmlChapteredDocument
        ? FoliateSession.open(reader)
        : null;
    if (session != null && reader is HtmlChapteredDocument) {
      session.goToPage(
        reflowPageIndexForProgress(
          progress: progress,
          chapterCount: reader.chapterCount,
          chapterIndex: reader.chapterIndex,
          pageCount: session.pageCount,
        ),
      );
    }
    _setRuntime(
      runtime
          .loaded(
            document: reader,
            body: readerCurrentBody(reader),
            toc: items,
            progress: progress,
          )
          .copyWith(
            notes: loadedNotes,
            fileBytes: bytes,
            foliateSession: session,
          ),
    );
  }

  Future<void> _goTo(
    Locator locator, {
    bool syncProgress = true,
    String? fragment,
    String? scrollQuote,
  }) async {
    final reader = runtime.opened;
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
    var nextRuntime = runtime.copyWith(
      body: readerCurrentBody(reader),
      foliateSession: session,
      foliateFragment: resolvedFragment,
      foliateScrollQuote: scrollQuote,
    );
    if (resolvedFragment != null) {
      nextRuntime = nextRuntime.copyWith(
        foliateFragmentEpoch: nextRuntime.foliateFragmentEpoch + 1,
      );
    }
    if (scrollQuote != null) {
      nextRuntime = nextRuntime.copyWith(
        foliateScrollQuoteEpoch: nextRuntime.foliateScrollQuoteEpoch + 1,
      );
    }
    if (syncProgress &&
        reader is ChapteredDocument &&
        reader.chapterCount > 0) {
      progress = reader.chapterIndex / reader.chapterCount;
      ref.read(libraryProvider).updateProgress(widget.id, progress);
    }
    _setRuntime(nextRuntime.copyWith(progress: progress));
  }

  Future<void> _goToToc(TocItem item) async {
    final locator = item.locator;
    if (locator is EpubLocator) {
      final fragment = locator.fragment;
      final session = runtime.foliateSession;
      if (session != null &&
          fragment != null &&
          reflowSameHref(session.href, locator.href)) {
        if (!mounted) return;
        _setRuntime(runtime.bumpFragmentEpoch(fragment));
        return;
      }
    }
    await _goTo(locator);
  }

  Future<void> _onSearchHit(SearchResult hit) async {
    final quote = reflowScrollQuote(runtime.searchQuery);
    final locator = hit.locator;
    if (locator is EpubLocator &&
        runtime.foliateSession != null &&
        reflowSameHref(runtime.foliateSession!.href, locator.href)) {
      if (quote == null || !mounted) return;
      _setRuntime(runtime.bumpScrollQuoteEpoch(quote));
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
        runtime.foliateSession != null &&
        reflowSameHref(runtime.foliateSession!.href, locator.href)) {
      if (quote == null || !mounted) return;
      _setRuntime(runtime.bumpScrollQuoteEpoch(quote));
      return;
    }
    await _goTo(locator, scrollQuote: quote);
  }

  Future<Locator> _bookmarkLocator() async {
    final reader = runtime.opened;
    if (reader == null) return const TextLocator(offset: 0);
    final current = await reader.currentLocator();
    final session = runtime.foliateSession;
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
    if (runtime.opened == null || runtime.loading) return;
    final mark = bookmarkAt(locator: await _bookmarkLocator());
    await ref.read(aiRuntimeProvider).annotations.append(widget.id, mark);
    if (!mounted) return;
    setState(() {
      runtime = runtime.withNote(mark);
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
    _setRuntime(runtime.copyWith(notes: next));
  }

  Future<void> _searchBook(String query) async {
    final reader = runtime.opened;
    _setRuntime(runtime.copyWith(searchQuery: query));
    if (reader == null) {
      _setRuntime(runtime.withSearchHits(const []));
      return;
    }
    final hits = await hitsForQuery(reader, query);
    if (!mounted) return;
    _setRuntime(runtime.withSearchHits(hits));
  }

  Future<void> _saveSelection() async {
    final quote = runtime.pendingQuote;
    if (quote == null) return;
    final note = noteFromSelection(
      quote,
      locatorLabel: encodeLocator(await _bookmarkLocator()),
    );
    if (note == null) {
      _setRuntime(runtime.copyWith(pendingQuote: null));
      return;
    }
    await ref.read(aiRuntimeProvider).annotations.append(widget.id, note);
    if (!mounted) return;
    _setRuntime(runtime.withNote(note).copyWith(pendingQuote: null));
  }

  void _onFoliateSelection(FoliateSelection selection) {
    _setRuntime(runtime.copyWith(pendingQuote: selection.quote));
  }

  void _onFoliateHostEvent(Map<String, Object?> event) {
    final session = runtime.foliateSession;
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
      _setRuntime(runtime.bumpFragmentEpoch(fragment));
      return;
    }
    await _goTo(EpubLocator(href: target), fragment: fragment);
  }

  Future<void> _turnReflow({required bool next}) async {
    final reader = runtime.opened;
    final session = runtime.foliateSession;
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
    final reader = runtime.opened;
    if (reader is! ChapteredDocument) return;
    if (index < 0 || index >= reader.chapterCount) return;
    final at = reader.chapterCount <= 1 ? 0.0 : index / reader.chapterCount;
    await _goTo(reader.locatorForProgress(at));
    if (lastPage) {
      runtime.foliateSession?.goToLastPage();
      if (mounted) setState(() {});
    }
    _syncReflowProgress();
  }

  void _syncReflowProgress() {
    final reader = runtime.opened;
    final session = runtime.foliateSession;
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
    setState(() {
      progress = value;
      runtime = runtime.copyWith(progress: value);
    });
    ref.read(libraryProvider).updateProgress(widget.id, value);
    final reader = runtime.opened;
    if (reader is! ChapteredDocument) return;
    if (reader is HtmlChapteredDocument) {
      await _goTo(reader.locatorForProgress(value), syncProgress: false);
      final session = runtime.foliateSession;
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
    _setRuntime(runtime.copyWith(body: readerCurrentBody(reader)));
  }

  void _toggleChrome() {
    setState(() => chrome = !chrome);
  }

  void _toggleAsk() {
    setState(() => ask = !ask);
  }

  void _toggleSearch() => _togglePanel(PanelKind.search);
  void _toggleNotes() => _togglePanel(PanelKind.notes);
  void _toggleBookmarks() => _togglePanel(PanelKind.bookmarks);
  void _toggleToc() => _togglePanel(PanelKind.toc);

  void _togglePanel(PanelKind kind) {
    setState(() => panels = panels.toggle(kind));
  }

  void _setRuntime(ReaderRuntime next) {
    setState(() => runtime = next);
  }

  PreferredSizeWidget? _buildAppBar(String title) {
    if (!chrome) return null;
    return ReaderAppBar(
      title: title,
      ask: ask,
      showSearch: panels.showSearch,
      showNotes: panels.showNotes,
      bookmarks: panels.bookmarks,
      toc: panels.toc,
      onAskToggle: _toggleAsk,
      onSearchToggle: _toggleSearch,
      onNotesToggle: _toggleNotes,
      onBookmarksToggle: _toggleBookmarks,
      onTocToggle: _toggleToc,
      onAddBookmark: _addBookmark,
      onOpenSettings: _openReadingSettings,
      onBack: () => context.go('/'),
    );
  }

  ReaderSidePanel _buildSidePanel({
    required Color tocBg,
    required Color ink,
    required Color muted,
    required Color accent,
    required int currentIndex,
    required String currentHref,
  }) {
    return ReaderSidePanel(
      background: tocBg,
      ink: ink,
      muted: muted,
      accent: accent,
      showSearch: panels.showSearch,
      showNotes: panels.showNotes,
      showBookmarks: panels.bookmarks,
      showToc: panels.toc,
      searchQuery: runtime.searchQuery,
      searchHits: runtime.searchHits,
      notes: runtime.notes,
      tocItems: runtime.tocItems,
      currentHref: currentHref,
      currentFragment: runtime.foliateFragment,
      currentIndex: currentIndex,
      foliateSession: runtime.foliateSession,
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
    );
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
      opened: runtime.opened,
      tocItems: runtime.tocItems,
      body: runtime.body,
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
      loading: runtime.loading,
      opened: runtime.opened,
      document: document,
      isTruncated:
          runtime.opened is ChapteredDocument &&
          (runtime.opened as ChapteredDocument).truncated,
    );

    return Scaffold(
      backgroundColor: paper,
      appBar: _buildAppBar(title),
      body: ReaderGestureShell(
        isReflowOpened: runtime.opened is HtmlChapteredDocument,
        hasPendingQuote:
            runtime.pendingQuote != null &&
            runtime.pendingQuote!.trim().isNotEmpty,
        onToggleChrome: _toggleChrome,
        onTurnNext: () => _turnReflow(next: true),
        onTurnPrevious: () => _turnReflow(next: false),
        child: Stack(
          children: [
            Row(
              children: [
                if (sideOpen)
                  _buildSidePanel(
                    tocBg: tocBg,
                    ink: ink,
                    muted: muted,
                    accent: accent,
                    currentIndex: currentIndex,
                    currentHref: currentHref,
                  ),
                Expanded(
                  child: ReaderReadingPane(
                    opened: runtime.opened,
                    chrome: chrome,
                    fileBytes: runtime.fileBytes,
                    foliateSession: runtime.foliateSession,
                    foliateFragment: runtime.foliateFragment,
                    foliateFragmentEpoch: runtime.foliateFragmentEpoch,
                    foliateScrollQuote: runtime.foliateScrollQuote,
                    foliateScrollQuoteEpoch: runtime.foliateScrollQuoteEpoch,
                    tocItems: runtime.tocItems,
                    notes: runtime.notes,
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
                    onComicTurn: (index) =>
                        _goTo(ComicLocator(page: index + 1)),
                    onToggleChrome: _toggleChrome,
                    onFoliateSelection: _onFoliateSelection,
                    onFoliateHostEvent: _onFoliateHostEvent,
                    onFoliateNext: () => _turnReflow(next: true),
                    onFoliatePrevious: () => _turnReflow(next: false),
                    onSelectionChanged: (quote) =>
                        _setRuntime(runtime.copyWith(pendingQuote: quote)),
                  ),
                ),
              ],
            ),
            ReaderChromeOverlay(
              runtime: runtime,
              chrome: chrome,
              ask: ask,
              wide: wide,
              paper: paper,
              muted: muted,
              ink: ink,
              sideOpen: sideOpen,
              progress: progress,
              progressLabel: _progressLabel(
                l10n: l10n,
                formatLabel: formatLabel,
                currentIndex: currentIndex,
              ),
              formatLabel: formatLabel,
              currentIndex: currentIndex,
              onJump: _goTo,
              onSaveSelection: _saveSelection,
              onDismissSelection: () =>
                  _setRuntime(runtime.copyWith(pendingQuote: null)),
              onSeekProgress: _seekProgress,
            ),
          ],
        ),
      ),
    );
  }

  String _progressLabel({
    required AppLocalizations l10n,
    required String formatLabel,
    required int currentIndex,
  }) {
    return readerProgressLabel(
      runtime: runtime,
      l10n: l10n,
      formatLabel: formatLabel,
      currentIndex: currentIndex,
    );
  }

  Future<void> _openReadingSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ReadingSettingsSheet(
        showComicLayout: runtime.opened is ComicReaderDocument,
        showPdfZoom: runtime.opened is PdfReaderDocument,
      ),
    );
  }

  List<String> _pageParagraphs(HtmlChapteredDocument reader) {
    return splitTextParagraphs(_pageText(reader));
  }

  String _pageText(HtmlChapteredDocument reader) {
    final session = runtime.foliateSession;
    final source = reader.currentChapterText;
    if (session == null || source.isEmpty) return source;
    final page = session.currentPage;
    final start = page.startOffset.clamp(0, source.length);
    final end = page.endOffset.clamp(start, source.length);
    return source.substring(start, end);
  }
}
