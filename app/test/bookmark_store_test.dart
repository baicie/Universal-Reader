import 'package:app/core/locator_codec.dart';
import 'package:app/core/models.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_bookmarks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bookmarks stay on the same book and are not mixed into notes',
    () async {
      final store = InMemoryAnnotationRepository();
      await store.append(
        'notes.txt',
        ReaderAnnotation(
          id: 'n1',
          note: 'keep',
          quote: 'hello',
          source: userNoteSource,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await store.append(
        'notes.txt',
        bookmarkAt(
          locator: const TextLocator(offset: 12),
          now: DateTime.utc(2026, 1, 2),
        ),
      );

      final all = await store.load('notes.txt');
      expect(bookmarksOf(all), hasLength(1));
      expect(notesOf(all), hasLength(1));
      expect(bookmarksOf(all).single.source, bookmarkSource);
      expect(await store.load('other.txt'), isEmpty);
      expect(
        decodeLocator(bookmarksOf(all).single.locatorLabel),
        isA<TextLocator>(),
      );
      expect(
        (decodeLocator(
          bookmarksOf(all).single.locatorLabel,
        ) as TextLocator).offset,
        12,
      );
    },
  );

  test('bookmark locators round-trip through the label', () {
    expect(
      decodeLocator(
        encodeLocator(
          const EpubLocator(href: 'ch1.xhtml', cfi: 'epubcfi(ch1:10)'),
        ),
      ),
      isA<EpubLocator>(),
    );
    expect(
      (decodeLocator(
        encodeLocator(const PdfLocator(page: 3)),
      ) as PdfLocator).page,
      3,
    );
  });
}
