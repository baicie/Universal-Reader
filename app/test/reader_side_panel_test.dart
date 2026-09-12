import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/models.dart';
import 'package:app/features/reader/reader_side_panel.dart';
import 'package:app/features/reader/reader_bookmarks_pane.dart';
import 'package:app/features/reader/reader_notes_pane.dart';
import 'package:app/features/reader/reader_search_pane.dart';
import 'package:app/l10n/generated/app_localizations.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 800,
          width: 240,
          child: child,
        ),
      ),
    );
  }

  TocItem item(String title) =>
      TocItem(title: title, locator: const TextLocator(offset: 0));

  testWidgets('renders nothing relevant when every toggle is off', (tester) async {
    await tester.pumpWidget(wrap(ReaderSidePanel(
      background: const Color(0xFFF0EADF),
      ink: Colors.black,
      muted: Colors.grey,
      accent: Colors.blue,
      showSearch: false,
      showNotes: false,
      showBookmarks: false,
      showToc: false,
      searchQuery: '',
      searchHits: const [],
      notes: const [],
      tocItems: const [],
      currentHref: '',
      currentFragment: null,
      currentIndex: 0,
      foliateSession: null,
      onSearchQuery: (_) {},
      onSearchOpen: (_) {},
      onNoteOpen: (_) {},
      onNoteDelete: (_) {},
      onBookmarkOpen: (_) {},
      onBookmarkDelete: (_) {},
      onTocOpen: (_) {},
    )));
    // No pane should be visible
    expect(find.byKey(searchPanelKey), findsNothing);
    expect(find.byKey(notesPanelKey), findsNothing);
    expect(find.byKey(bookmarksPanelKey), findsNothing);
  });

  testWidgets('renders only the search pane when showSearch is on', (tester) async {
    await tester.pumpWidget(wrap(ReaderSidePanel(
      background: const Color(0xFFF0EADF),
      ink: Colors.black,
      muted: Colors.grey,
      accent: Colors.blue,
      showSearch: true,
      showNotes: false,
      showBookmarks: false,
      showToc: false,
      searchQuery: 'foo',
      searchHits: const [],
      notes: const [],
      tocItems: const [],
      currentHref: '',
      currentFragment: null,
      currentIndex: 0,
      foliateSession: null,
      onSearchQuery: (_) {},
      onSearchOpen: (_) {},
      onNoteOpen: (_) {},
      onNoteDelete: (_) {},
      onBookmarkOpen: (_) {},
      onBookmarkDelete: (_) {},
      onTocOpen: (_) {},
    )));
    expect(find.byKey(searchPanelKey), findsOneWidget);
    expect(find.byKey(notesPanelKey), findsNothing);
    expect(find.byKey(bookmarksPanelKey), findsNothing);
  });

  testWidgets('renders all four panes when every toggle is on', (tester) async {
    await tester.pumpWidget(wrap(ReaderSidePanel(
      background: const Color(0xFFF0EADF),
      ink: Colors.black,
      muted: Colors.grey,
      accent: Colors.blue,
      showSearch: true,
      showNotes: true,
      showBookmarks: true,
      showToc: true,
      searchQuery: '',
      searchHits: const [],
      notes: const [],
      tocItems: [item('Chapter 1')],
      currentHref: '',
      currentFragment: null,
      currentIndex: 0,
      foliateSession: null,
      onSearchQuery: (_) {},
      onSearchOpen: (_) {},
      onNoteOpen: (_) {},
      onNoteDelete: (_) {},
      onBookmarkOpen: (_) {},
      onBookmarkDelete: (_) {},
      onTocOpen: (_) {},
    )));
    expect(find.byKey(searchPanelKey), findsOneWidget);
    expect(find.byKey(notesPanelKey), findsOneWidget);
    expect(find.byKey(bookmarksPanelKey), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
  });

  testWidgets('toc tile invokes onTocOpen', (tester) async {
    TocItem? opened;
    await tester.pumpWidget(wrap(ReaderSidePanel(
      background: const Color(0xFFF0EADF),
      ink: Colors.black,
      muted: Colors.grey,
      accent: Colors.blue,
      showSearch: false,
      showNotes: false,
      showBookmarks: false,
      showToc: true,
      searchQuery: '',
      searchHits: const [],
      notes: const [],
      tocItems: [item('Chapter 1'), item('Chapter 2')],
      currentHref: '',
      currentFragment: null,
      currentIndex: 0,
      foliateSession: null,
      onSearchQuery: (_) {},
      onSearchOpen: (_) {},
      onNoteOpen: (_) {},
      onNoteDelete: (_) {},
      onBookmarkOpen: (_) {},
      onBookmarkDelete: (_) {},
      onTocOpen: (it) => opened = it,
    )));
    await tester.tap(find.text('Chapter 2'));
    expect(opened?.title, 'Chapter 2');
  });

  testWidgets('empty toc renders the untitled fallback', (tester) async {
    await tester.pumpWidget(wrap(ReaderSidePanel(
      background: const Color(0xFFF0EADF),
      ink: Colors.black,
      muted: Colors.grey,
      accent: Colors.blue,
      showSearch: false,
      showNotes: false,
      showBookmarks: false,
      showToc: true,
      searchQuery: '',
      searchHits: const [],
      notes: const [],
      tocItems: const [],
      currentHref: '',
      currentFragment: null,
      currentIndex: 0,
      foliateSession: null,
      onSearchQuery: (_) {},
      onSearchOpen: (_) {},
      onNoteOpen: (_) {},
      onNoteDelete: (_) {},
      onBookmarkOpen: (_) {},
      onBookmarkDelete: (_) {},
      onTocOpen: (_) {},
    )));
    await tester.pumpAndSettle();
    // Eyebrow wraps the table-of-contents label.
    expect(find.text('目录'), findsOneWidget);
    // No toc item → fallback text is rendered.
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.untitledSection), findsOneWidget);
  });

  testWidgets('search query edits invoke onSearchQuery', (tester) async {
    String? lastQuery;
    await tester.pumpWidget(wrap(ReaderSidePanel(
      background: const Color(0xFFF0EADF),
      ink: Colors.black,
      muted: Colors.grey,
      accent: Colors.blue,
      showSearch: true,
      showNotes: false,
      showBookmarks: false,
      showToc: false,
      searchQuery: '',
      searchHits: const [],
      notes: const [],
      tocItems: const [],
      currentHref: '',
      currentFragment: null,
      currentIndex: 0,
      foliateSession: null,
      onSearchQuery: (q) => lastQuery = q,
      onSearchOpen: (_) {},
      onNoteOpen: (_) {},
      onNoteDelete: (_) {},
      onBookmarkOpen: (_) {},
      onBookmarkDelete: (_) {},
      onTocOpen: (_) {},
    )));
    await tester.enterText(find.byKey(readerSearchFieldKey), 'hello');
    expect(lastQuery, 'hello');
  });
}
