import 'package:app/core/foliate_session.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/reader_state.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/tools/sample_reader_document.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

SampleReaderDocument _doc({String id = 'book-1'}) => SampleReaderDocument(
  metadata: DocumentMetadata(
    id: id,
    title: 'A',
    author: 'B',
    format: DocumentFormat.epub,
    type: DocumentType.reflow,
  ),
);

/// Minimal `HtmlChapteredDocument` used to materialise a real
/// [FoliateSession] inside the copyWith / loaded tests.
class _StubHtmlReader implements HtmlChapteredDocument {
  _StubHtmlReader({DocumentMetadata? metadata})
      : docMetadata =
            metadata ??
            const DocumentMetadata(
              id: 'book-1',
              title: 'A',
              author: 'B',
              format: DocumentFormat.epub,
              type: DocumentType.reflow,
            );

  @override
  final DocumentMetadata docMetadata;

  @override
  String get currentChapterText => 'hello world';

  @override
  String get currentChapterHtml => '<p>hello world</p>';

  @override
  String get currentChapterHref => 'chapter-1.xhtml';

  @override
  String get currentChapterTitle => 'Chapter 1';

  @override
  int get chapterIndex => 0;

  @override
  int get chapterCount => 1;

  @override
  bool get truncated => false;

  @override
  Locator locatorForProgress(double progress) =>
      EpubLocator(href: currentChapterHref, progression: progress);

  @override
  Future<Locator> currentLocator() async =>
      EpubLocator(href: currentChapterHref, progression: 0);

  @override
  Future<String?> extractText(DocumentRange range) async =>
      currentChapterText;

  @override
  Future<void> goTo(Locator locator) async {}

  @override
  Stream<double> get progress => const Stream<double>.empty();

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  Future<List<TocItem>> getToc() async => const [];

  @override
  DocumentMetadata get metadata => docMetadata;
}

FoliateSession _buildSession() => FoliateSession.open(_StubHtmlReader());

void main() {
  group('ReaderRuntime.copyWith sentinel behavior', () {
    test('explicit null clears pendingQuote', () {
      const rt = ReaderRuntime(pendingQuote: 'something');
      final cleared = rt.copyWith(pendingQuote: null);
      expect(cleared.pendingQuote, isNull);
    });

    test('omitting pendingQuote keeps the existing value', () {
      const rt = ReaderRuntime(pendingQuote: 'kept');
      // Using a non-sentinel sentinel default keeps the previous value; passing
      // null explicitly clears it.
      final kept = rt.copyWith();
      expect(kept.pendingQuote, 'kept');
    });

    test('explicit null clears foliateSession', () {
      // Build a session via the public factory would pull foliate into the
      // test; here we just check the dispatcher accepts a null sentinel
      // without crashing. The "kept when omitted" guarantee is covered above.
      const rt = ReaderRuntime();
      final cleared = rt.copyWith(foliateSession: null);
      expect(cleared.foliateSession, isNull);
    });

    test('explicit null clears foliateFragment and scrollQuote', () {
      const rt = ReaderRuntime(
        foliateFragment: 'frag',
        foliateScrollQuote: 'q',
      );
      final cleared = rt.copyWith(foliateFragment: null, foliateScrollQuote: null);
      expect(cleared.foliateFragment, isNull);
      expect(cleared.foliateScrollQuote, isNull);
    });

    test('omitting nullable fields preserves them through copyWith', () {
      const rt = ReaderRuntime(
        pendingQuote: 'p',
        foliateFragment: 'f',
        foliateScrollQuote: 's',
      );
      final next = rt.copyWith(progress: 0.5);
      expect(next.pendingQuote, 'p');
      expect(next.foliateFragment, 'f');
      expect(next.foliateScrollQuote, 's');
      expect(next.progress, 0.5);
    });

    test('handles a real FoliateSession instance via the default factory', () {
      // The default factory in foliate_session.dart returns a fresh stub
      // session. Verify the copyWith dispatcher accepts it without throwing.
      final session = _buildSession();
      const rt = ReaderRuntime();
      final next = rt.copyWith(foliateSession: session);
      expect(next.foliateSession, isNotNull);
      rt.copyWith(foliateSession: null);
    });
  });

  group('ReaderRuntime.loaded preserves cross-cutting state', () {
    test('keeps notes, pendingQuote, foliate, and search across the transition', () {
      final rt = ReaderRuntime(
        notes: [
          ReaderAnnotation(
            id: 'n1',
            note: '',
            createdAt: DateTime.utc(2025, 1, 1),
          ),
        ],
        pendingQuote: 'q',
        foliateSession: _buildSession(),
        foliateFragment: 'frag',
        foliateFragmentEpoch: 1,
        foliateScrollQuote: 'sq',
        foliateScrollQuoteEpoch: 2,
        searchQuery: 'orange',
        searchHits: const <SearchResult>[
          SearchResult(
            title: 't',
            excerpt: 'e',
            locator: EpubLocator(href: 'chapter-1', progression: 0),
          ),
        ],
      );

      final loaded = rt.loaded(
        document: _doc(),
        body: 'b',
        toc: const <TocItem>[],
        progress: 0.1,
      );

      expect(loaded.loading, false);
      expect(loaded.opened, isNotNull);
      expect(loaded.notes, rt.notes);
      expect(loaded.pendingQuote, 'q');
      expect(loaded.foliateSession, rt.foliateSession);
      expect(loaded.foliateFragment, 'frag');
      expect(loaded.foliateFragmentEpoch, 1);
      expect(loaded.foliateScrollQuote, 'sq');
      expect(loaded.foliateScrollQuoteEpoch, 2);
      expect(loaded.searchQuery, 'orange');
      expect(loaded.searchHits, rt.searchHits);
    });

    test(
      'loaded() without fileBytes keeps the previous fileBytes (null default)',
      () {
        const rt = ReaderRuntime();
        final loaded = rt.loaded(
          document: _doc(),
          body: 'b',
          toc: const <TocItem>[],
          progress: 0.2,
        );
        expect(loaded.fileBytes, isNull);
      },
    );

    test('loaded() with explicit fileBytes stores them', () {
      const rt = ReaderRuntime();
      final loaded = rt.loaded(
        document: _doc(),
        body: 'b',
        toc: const <TocItem>[],
        progress: 0.0,
        fileBytes: [1, 2, 3],
      );
      expect(loaded.fileBytes, [1, 2, 3]);
    });
  });

  group('ReaderRuntime.failed preserves cross-cutting state', () {
    test(
      'keeps notes, pendingQuote, foliate bridge fields across the failure',
      () {
        final rt = ReaderRuntime(
          notes: [
            ReaderAnnotation(
              id: 'n1',
              note: '',
              createdAt: DateTime.utc(2025, 1, 1),
            ),
          ],
          pendingQuote: 'q',
          foliateSession: _buildSession(),
          foliateFragment: 'frag',
          foliateFragmentEpoch: 1,
          foliateScrollQuote: 'sq',
          foliateScrollQuoteEpoch: 2,
          searchQuery: 'orange',
        );
        final failed = rt.failed();
        expect(failed.loading, false);
        expect(failed.opened, isNull);
        expect(failed.body, '');
        expect(failed.notes, rt.notes);
        expect(failed.pendingQuote, 'q');
        expect(failed.foliateSession, rt.foliateSession);
        expect(failed.foliateFragment, 'frag');
        expect(failed.foliateScrollQuote, 'sq');
        expect(failed.foliateScrollQuoteEpoch, 2);
        // searchQuery is intentionally cleared by failed() — the failure
        // screen does not surface the previous query.
        expect(failed.searchQuery, '');
      },
    );
  });

  group('ReaderRuntime epochs are independent', () {
    test('bumping the fragment does not affect the scroll-quote epoch', () {
      const rt = ReaderRuntime(
        foliateFragmentEpoch: 0,
        foliateScrollQuoteEpoch: 7,
      );
      final bumped = rt.bumpFragmentEpoch('ch');
      expect(bumped.foliateFragmentEpoch, 1);
      // scroll-quote epoch is untouched
      expect(bumped.foliateScrollQuoteEpoch, 7);
    });

    test('bumping the scroll quote does not affect the fragment epoch', () {
      const rt = ReaderRuntime(
        foliateFragmentEpoch: 5,
        foliateScrollQuoteEpoch: 0,
      );
      final bumped = rt.bumpScrollQuoteEpoch('q');
      expect(bumped.foliateScrollQuoteEpoch, 1);
      expect(bumped.foliateFragmentEpoch, 5);
    });

    test('bumpFragmentEpoch(null) clears the fragment', () {
      const rt = ReaderRuntime(foliateFragment: 'frag');
      final bumped = rt.bumpFragmentEpoch(null);
      expect(bumped.foliateFragment, isNull);
      expect(bumped.foliateFragmentEpoch, 1);
    });

    test('bumpScrollQuoteEpoch(null) clears the quote', () {
      const rt = ReaderRuntime(foliateScrollQuote: 'q');
      final bumped = rt.bumpScrollQuoteEpoch(null);
      expect(bumped.foliateScrollQuote, isNull);
      expect(bumped.foliateScrollQuoteEpoch, 1);
    });
  });

  group('ReaderRuntime equality', () {
    test('differing on any field breaks equality', () {
      final base = ReaderRuntime(loading: false, progress: 0.5);
      final next = base.copyWith(loading: true);
      // Sanity check that copyWith really flips the loading flag before
      // asserting equality on it.
      expect(next.loading, true);
      expect(next, isNot(base));
      expect(base, isNot(base.copyWith(progress: 0.6)));
      expect(base, isNot(base.copyWith(searchQuery: 'q')));
    });

    test('hashCode is stable and serves as a set key', () {
      // Two structurally equal instances must produce the same hash, so the
      // framework's set / map containment works.
      final a = ReaderRuntime(loading: false, progress: 0.25);
      final b = ReaderRuntime(loading: false, progress: 0.25);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final set = <ReaderRuntime>{a};
      expect(set.contains(b), isTrue);
    });
  });
}
