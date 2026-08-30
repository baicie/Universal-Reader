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
import '../../core/reader_runtime.dart';
import '../../core/reading_surface.dart';
import '../../core/reflow_nav.dart';
import '../../core/text_document.dart';
import '../../l10n/l10n.dart';
import '../../widgets/eyebrow.dart';
import '../library/annotation_store.dart';
import '../tools/reader_ai_panel.dart';
import 'open_reader.dart';
import 'reader_bookmarks.dart';
import 'reader_bookmarks_pane.dart';
import 'reader_notes.dart';
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
      body = _bodyFor(reader);
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

  String _bodyFor(ReaderDocument reader) {
    if (reader is ChapteredDocument) return reader.currentChapterText;
    return '';
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
      body = _bodyFor(reader);
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
      body = _bodyFor(reader);
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
    final sideOpen = toc || bookmarks || showNotes || showSearch;
    final currentIndex = opened is ChapteredDocument
        ? (opened as ChapteredDocument).chapterIndex
        : 0;
    final chapterCount = opened is ChapteredDocument
        ? (opened as ChapteredDocument).chapterCount
        : tocItems.length;
    final currentHref = opened is HtmlChapteredDocument
        ? (opened as HtmlChapteredDocument).currentChapterHref
        : '';
    final currentTitle = opened is HtmlChapteredDocument
        ? (opened as HtmlChapteredDocument).currentChapterTitle
        : tocItems.isEmpty
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
                      Material(
                        color: tocBg,
                        child: GestureDetector(
                          onTap: () {},
                          child: SizedBox(
                            width: 240,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                16,
                                24,
                              ),
                              children: [
                                if (showSearch) ...[
                                  ReaderSearchPane(
                                    title: l10n.searchInBook,
                                    hint: l10n.searchInBookHint,
                                    emptyLabel: l10n.noSearchResults,
                                    query: searchQuery,
                                    hits: searchHits,
                                    onQuery: _searchBook,
                                    onOpen: _onSearchHit,
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
                                    onOpen: _onNoteOpen,
                                    onDelete: (note) => _removeMark(note.id),
                                  ),
                                  if (bookmarks || toc)
                                    const SizedBox(height: 28),
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
                                      style: TextStyle(
                                        color: muted,
                                        height: 1.4,
                                      ),
                                    )
                                  else
                                    ..._tocTiles(
                                      items: tocItems,
                                      currentIndex: currentIndex,
                                      currentHref: currentHref,
                                      currentFragment: foliateFragment,
                                      ink: ink,
                                      accent: accent,
                                      l10n: l10n,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: _readingPane(
                        l10n: l10n,
                        document: document,
                        muted: muted,
                        heading: heading,
                        showHeading: currentTitle.trim().isNotEmpty,
                        paragraphs: paragraphs,
                        currentIndex: currentIndex,
                        chapterCount: chapterCount,
                        surface: surface,
                        formatLabel: formatLabel,
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
                                  onChanged: _seekProgress,
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _progressLabel(
                                        l10n: l10n,
                                        formatLabel: formatLabel,
                                        currentIndex: currentIndex,
                                      ),
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
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
        ),
      ),
    );
  }

  List<Widget> _tocTiles({
    required List<TocItem> items,
    required int currentIndex,
    required String currentHref,
    String? currentFragment,
    required Color ink,
    required Color accent,
    required AppLocalizations l10n,
    int depth = 0,
  }) {
    final tiles = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final current = currentHref.isEmpty
          ? depth == 0 && i == currentIndex
          : reflowTocItemCurrent(
              item,
              href: currentHref,
              fragment: currentFragment,
            );
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(depth * 12.0, 6, 0, 6),
          child: InkWell(
            onTap: () => _goToToc(item),
            child: Text(
              item.title.trim().isEmpty ? l10n.untitledSection : item.title,
              style: TextStyle(
                fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                color: current ? accent : ink,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
      if (item.children.isNotEmpty) {
        tiles.addAll(
          _tocTiles(
            items: item.children,
            currentIndex: currentIndex,
            currentHref: currentHref,
            currentFragment: currentFragment,
            ink: ink,
            accent: accent,
            l10n: l10n,
            depth: depth + 1,
          ),
        );
      }
    }
    return tiles;
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

  Widget _readingPane({
    required AppLocalizations l10n,
    required LibraryDocument? document,
    required Color muted,
    required String heading,
    required bool showHeading,
    required List<String> paragraphs,
    required int currentIndex,
    required int chapterCount,
    required ReadingSurface surface,
    required String formatLabel,
  }) {
    final reader = opened;
    if (reader is ComicReaderDocument) {
      return Padding(
        padding: EdgeInsets.only(bottom: chrome ? 72 : 0),
        child: IsolatedComicView(
          document: reader,
          layout: ref.watch(readerPrefsProvider).comicLayout,
          direction: ref.watch(readerPrefsProvider).comicDirection,
          onTurn: (index) {
            _goTo(ComicLocator(page: index + 1));
          },
          onToggleChrome: () {
            setState(() => chrome = !chrome);
          },
        ),
      );
    }
    if (reader is PdfReaderDocument) {
      return Padding(
        padding: EdgeInsets.only(bottom: chrome ? 72 : 0),
        child: IsolatedPdfView(
          document: reader,
          bytes: fileBytes,
          zoom: ref.watch(readerPrefsProvider).pdfZoom,
          fallback: _annotatedBody(surface: surface, paragraphs: paragraphs),
        ),
      );
    }
    if (reader is HtmlChapteredDocument) {
      return Padding(
        padding: EdgeInsets.only(bottom: chrome ? 72 : 0),
        child: IsolatedFoliateView(
          document: reader,
          session: foliateSession,
          surface: surface,
          fallback: _annotatedBody(
            surface: surface,
            paragraphs: _pageParagraphs(reader),
          ),
          quotes: quoteHighlights(notes),
          fragment: foliateFragment,
          fragmentEpoch: foliateFragmentEpoch,
          scrollQuote: foliateScrollQuote,
          scrollQuoteEpoch: foliateScrollQuoteEpoch,
          pageIndex: foliateSession?.pageIndex ?? 0,
          onSelection: _onFoliateSelection,
          onHostEvent: _onFoliateHostEvent,
          onNext: () => _turnReflow(next: true),
          onPrevious: () => _turnReflow(next: false),
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
          child: _readerBody(
            l10n: l10n,
            document: document,
            muted: muted,
            heading: heading,
            showHeading: showHeading,
            paragraphs: paragraphs,
            currentIndex: currentIndex,
            chapterCount: chapterCount,
            surface: surface,
            formatLabel: formatLabel,
          ),
        ),
      ),
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
    required int chapterCount,
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
              : l10n.readerSection(
                  currentIndex + 1,
                  chapterCount <= 0 ? tocItems.length : chapterCount,
                ),
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
        _annotatedBody(surface: surface, paragraphs: paragraphs),
      ],
    );
  }

  List<String> _pageParagraphs(HtmlChapteredDocument reader) {
    final text = _pageText(reader);
    return text
        .split(RegExp(r'\n+'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
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
