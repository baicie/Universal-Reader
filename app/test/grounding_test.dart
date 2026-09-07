import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/features/tools/ai/grounding.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedDocument implements ReaderDocument {
  _FixedDocument({
    required this.id,
    required this.title,
    required this.author,
    required this.extractedText,
    required this.locator,
    this.searchHits = const [],
  });

  final String id;
  final String title;
  final String author;
  final String extractedText;
  final Locator locator;
  final List<SearchResult> searchHits;

  @override
  DocumentMetadata get metadata => DocumentMetadata(
        id: id,
        title: title,
        author: author,
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      );

  Future<String?> Function(DocumentRange range)? extractTextOverride;

  @override
  Future<String?> extractText(DocumentRange range) async {
    final override = extractTextOverride;
    if (override != null) return override(range);
    return extractedText;
  }

  @override
  Future<Locator> currentLocator() async => locator;

  @override
  Future<List<SearchResult>> search(String query) async => searchHits;

  @override
  Future<List<TocItem>> getToc() async => const [];
  @override
  Future<void> goTo(Locator locator) async {}
  @override
  Stream<double> get progress => const Stream<double>.empty();
}

AppLocalizations _stubL10n(Locale locale) {
  return lookupAppLocalizations(locale);
}

void main() {
  group('DocumentGrounding.fromDocument', () {
    test('truncates excerpts longer than maxExcerptLength', () async {
      final doc = _FixedDocument(
        id: 'big',
        title: 'T',
        author: 'A',
        extractedText: 'a' * 5000,
        locator: const EpubLocator(href: 'ch-1', progression: 0.5),
      );
      const grounding = DocumentGrounding(maxExcerptLength: 16);
      final context = await grounding.fromDocument(doc);
      expect(context.excerpt, 'a' * 16);
      expect(context.locatorLabel, contains('ch-1'));
    });

    test('returns an empty excerpt when extractText yields null', () async {
      final doc = _FixedDocument(
        id: 'empty',
        title: 'T',
        author: 'A',
        extractedText: '',
        locator: const EpubLocator(href: 'ch-1'),
      );
      const grounding = DocumentGrounding();
      final context = await grounding.fromDocument(doc);
      expect(context.excerpt, '');
      expect(context.documentId, 'empty');
    });

    test('uses the supplied locator without calling currentLocator',
        () async {
      final doc = _FixedDocument(
        id: 'book',
        title: 'T',
        author: 'A',
        extractedText: 'hi',
        locator: const EpubLocator(href: 'unused'),
      );
      const explicit = EpubLocator(href: 'supplied', progression: 0.25);
      const grounding = DocumentGrounding();
      final context =
          await grounding.fromDocument(doc, locator: explicit);
      expect(context.locatorLabel, contains('supplied'));
    });

    test('falls back to English-style label without a l10n object',
        () async {
      final doc = _FixedDocument(
        id: 'pdf',
        title: 'T',
        author: 'A',
        extractedText: 'hi',
        locator: const PdfLocator(page: 4),
      );
      const grounding = DocumentGrounding();
      final context = await grounding.fromDocument(doc);
      expect(context.locatorLabel, '第 4 页');
    });
  });

  group('DocumentGrounding.fromSearch', () {
    test('returns the document fallback when no hits match', () async {
      final doc = _FixedDocument(
        id: 'no-hit',
        title: 'T',
        author: 'A',
        extractedText: 'body text',
        locator: const EpubLocator(href: 'ch-1', progression: 0.5),
      );
      const grounding = DocumentGrounding();
      final result = await grounding.fromSearch(doc, query: 'needle');
      expect(result.hits, isEmpty);
      expect(result.context.excerpt, contains('body text'));
    });

    test('combines search hits and clips at maxExcerptLength', () async {
      final doc = _FixedDocument(
        id: 'matches',
        title: 'T',
        author: 'A',
        extractedText: '',
        locator: const EpubLocator(href: 'ch-1', progression: 0.5),
        searchHits: [
          SearchResult(
            title: 'T',
            excerpt: 'a' * 1500,
            locator: const EpubLocator(href: 'ch-1', progression: 0.1),
          ),
          SearchResult(
            title: 'T',
            excerpt: 'b' * 1500,
            locator: const EpubLocator(href: 'ch-1', progression: 0.5),
          ),
        ],
      );
      const grounding = DocumentGrounding(maxExcerptLength: 32);
      final result = await grounding.fromSearch(doc, query: 'hit');
      expect(result.hits, hasLength(2));
      expect(result.context.excerpt.length, 32);
    });
  });

  group('DocumentGrounding.locatorLabel', () {
    test('EpubLocator without progression returns the bare href', () {
      expect(
        DocumentGrounding.locatorLabel(
          const EpubLocator(href: 'chapter-1'),
        ),
        'chapter-1',
      );
    });

    test('TextLocator falls back to a plain offset string', () {
      expect(
        DocumentGrounding.locatorLabel(
          const TextLocator(offset: 42),
        ),
        '偏移 42',
      );
    });

    test('ComicLocator falls back to a plain page label', () {
      expect(
        DocumentGrounding.locatorLabel(
          const ComicLocator(page: 7),
        ),
        '第 7 页',
      );
    });

    test('PdfLocator with l10n uses the localised page label', () {
      final l10n = _stubL10n(const Locale('en'));
      expect(
        DocumentGrounding.locatorLabel(
          const PdfLocator(page: 3),
          l10n: l10n,
        ),
        l10n.pageNumber(3),
      );
    });
  });

  group('DocumentGrounding.fromDocument range handling', () {
    test('passes the supplied range through to extractText', () async {
      DocumentRange? observed;
      final doc = _FixedDocument(
        id: 'range',
        title: 'T',
        author: 'A',
        extractedText: 'sliced body',
        locator: const EpubLocator(href: 'ch-1'),
      );
      doc.extractTextOverride = (range) async {
        observed = range;
        return 'sliced body';
      };
      const range = DocumentRange(
        start: TextLocator(offset: 100),
        end: TextLocator(offset: 200),
      );
      const grounding = DocumentGrounding();
      await grounding.fromDocument(doc, range: range);
      expect(observed, isNotNull);
      expect(observed!.start, const TextLocator(offset: 100));
      expect(observed!.end, const TextLocator(offset: 200));
    });

    test('throws when extractText fails instead of swallowing the error',
        () async {
      final doc = _FixedDocument(
        id: 'broken',
        title: 'T',
        author: 'A',
        extractedText: '',
        locator: const EpubLocator(href: 'ch-1'),
      )..extractTextOverride = (range) async {
        throw StateError('extract failed');
      };
      const grounding = DocumentGrounding();
      await expectLater(
        grounding.fromDocument(doc),
        throwsA(isA<Object>()),
      );
    });
  });

  group('DocumentGrounding.fromSearch bounds', () {
    test('caps the joined excerpt at five search hits', () async {
      final doc = _FixedDocument(
        id: 'many',
        title: 'T',
        author: 'A',
        extractedText: '',
        locator: const EpubLocator(href: 'ch-1'),
        searchHits: [
          for (var i = 0; i < 8; i++)
            SearchResult(
              title: 'T',
              excerpt: 'hit-$i ' + ('x' * 200),
              locator: EpubLocator(href: 'h-$i', progression: i / 8),
            ),
        ],
      );
      const grounding = DocumentGrounding(maxExcerptLength: 5000);
      final result = await grounding.fromSearch(doc, query: 'hit');
      expect(result.hits, hasLength(8));
      final occurrences = RegExp(r'h-\d').allMatches(result.context.excerpt);
      expect(occurrences.length, 5);
      expect(
        result.context.excerpt.contains('h-5'),
        isFalse,
        reason: 'sixth hit must be dropped from the joined excerpt',
      );
    });

    test('falls back to the document body when the trimmed query is empty',
        () async {
      final doc = _FixedDocument(
        id: 'blank-query',
        title: 'T',
        author: 'A',
        extractedText: 'fallback body',
        locator: const EpubLocator(href: 'ch-1'),
      );
      const grounding = DocumentGrounding();
      final result = await grounding.fromSearch(doc, query: '   ');
      expect(result.hits, isEmpty);
      expect(result.context.excerpt, contains('fallback body'));
    });
  });

  group('DocumentGrounding.locatorLabel EpubLocator with progression', () {
    test('renders progression as a rounded percent', () {
      expect(
        DocumentGrounding.locatorLabel(
          const EpubLocator(href: 'chapter-1', progression: 0.5),
        ),
        'chapter-1 · 50%',
      );
    });

    test('rounds progression to the nearest integer percent', () {
      expect(
        DocumentGrounding.locatorLabel(
          const EpubLocator(href: 'ch', progression: 0.1234),
        ),
        'ch · 12%',
      );
    });
  });

  group('DocumentGrounding.fromSearch with l10n', () {
    test('uses the localised label inside the joined excerpt', () async {
      final doc = _FixedDocument(
        id: 'pdf-search',
        title: 'T',
        author: 'A',
        extractedText: '',
        locator: const PdfLocator(page: 1),
        searchHits: [
          SearchResult(
            title: 'T',
            excerpt: 'a needle',
            locator: const PdfLocator(page: 9),
          ),
        ],
      );
      final l10n = _stubL10n(const Locale('en'));
      const grounding = DocumentGrounding();
      final result = await grounding.fromSearch(
        doc,
        query: 'needle',
        l10n: l10n,
      );
      expect(result.context.excerpt, contains(l10n.pageNumber(9)));
      expect(result.context.locatorLabel, l10n.pageNumber(9));
    });
  });
}