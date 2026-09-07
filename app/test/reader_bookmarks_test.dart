import 'package:app/core/models.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_bookmarks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReaderAnnotation makeNote({
    String id = 'n1',
    String note = 'my note',
    String source = userNoteSource,
    String locatorLabel = 'p.1',
  }) {
    return ReaderAnnotation(
      id: id,
      note: note,
      locatorLabel: locatorLabel,
      source: source,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  group('isBookmark', () {
    test('returns true when source is bookmarkSource', () {
      expect(isBookmark(makeNote(source: bookmarkSource)), isTrue);
    });

    test('returns false for user notes', () {
      expect(isBookmark(makeNote(source: userNoteSource)), isFalse);
    });

    test('returns false for assistant notes', () {
      expect(isBookmark(makeNote(source: assistantNoteSource)), isFalse);
    });
  });

  group('bookmarksOf', () {
    test('returns only bookmark annotations', () {
      final all = [
        makeNote(id: 'bm1', source: bookmarkSource),
        makeNote(id: 'n1', source: userNoteSource),
        makeNote(id: 'bm2', source: bookmarkSource),
      ];
      expect(bookmarksOf(all).map((n) => n.id), ['bm1', 'bm2']);
    });

    test('returns empty list when there are no bookmarks', () {
      expect(bookmarksOf([makeNote(source: userNoteSource)]), isEmpty);
    });
  });

  group('notesOf', () {
    test('excludes bookmark annotations', () {
      final all = [
        makeNote(id: 'n1', source: userNoteSource),
        makeNote(id: 'bm1', source: bookmarkSource),
        makeNote(id: 'n2', source: assistantNoteSource),
      ];
      expect(notesOf(all).map((n) => n.id), ['n1', 'n2']);
    });

    test('returns empty list when every annotation is a bookmark', () {
      expect(notesOf([makeNote(source: bookmarkSource)]), isEmpty);
    });
  });

  group('bookmarkAt', () {
    test('creates a bookmark with empty note and quote', () {
      final bm = bookmarkAt(
        locator: const EpubLocator(href: 'ch1.xhtml'),
        now: DateTime.utc(2026, 1, 1, 0, 0, 0),
      );
      expect(bm.note, isEmpty);
      expect(bm.quote, isEmpty);
      expect(bm.source, bookmarkSource);
    });

    test('id is prefixed with bm- and uses microsecondsSinceEpoch', () {
      final bm = bookmarkAt(
        locator: const PdfLocator(page: 1),
        now: DateTime.utc(2026, 6, 15, 12, 30, 0),
      );
      expect(bm.id, startsWith('bm-'));
      expect(bm.createdAt, DateTime.utc(2026, 6, 15, 12, 30, 0));
    });

    test('uses now parameter when provided, otherwise DateTime.now', () {
      final fixed = DateTime.utc(2026, 3, 1);
      final bm = bookmarkAt(locator: const TextLocator(offset: 0), now: fixed);
      expect(bm.createdAt, fixed);
    });

    test('encodes the locator into locatorLabel', () {
      const locator = ComicLocator(page: 5);
      final bm = bookmarkAt(locator: locator);
      expect(bm.locatorLabel, isNotEmpty);
    });
  });
}
