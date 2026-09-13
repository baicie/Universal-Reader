import 'package:app/core/models.dart';
import 'package:app/core/pdf_document.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pdf_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: '2-0',
    title: 'scan',
    author: '',
    format: DocumentFormat.pdf,
    type: DocumentType.fixedPage,
  );

  // ── baseline ────────────────────────────────────────────────────────────

  test('opens a simple pdf by page text', () async {
    final document = PdfReaderDocument.parse(
      metadata: metadata,
      bytes: minimalPdfBytes(pages: ['first page text', 'second page text']),
    );

    final toc = await document.getToc();
    expect(toc, hasLength(2));
    expect(document.currentChapterText, contains('first page text'));

    await document.goTo(const PdfLocator(page: 2));
    expect(document.currentChapterText, contains('second page text'));
    expect(
      await document.extractText(
        const DocumentRange(
          start: PdfLocator(page: 2),
          end: PdfLocator(page: 2),
        ),
      ),
      contains('second page text'),
    );
  });

  test('unreadable pdf bytes stay corrupt', () {
    expect(
      openReaderDocument(metadata: metadata, bytes: [1, 2, 3]),
      isA<CorruptReaderDocument>(),
    );
  });

  // ── group 1: PdfReaderDocument API ──────────────────────────────────────

  group('PdfReaderDocument API', () {
    test('exposes chapter navigation matching parsed page count', () {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two', 'three']),
      );

      expect(document.chapterIndex, 0);
      expect(document.chapterCount, 3);
      expect(document.currentChapterText, contains('one'));
    });

    test('currentPage clamps pageIndex out of range', () {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two']),
      );

      document.pageIndex = 99;
      expect(document.currentPage.page, 2);
      expect(document.currentPage.text, contains('two'));
    });

    test('currentLocator returns PdfLocator for the current page', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two']),
      );
      await document.goTo(const PdfLocator(page: 2));

      final locator = await document.currentLocator();
      expect(locator, isA<PdfLocator>());
      expect((locator as PdfLocator).page, 2);
    });

    test('locatorForProgress maps to a real page index', () {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two', 'three', 'four']),
      );

      // floor(0.25 * 4) = 1 -> page 2; floor(0.5 * 4) = 2 -> page 3.
      expect((document.locatorForProgress(0.25) as PdfLocator).page, 2);
      expect((document.locatorForProgress(0.5) as PdfLocator).page, 3);
      expect((document.locatorForProgress(0.75) as PdfLocator).page, 4);
    });

    test('locatorForProgress caps at the second-to-last page', () {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two', 'three']),
      );

      // clamp(0, 0.999) * 3 = 2.997, floor = 2 -> page 3.
      final locator = document.locatorForProgress(1.0);
      expect((locator as PdfLocator).page, 3);
    });

    test('locatorForProgress clamps values above 1 to second-to-last page', () {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two']),
      );

      // clamp(2.5, 0, 0.999) = 0.999; floor(0.999 * 2) = 1 -> page 2.
      final locator = document.locatorForProgress(2.5);
      expect((locator as PdfLocator).page, 2);
    });

    test('goTo navigates by PdfLocator', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two', 'three']),
      );

      await document.goTo(const PdfLocator(page: 3));
      expect(document.chapterIndex, 2);
      expect(document.currentChapterText, contains('three'));
    });

    test('goTo ignores an unknown PdfLocator page', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two']),
      );

      final initial = document.chapterIndex;
      await document.goTo(const PdfLocator(page: 99));
      expect(document.chapterIndex, initial);
    });

    test('goTo by TextLocator maps offset to a page', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['first body', 'second body']),
      );

      final secondOffset = document.parsed.fullText.indexOf('second body');
      await document.goTo(TextLocator(offset: secondOffset));
      expect(document.chapterIndex, 1);
      expect(document.currentChapterText, contains('second body'));
    });

    test('goTo by TextLocator at last page stays on the last page', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['a', 'b']),
      );

      await document.goTo(TextLocator(offset: document.parsed.fullText.length));
      expect(document.chapterIndex, 1);
    });

    test('goTo ignores Locator types it does not understand', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two']),
      );

      final initial = document.chapterIndex;
      await document.goTo(const EpubLocator(href: 'whatever'));
      await document.goTo(const ComicLocator(page: 1));
      expect(document.chapterIndex, initial);
    });

    test('extractText with PdfLocator range joins pages', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(
          pages: ['page a text', 'page b text', 'page c text'],
        ),
      );

      final text = await document.extractText(
        const DocumentRange(
          start: PdfLocator(page: 1),
          end: PdfLocator(page: 2),
        ),
      );
      expect(text, contains('page a text'));
      expect(text, contains('page b text'));
      expect(text, isNot(contains('page c text')));
    });

    test('extractText with PdfLocator range crossing full document', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two']),
      );

      final text = await document.extractText(
        const DocumentRange(
          start: PdfLocator(page: 1),
          end: PdfLocator(page: 99),
        ),
      );
      expect(text, contains('one'));
      expect(text, contains('two'));
    });

    test(
      'extractText with PdfLocator end point only returns from start',
      () async {
        final document = PdfReaderDocument.parse(
          metadata: metadata,
          bytes: minimalPdfBytes(pages: ['one', 'two']),
        );

        final text = await document.extractText(
          const DocumentRange(
            start: PdfLocator(page: 1),
            end: TextLocator(offset: 0),
          ),
        );
        // The mixed PdfLocator/TextLocator range picks the document tail end as
        // the upper bound, so both pages are included.
        expect(text, contains('one'));
        expect(text, contains('two'));
      },
    );

    test('extractText with TextLocator range returns substring', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['alpha body', 'beta body']),
      );

      final start = document.parsed.fullText.indexOf('alpha');
      final end = document.parsed.fullText.indexOf('alpha') + 'alpha'.length;
      final text = await document.extractText(
        DocumentRange(
          start: TextLocator(offset: start),
          end: TextLocator(offset: end),
        ),
      );
      expect(text, equals('alpha'));
    });

    test('extractText with TextLocator end beyond length clamps', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['short']),
      );

      final text = await document.extractText(
        const DocumentRange(
          start: TextLocator(offset: 0),
          end: TextLocator(offset: 99999),
        ),
      );
      expect(text, isNotNull);
      expect(text, contains('short'));
    });

    test('extractText with offset at end returns empty string', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['short']),
      );

      final text = await document.extractText(
        const DocumentRange(
          start: TextLocator(offset: 9999),
          end: TextLocator(offset: 99999),
        ),
      );
      expect(text, equals(''));
    });

    test('progress returns 0 for single-page PDFs', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['only page']),
      );

      expect(await document.progress.first, equals(0));
    });

    test('progress reflects current page index over page count', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['a', 'b', 'c', 'd']),
      );

      await document.goTo(const PdfLocator(page: 3));
      expect(await document.progress.first, closeTo(2 / 3, 0.01));
    });

    test('progress stays within [0,1]', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['a', 'b', 'c']),
      );

      await document.goTo(const PdfLocator(page: 1));
      expect(await document.progress.first, greaterThanOrEqualTo(0));
      expect(await document.progress.first, lessThanOrEqualTo(1));
    });

    test('search returns one result per matching page', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(
          pages: ['alpha content', 'beta content', 'alpha again'],
        ),
      );

      final results = await document.search('alpha');
      expect(results, hasLength(2));
      expect(results.every((r) => r.locator is PdfLocator), isTrue);
      expect(
        results.map((r) => (r.locator as PdfLocator).page).toList(),
        equals([1, 3]),
      );
    });

    test('search returns empty list when query has no matches', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one', 'two']),
      );

      final results = await document.search('zzz-not-here');
      expect(results, isEmpty);
    });

    test('search returns empty list for empty query', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one']),
      );

      final results = await document.search('');
      expect(results, isEmpty);
    });

    test('search result carries metadata title', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata.copyWith(title: 'My Book'),
        bytes: minimalPdfBytes(pages: ['contains needle']),
      );

      final results = await document.search('needle');
      expect(results.first.title, equals('My Book'));
    });

    test(
      'getToc emits one TocItem per page with the page number as title',
      () async {
        final document = PdfReaderDocument.parse(
          metadata: metadata,
          bytes: minimalPdfBytes(pages: ['one', 'two', 'three']),
        );

        final toc = await document.getToc();
        expect(toc, hasLength(3));
        expect(toc.map((item) => item.title).toList(), equals(['1', '2', '3']));
        expect(toc.first.children, isEmpty);
      },
    );

    test('truncated is always false', () {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['one']),
      );

      expect(document.truncated, isFalse);
    });
  });

  // ── group 2: PDF edge cases ─────────────────────────────────────────────

  group('PDF edge cases', () {
    test('single-page PDF parses without per-page split logic', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['lonely']),
      );

      expect(document.chapterCount, 1);
      expect(document.currentChapterText, contains('lonely'));
    });

    test('perPage split path joins multiple strings into one page', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(
          pages: ['one'],
          stringsPerPage: [
            ['one-a', 'one-b', 'one-c'],
          ],
        ),
      );

      expect(document.chapterCount, 1);
      expect(document.currentChapterText, contains('one-a'));
      expect(document.currentChapterText, contains('one-b'));
      expect(document.currentChapterText, contains('one-c'));
    });

    test(
      'multi-string pages distribute across pages when 1:1 ratio fails',
      () async {
        final document = PdfReaderDocument.parse(
          metadata: metadata,
          bytes: minimalPdfBytes(
            pages: ['p1', 'p2'],
            stringsPerPage: [
              ['a', 'b', 'c'],
              ['d', 'e', 'f'],
            ],
          ),
        );

        expect(document.chapterCount, 2);
        // 6 strings / 2 pages => 3 per page.
        expect(document.currentChapterText, contains('a'));
        expect(document.currentChapterText, contains('b'));
        expect(document.currentChapterText, contains('c'));
        await document.goTo(const PdfLocator(page: 2));
        expect(document.currentChapterText, contains('d'));
        expect(document.currentChapterText, contains('e'));
        expect(document.currentChapterText, contains('f'));
      },
    );

    test('PDF escape sequences are unescaped in parsed text', () async {
      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: minimalPdfBytes(pages: ['line1\nline2\twith\\slash and(paren)']),
      );

      final text = document.currentChapterText;
      expect(text, contains('line1\nline2'));
      expect(text, contains('\twith'));
      expect(text, contains('\\slash'));
      expect(text, contains('(paren)'));
    });

    test('pages with only whitespace strings are corrupt', () {
      expect(
        () => PdfReaderDocument.parse(
          metadata: metadata,
          bytes: minimalPdfBytes(pages: ['   ']),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('zero pages of content is corrupt', () {
      expect(
        () => parsePdf([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x31]),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ── group 3: PDF parse / sniff ──────────────────────────────────────────

  group('PDF parse and sniff', () {
    test('rejects bytes without the %PDF- header', () {
      expect(
        () => parsePdf(const [0x47, 0x49, 0x46, 0x38]),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects empty bytes', () {
      expect(() => parsePdf(const []), throwsA(isA<FormatException>()));
    });

    test('rejects bytes too short for a header', () {
      expect(
        () => parsePdf(const [0x25, 0x50, 0x44]),
        throwsA(isA<FormatException>()),
      );
    });

    test('header is case-sensitive (lowercase magic is rejected)', () {
      expect(
        () => parsePdf(const [0x25, 0x70, 0x64, 0x66, 0x2D, 0x31]),
        throwsA(isA<FormatException>()),
      );
    });

    test('leading whitespace bytes are skipped before the magic check', () {
      final raw = minimalPdfBytes(pages: ['after leading space']);
      final padded = pdfBytesWithLeadingWhitespace(raw);

      final document = PdfReaderDocument.parse(
        metadata: metadata,
        bytes: padded,
      );
      expect(document.currentChapterText, contains('after leading space'));
    });

    test('Tj operators without surrounding parentheses are ignored', () {
      final bare = StringBuffer('%PDF-1.1\n');
      bare.writeln('1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj');
      bare.writeln('2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj');
      bare.writeln('3 0 obj << /Type /Page /Parent 2 0 R >> endobj');
      bare.writeln('%%EOF');

      expect(
        () => parsePdf(bare.toString().codeUnits),
        throwsA(isA<FormatException>()),
      );
    });

    test('non-Tj parentheses do not produce strings', () {
      final raw = StringBuffer('%PDF-1.1\n');
      raw.writeln('1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj');
      raw.writeln('2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj');
      raw.writeln('3 0 obj << /Type /Page /Parent 2 0 R >> endobj');
      raw.writeln('not a Tj operator');
      raw.writeln('%%EOF');

      expect(
        () => parsePdf(raw.toString().codeUnits),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
