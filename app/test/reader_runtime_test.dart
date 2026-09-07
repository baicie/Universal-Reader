import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/reader_state.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/tools/sample_reader_document.dart';
import 'package:flutter_test/flutter_test.dart';

SampleReaderDocument _doc() => SampleReaderDocument(
      metadata: const DocumentMetadata(
        id: 'book-1',
        title: 'A',
        author: 'B',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
    );

void main() {
  group('ReaderRuntime', () {
    test('default state is loading with no document', () {
      const rt = ReaderRuntime();
      expect(rt.loading, true);
      expect(rt.opened, null);
      expect(rt.progress, 0);
      expect(rt.notes, isEmpty);
      expect(rt.pendingQuote, null);
      expect(rt.foliateSession, null);
      expect(rt.searchQuery, '');
      expect(rt.searchHits, isEmpty);
    });

    test('copyWith only changes the provided fields', () {
      const initial = ReaderRuntime();
      final withProgress = initial.copyWith(progress: 0.42);
      expect(withProgress.progress, 0.42);
      expect(withProgress.loading, initial.loading);
      expect(withProgress.opened, initial.opened);
    });

    test('loaded() transitions out of loading with a document', () {
      const initial = ReaderRuntime();
      final doc = _doc();
      final loaded = initial.loaded(
        document: doc,
        body: 'hello',
        toc: const <TocItem>[],
        progress: 0.1,
      );
      expect(loaded.loading, false);
      expect(loaded.opened, doc);
      expect(loaded.body, 'hello');
      expect(loaded.tocItems, isEmpty);
      expect(loaded.progress, 0.1);
    });

    test('failed() clears loading and keeps notes/foliate untouched', () {
      final rt = ReaderRuntime(notes: [
        ReaderAnnotation(
          id: 'n1',
          note: '',
          createdAt: DateTime.utc(2025, 1, 1),
        ),
      ]);
      final failed = rt.failed();
      expect(failed.loading, false);
      expect(failed.opened, null);
      expect(failed.body, '');
      expect(failed.notes, rt.notes);
    });

    test('withNote appends to the notes list immutably', () {
      const initial = ReaderRuntime();
      final note = ReaderAnnotation(
        id: 'n1',
        note: 'a thought',
        createdAt: DateTime.utc(2025, 1, 1),
      );
      final added = initial.withNote(note);
      expect(initial.notes, isEmpty);
      expect(added.notes, [note]);
    });

    test('withSearchHit replaces the search hit list', () {
      const initial = ReaderRuntime();
      const hits = <SearchResult>[
        SearchResult(
            title: 't',
            excerpt: 'e',
            locator: EpubLocator(href: 'chapter-1', progression: 0)),
      ];
      final withHits = initial.withSearchHits(hits);
      expect(withHits.searchHits, hits);
      expect(initial.searchHits, isEmpty);
    });

    test('closeAllFoliate clears every foliate bridge field', () {
      const rt = ReaderRuntime(
        foliateFragment: 'frag',
        foliateFragmentEpoch: 1,
        foliateScrollQuote: 'q',
        foliateScrollQuoteEpoch: 2,
      );
      final cleared = rt.closeAllFoliate();
      expect(cleared.foliateSession, null);
      expect(cleared.foliateFragment, null);
      expect(cleared.foliateFragmentEpoch, 0);
      expect(cleared.foliateScrollQuote, null);
      expect(cleared.foliateScrollQuoteEpoch, 0);
    });

    test('value equality holds for structurally equal instances', () {
      final a = ReaderRuntime(loading: false, progress: 0.5);
      final b = ReaderRuntime(loading: false, progress: 0.5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
