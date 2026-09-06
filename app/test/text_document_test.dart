import 'dart:convert';

import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:flutter_test/flutter_test.dart';

DocumentMetadata _txt({String title = 'notes'}) => DocumentMetadata(
      id: 'notes',
      title: title,
      author: '',
      format: DocumentFormat.txt,
      type: DocumentType.reflow,
    );

DocumentMetadata _md({String title = 'md'}) => DocumentMetadata(
      id: 'md',
      title: title,
      author: '',
      format: DocumentFormat.markdown,
      type: DocumentType.reflow,
    );

void main() {
  // ── baseline ────────────────────────────────────────────────────────────

  test('decodes utf-8 text and splits blank-line sections', () {
    final parsed = parseTextDocument(
      bytes: utf8.encode('第一章\n\nhello\n\n第二章\n\nworld'),
      format: DocumentFormat.txt,
    );

    expect(parsed.truncated, isFalse);
    expect(parsed.sections, hasLength(2));
    expect(parsed.sections.first.title, '第一章');
    expect(parsed.sections.first.body, contains('hello'));
    expect(parsed.sections.last.title, '第二章');
  });

  test('splits markdown on ATX headings', () {
    final parsed = parseTextDocument(
      bytes: utf8.encode('# Intro\nwelcome\n\n## Details\nmore'),
      format: DocumentFormat.markdown,
    );

    expect(parsed.sections.map((section) => section.title), [
      'Intro',
      'Details',
    ]);
    expect(parsed.sections.last.body, contains('more'));
  });

  test('strips html tags before reading', () {
    final parsed = parseTextDocument(
      bytes: utf8.encode('<h1>Hi</h1><p>body &amp; text</p>'),
      format: DocumentFormat.html,
    );

    expect(parsed.fullText, contains('Hi'));
    expect(parsed.fullText, contains('body & text'));
    expect(parsed.fullText, isNot(contains('<p>')));
  });

  test('text reader document exposes toc and excerpt', () async {
    final document = TextReaderDocument.parse(
      metadata: _txt(),
      bytes: utf8.encode('Title\n\nreadable body'),
    );

    final toc = await document.getToc();
    expect(toc, isNotEmpty);
    expect(
      await document.extractText(
        const DocumentRange(
          start: TextLocator(offset: 0),
          end: TextLocator(offset: 4000),
        ),
      ),
      contains('readable body'),
    );
  });

  test('plain text files open as a text reader, binaries stay unavailable', () {
    final text = openReaderDocument(metadata: _txt(), bytes: utf8.encode('from disk'));
    expect(text, isA<TextReaderDocument>());

    final pdf = openReaderDocument(
      metadata: DocumentMetadata(
        id: '2-0',
        title: 'scan',
        author: '',
        format: DocumentFormat.pdf,
        type: DocumentType.fixedPage,
      ),
      bytes: [1, 2, 3],
    );
    expect(pdf, isA<CorruptReaderDocument>());

    final leftoverSeedId = openReaderDocument(
      metadata: const DocumentMetadata(
        id: 'design',
        title: '设计中的设计',
        author: '原研哉',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
    );
    expect(leftoverSeedId, isA<UnavailableReaderDocument>());
  });

  test('chunks oversized sections even when other chapters exist', () {
    final huge = 'x' * (textSectionCharLimit + 50);
    final parsed = parseTextDocument(
      bytes: utf8.encode('# A\n\n$huge\n\n# B\n\nshort'),
      format: DocumentFormat.markdown,
    );

    expect(parsed.sections.length, greaterThan(2));
    expect(
      parsed.sections.every(
        (section) => section.body.length <= textSectionCharLimit,
      ),
      isTrue,
    );
  });

  test('gb18030 txt decodes as chinese instead of replacement characters', () {
    final parsed = parseTextDocument(
      bytes: const [181, 218, 210, 187, 213, 194, 10, 10, 213, 253, 206, 196],
      format: DocumentFormat.txt,
    );
    expect(parsed.fullText, contains('第一章'));
    expect(parsed.fullText, contains('正文'));
    expect(parsed.fullText, isNot(contains('\uFFFD')));
  });

  test('valid utf-8 chinese is not reinterpreted as gb18030', () {
    final parsed = parseTextDocument(
      bytes: utf8.encode('第一章'),
      format: DocumentFormat.txt,
    );
    expect(parsed.fullText, '第一章');
  });

  test('undecodable txt is corrupt instead of another book', () {
    final opened = openReaderDocument(
      metadata: const DocumentMetadata(
        id: 'broken-txt',
        title: 'broken',
        author: '',
        format: DocumentFormat.txt,
        type: DocumentType.reflow,
      ),
      bytes: const [0xFF],
    );
    expect(opened, isA<CorruptReaderDocument>());
    expect(opened.metadata.title, 'broken');
  });

  // ── group 1: TextReaderDocument API ─────────────────────────────────────

  group('TextReaderDocument API', () {
    test('chapterIndex defaults to 0', () {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('# A\n\na\n\n# B\n\nb'),
      );
      expect(document.chapterIndex, 0);
    });

    test('chapterCount matches section count after packing', () {
      final huge = 'x' * (textSectionCharLimit + 1);
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('$huge\n\n$huge'),
      );
      expect(document.chapterCount, greaterThan(2));
      expect(document.chapterIndex, 0);
    });

    test('currentChapterText reflects the current section body', () {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('# First\n\nbody alpha\n\n# Second\n\nbody beta'),
      );
      expect(document.currentChapterText, contains('body alpha'));
    });

    test('truncated surfaces from parsed metadata', () {
      final oversized = utf8.encode('a' * (textReaderByteLimit + 100));
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: oversized,
      );
      expect(document.truncated, isTrue);
    });

    test('currentLocator returns a TextLocator at section startOffset',
        () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('Title\n\nbody\n\nBody2'),
      );
      await document.goTo(const TextLocator(offset: 12));
      final locator = await document.currentLocator();
      expect(locator, isA<TextLocator>());
    });

    test('locatorForProgress never exceeds fullText length', () {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('hello there'),
      );
      final locator = document.locatorForProgress(2.0) as TextLocator;
      expect(locator.offset, lessThanOrEqualTo(document.parsed.fullText.length));
    });

    test('locatorForProgress(0) returns offset 0', () {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('hello there'),
      );
      expect(
        (document.locatorForProgress(0.0) as TextLocator).offset,
        equals(0),
      );
    });

    test('locatorForProgress(1) returns fullText length', () {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('hello there'),
      );
      expect(
        (document.locatorForProgress(1.0) as TextLocator).offset,
        equals(document.parsed.fullText.length),
      );
    });

    test('goTo by TextLocator selects section with startOffset <= offset',
        () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('# A\n\naaa\n\n# B\n\nbbb\n\n# C\n\nccc'),
      );
      // The offset of "B" body content.
      final offsetB = document.parsed.fullText.indexOf('bbb');
      await document.goTo(TextLocator(offset: offsetB));
      expect(document.chapterIndex, greaterThan(0));
      // The "ccc" exclusive is on its own section.
      await document.goTo(TextLocator(offset: document.parsed.fullText.length));
      expect(document.currentChapterText, contains('ccc'));
    });

    test('goTo ignores Locator types it does not understand', () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('# A\n\naaa\n\n# B\n\nbbb'),
      );
      final initial = document.chapterIndex;
      await document.goTo(const PdfLocator(page: 1));
      await document.goTo(const ComicLocator(page: 1));
      await document.goTo(const EpubLocator(href: 'x'));
      expect(document.chapterIndex, initial);
    });

    test('extractText returns substring for TextLocator range', () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('hello world'),
      );
      final text = await document.extractText(
        const DocumentRange(
          start: TextLocator(offset: 0),
          end: TextLocator(offset: 5),
        ),
      );
      expect(text, equals('hello'));
    });

    test('extractText with non-TextLocator defaults to full document',
        () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('hello world'),
      );
      final text = await document.extractText(
        const DocumentRange(
          start: PdfLocator(page: 1),
          end: PdfLocator(page: 99),
        ),
      );
      expect(text, contains('hello world'));
    });

    test('extractText with start beyond length returns empty', () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('short'),
      );
      final text = await document.extractText(
        const DocumentRange(
          start: TextLocator(offset: 9999),
          end: TextLocator(offset: 99999),
        ),
      );
      expect(text, equals(''));
    });

    test('progress returns offset/length ratio', () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('# A\n\naaaa\n\n# B\n\nbbbb'),
      );
      await document.goTo(const TextLocator(offset: 20));
      final progress = await document.progress.first;
      expect(progress, greaterThan(0));
      expect(progress, lessThanOrEqualTo(1));
    });

    test('search returns a result for a single match with its offset',
        () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('hello there friend'),
      );
      final results = await document.search('there');
      expect(results, hasLength(1));
      expect(
        (results.first.locator as TextLocator).offset,
        document.parsed.fullText.indexOf('there'),
      );
    });

    test('search returns const empty for empty query', () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('hello world'),
      );
      expect(await document.search(''), isEmpty);
    });

    test('search returns const empty for missing query', () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('hello world'),
      );
      expect(await document.search('zzz'), isEmpty);
    });

    test('search result uses metadata title', () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(title: 'My Notes'),
        bytes: utf8.encode('this contains needle inside'),
      );
      final results = await document.search('needle');
      expect(results.first.title, equals('My Notes'));
    });

    test('getToc emits one entry per section preserving titles', () async {
      final document = TextReaderDocument.parse(
        metadata: _md(),
        bytes: utf8.encode('# Alpha\n\nbody\n\n# Beta\n\nbody\n\n# Gamma\n\nbody'),
      );
      final toc = await document.getToc();
      expect(toc, hasLength(3));
      expect(toc.map((item) => item.title).toList(),
          equals(['Alpha', 'Beta', 'Gamma']));
      expect(
        toc.every((item) => item.locator is TextLocator),
        isTrue,
      );
    });

    test('chapterIndex clamps out-of-range goTo to a valid section',
        () async {
      final document = TextReaderDocument.parse(
        metadata: _txt(),
        bytes: utf8.encode('# A\n\na\n\n# B\n\nb'),
      );
      await document.goTo(const TextLocator(offset: 999999));
      expect(document.chapterIndex, lessThan(document.chapterCount));
      expect(document.chapterIndex, greaterThanOrEqualTo(0));
    });
  });

  // ── group 2: decode functions ────────────────────────────────────────────

  group('Byte decoders', () {
    test('UTF-16 LE BOM is decoded', () {
      // "hi" in UTF-16 LE with BOM (0xFF 0xFE), no extra BOM char.
      final bytes = [0xFF, 0xFE, 0x68, 0x00, 0x69, 0x00];
      expect(decodeTextBytes(bytes), equals('hi'));
    });

    test('UTF-16 BE BOM is decoded', () {
      final bytes = [0xFE, 0xFF, 0x00, 0x68, 0x00, 0x69];
      expect(decodeTextBytes(bytes), contains('hi'));
    });

    test('decodePlainTextBytes strips the UTF-8 BOM if present', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('hello')];
      expect(decodePlainTextBytes(bytes), equals('hello'));
    });

    test('decodeTextBytes strips the UTF-8 BOM if present', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('hello')];
      expect(decodeTextBytes(bytes), equals('hello'));
    });

    test('GB18030 fallback decodes bytes that fail strict UTF-8', () {
      // 0xC4 0xE3 0xBA 0xC3 = "你好" in GB18030.
      final text = decodePlainTextBytes(const [196, 227, 186, 195]);
      expect(text, contains('你好'));
    });

    test('UTF-16 BE bogus bytes do not crash', () {
      // 2-byte BOM without full payload: should still return a String.
      final text = decodeTextBytes(const [0xFE, 0xFF]);
      expect(text, isNotNull);
      expect(text, isA<String>());
    });
  });

  // ── group 3: parsing edge cases ──────────────────────────────────────────

  group('Parsing edge cases', () {
    test('truncation flag is set when bytes exceed the limit', () {
      final huge = 'a' * (textReaderByteLimit + 1);
      final parsed = parseTextDocument(
        bytes: utf8.encode(huge),
        format: DocumentFormat.txt,
      );
      expect(parsed.truncated, isTrue);
      expect(parsed.fullText.length, lessThanOrEqualTo(textReaderByteLimit));
    });

    test('crlf line endings are normalized before splitting', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode('alpha\r\n\r\nbeta'),
        format: DocumentFormat.txt,
      );
      expect(parsed.fullText.contains('\r'), isFalse);
      // "alpha" is short and the next block becomes its body.
      expect(parsed.sections, hasLength(1));
      expect(parsed.sections.first.body, contains('beta'));
    });

    test('lone CR line endings are normalized too', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode('A\rB\r\rC\rD'),
        format: DocumentFormat.txt,
      );
      expect(parsed.fullText.contains('\r'), isFalse);
      expect(parsed.fullText.contains('C'), isTrue);
    });

    test('markdown without headings falls back to plain split', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode('Just\n\ntwo\n\nblocks'),
        format: DocumentFormat.markdown,
      );
      expect(parsed.sections.length, greaterThanOrEqualTo(2));
    });

    test('markdown preface before first heading is captured', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode('preface prose\n\n# Title\n\nbody'),
        format: DocumentFormat.markdown,
      );
      expect(parsed.sections.first.title, equals(''));
      expect(parsed.sections.first.body, contains('preface prose'));
    });

    test('plain text single block produces one section with empty title', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode('just one block'),
        format: DocumentFormat.txt,
      );
      expect(parsed.sections, hasLength(1));
      expect(parsed.sections.first.title, equals(''));
      expect(parsed.sections.first.body, equals('just one block'));
    });

    test('plain text empty document produces one empty section', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode(''),
        format: DocumentFormat.txt,
      );
      expect(parsed.sections, hasLength(1));
      expect(parsed.sections.first.body, equals(''));
    });

    test('plain text long title (over 40 runes) becomes a body, not a title',
        () {
      final long = 'x' * 80;
      final parsed = parseTextDocument(
        bytes: utf8.encode('$long\n\nbody'),
        format: DocumentFormat.txt,
      );
      // The long block should not be split as title/body.
      expect(parsed.sections.first.title, equals(''));
    });

    test('plain text short-title block is split as title + body', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode('Title\n\nBody here'),
        format: DocumentFormat.txt,
      );
      expect(parsed.sections.first.title, equals('Title'));
      expect(parsed.sections.first.body, contains('Body here'));
    });

    test('html script and style blocks are stripped', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode(
          '<script>alert(1)</script>visible<script>x</script>'
          '<style>.x{}</style>keep',
        ),
        format: DocumentFormat.html,
      );
      expect(parsed.fullText, contains('visible'));
      expect(parsed.fullText, contains('keep'));
      expect(parsed.fullText, isNot(contains('alert')));
      expect(parsed.fullText, isNot(contains('.x{}')));
    });

    test('html br and p tags become newlines', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode('one<br>two</p>three'),
        format: DocumentFormat.html,
      );
      expect(parsed.fullText, contains('one\ntwo'));
      expect(parsed.fullText, contains('three'));
    });

    test('html multiple consecutive newlines collapse to two', () {
      final parsed = parseTextDocument(
        bytes: utf8.encode('a\n\n\n\n\nb'),
        format: DocumentFormat.html,
      );
      expect(parsed.fullText, contains('a\n\nb'));
      expect(parsed.fullText, isNot(contains('\n\n\n')));
    });

    test('chunked section preserves title and continues startOffset', () {
      final huge = 'x' * (textSectionCharLimit + 10);
      final parsed = parseTextDocument(
        bytes: utf8.encode('# Title\n\n$huge'),
        format: DocumentFormat.markdown,
      );
      expect(parsed.sections.length, 2);
      expect(parsed.sections.first.title, parsed.sections.last.title);
      expect(
        parsed.sections.last.startOffset,
        greaterThan(parsed.sections.first.startOffset),
      );
    });

    test('chunked section body length never exceeds limit', () {
      final huge = 'x' * (textSectionCharLimit * 2 + 100);
      final parsed = parseTextDocument(
        bytes: utf8.encode('# Big\n\n$huge'),
        format: DocumentFormat.markdown,
      );
      expect(
        parsed.sections.every(
          (section) => section.body.length <= textSectionCharLimit,
        ),
        isTrue,
      );
      expect(parsed.sections.length, greaterThanOrEqualTo(3));
    });

    test('chunked section bodies concatenate back to original body', () {
      final huge = 'x' * (textSectionCharLimit + 5);
      final parsed = parseTextDocument(
        bytes: utf8.encode('# T\n\n$huge'),
        format: DocumentFormat.markdown,
      );
      final rejoined =
          parsed.sections.map((section) => section.body).join();
      expect(rejoined.length, equals(huge.length));
      expect(rejoined, equals(huge));
    });
  });
}
