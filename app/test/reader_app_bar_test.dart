import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/features/reader/reader_app_bar.dart';
import 'package:app/features/reader/reader_bookmarks_pane.dart';

void main() {
  Widget buildTestTarget({
    required String title,
    required bool ask,
    required bool showSearch,
    required bool showNotes,
    required bool bookmarks,
    required bool toc,
    VoidCallback? onAskToggle,
    VoidCallback? onSearchToggle,
    VoidCallback? onNotesToggle,
    VoidCallback? onBookmarksToggle,
    VoidCallback? onTocToggle,
    VoidCallback? onAddBookmark,
    VoidCallback? onOpenSettings,
    VoidCallback? onBack,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: ReaderAppBar(
          title: title,
          ask: ask,
          showSearch: showSearch,
          showNotes: showNotes,
          bookmarks: bookmarks,
          toc: toc,
          onAskToggle: onAskToggle,
          onSearchToggle: onSearchToggle,
          onNotesToggle: onNotesToggle,
          onBookmarksToggle: onBookmarksToggle,
          onTocToggle: onTocToggle,
          onAddBookmark: onAddBookmark,
          onOpenSettings: onOpenSettings,
          onBack: onBack,
        ),
      ),
    );
  }

  testWidgets('shows the book title', (tester) async {
    await tester.pumpWidget(buildTestTarget(
      title: 'My Novel',
      ask: false,
      showSearch: false,
      showNotes: false,
      bookmarks: false,
      toc: false,
    ));
    expect(find.text('My Novel'), findsOneWidget);
  });

  testWidgets('back button calls onBack', (tester) async {
    var called = false;
    await tester.pumpWidget(buildTestTarget(
      title: 'Book',
      ask: false,
      showSearch: false,
      showNotes: false,
      bookmarks: false,
      toc: false,
      onBack: () => called = true,
    ));
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(called, isTrue);
  });

  testWidgets('search toggle calls onSearchToggle', (tester) async {
    var searchCalls = 0;
    await tester.pumpWidget(buildTestTarget(
      title: 'Book',
      ask: false,
      showSearch: false,
      showNotes: false,
      bookmarks: false,
      toc: false,
      onSearchToggle: () => searchCalls++,
    ));
    await tester.tap(find.byIcon(Icons.search));
    expect(searchCalls, 1);
  });

  testWidgets('ask toggle calls onAskToggle', (tester) async {
    var askCalls = 0;
    await tester.pumpWidget(buildTestTarget(
      title: 'Book',
      ask: false,
      showSearch: false,
      showNotes: false,
      bookmarks: false,
      toc: false,
      onAskToggle: () => askCalls++,
    ));
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    expect(askCalls, 1);
  });

  testWidgets('add bookmark button is tappable', (tester) async {
    var bookmarkCalls = 0;
    await tester.pumpWidget(buildTestTarget(
      title: 'Book',
      ask: false,
      showSearch: false,
      showNotes: false,
      bookmarks: false,
      toc: false,
      onAddBookmark: () => bookmarkCalls++,
    ));
    await tester.tap(find.byKey(addBookmarkButtonKey));
    expect(bookmarkCalls, 1);
  });

  testWidgets('settings button calls onOpenSettings', (tester) async {
    var settingsCalls = 0;
    await tester.pumpWidget(buildTestTarget(
      title: 'Book',
      ask: false,
      showSearch: false,
      showNotes: false,
      bookmarks: false,
      toc: false,
      onOpenSettings: () => settingsCalls++,
    ));
    await tester.tap(find.byIcon(Icons.text_fields));
    expect(settingsCalls, 1);
  });

  testWidgets('active states render without crashing', (tester) async {
    await tester.pumpWidget(buildTestTarget(
      title: 'Book',
      ask: true,
      showSearch: true,
      showNotes: true,
      bookmarks: true,
      toc: true,
    ));
    expect(find.byIcon(Icons.chat_bubble), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2), findsOneWidget);
    expect(find.byIcon(Icons.bookmarks), findsOneWidget);
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
  });
}
