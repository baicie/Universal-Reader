import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_bookmarks_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReaderAnnotation makeBookmark({required String id, String locatorLabel = 'p.1'}) {
    return ReaderAnnotation(
      id: id,
      note: '',
      quote: '',
      locatorLabel: locatorLabel,
      source: bookmarkSource,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  group('ReaderBookmarksPane', () {
    testWidgets('renders the column with the panel key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBookmarksPane(
              title: 'Bookmarks',
              emptyLabel: 'No bookmarks',
              deleteLabel: 'Delete',
              bookmarks: const [],
              onOpen: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      expect(find.byKey(bookmarksPanelKey), findsOneWidget);
    });

    testWidgets('shows emptyLabel when bookmarks is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBookmarksPane(
              title: 'Bookmarks',
              emptyLabel: 'No bookmarks yet',
              deleteLabel: 'Delete',
              bookmarks: const [],
              onOpen: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('No bookmarks yet'), findsOneWidget);
    });

    testWidgets('hides emptyLabel when bookmarks is not empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBookmarksPane(
              title: 'Bookmarks',
              emptyLabel: 'No bookmarks',
              deleteLabel: 'Delete',
              bookmarks: [makeBookmark(id: 'bm1', locatorLabel: 'ch.1')],
              onOpen: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('No bookmarks'), findsNothing);
    });

    testWidgets('shows a row per bookmark with the locator label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBookmarksPane(
              title: 'Bookmarks',
              emptyLabel: 'No bookmarks',
              deleteLabel: 'Delete',
              bookmarks: [
                makeBookmark(id: 'bm1', locatorLabel: 'Chapter 1'),
                makeBookmark(id: 'bm2', locatorLabel: 'Chapter 2'),
              ],
              onOpen: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Chapter 2'), findsOneWidget);
    });

    testWidgets('tapping the locator label calls onOpen with that bookmark', (tester) async {
      ReaderAnnotation? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBookmarksPane(
              title: 'Bookmarks',
              emptyLabel: 'No bookmarks',
              deleteLabel: 'Delete',
              bookmarks: [makeBookmark(id: 'bm1', locatorLabel: 'p.5')],
              onOpen: (mark) => opened = mark,
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('p.5'));
      expect(opened?.id, 'bm1');
    });

    testWidgets('delete button has the correct key per bookmark id', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBookmarksPane(
              title: 'Bookmarks',
              emptyLabel: 'No bookmarks',
              deleteLabel: 'Delete',
              bookmarks: [makeBookmark(id: 'bm-x')],
              onOpen: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('delete-bookmark-bm-x')), findsOneWidget);
    });

    testWidgets('tapping the delete button calls onDelete with that bookmark', (tester) async {
      ReaderAnnotation? deleted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBookmarksPane(
              title: 'Bookmarks',
              emptyLabel: 'No bookmarks',
              deleteLabel: 'Delete',
              bookmarks: [makeBookmark(id: 'bm1', locatorLabel: 'p.3')],
              onOpen: (_) {},
              onDelete: (mark) => deleted = mark,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('delete-bookmark-bm1')));
      expect(deleted?.id, 'bm1');
    });
  });
}
