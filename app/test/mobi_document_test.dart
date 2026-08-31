import 'package:app/core/epub_document.dart';
import 'package:app/core/mobi_document.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'mobi-1',
    title: 'Local',
    author: 'Local',
    format: DocumentFormat.mobi,
    type: DocumentType.reflow,
  );

  test('opens a zip-based azw3 as an epub spine', () {
    final document = MobiReaderDocument.parse(
      metadata: metadata.copyWith(format: DocumentFormat.azw3),
      bytes: minimalEpubBytes(firstBody: 'hello from azw3'),
    );
    expect(document.currentChapterText, contains('hello from azw3'));
    expect(document.currentChapterHtml, contains('hello from azw3'));
  });

  test('extracts a readable run from a raw mobi payload', () {
    final bytes = [
      ...List<int>.filled(80, 0),
      ...'hello from mobi and more text for the engine'.codeUnits,
    ];
    final document = MobiReaderDocument.parse(metadata: metadata, bytes: bytes);
    expect(document.currentChapterText, contains('hello from mobi'));
  });

  test('empty mobi bytes are corrupt', () {
    expect(
      () =>
          MobiReaderDocument.parse(metadata: metadata, bytes: const [0, 1, 2]),
      throwsA(isA<FormatException>()),
    );
  });

  group('MobiReaderDocument API', () {
    test('provides chapter navigation', () {
      final bytes = [
        ...List<int>.filled(80, 0),
        ...'first chapter with enough text to pass the threshold'.codeUnits,
      ];
      final document =
          MobiReaderDocument.parse(metadata: metadata, bytes: bytes);

      expect(document.chapterIndex, 0);
      expect(document.chapterCount, 1);
      expect(document.currentChapterHref, 'text');
      expect(document.currentChapterTitle, 'Local');
    });

    test('locatorForProgress maps to chapter', () {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'chapter one'),
      );

      final locator = document.locatorForProgress(0.5);
      expect(locator, isA<EpubLocator>());
      expect((locator as EpubLocator).progression, 0.5);
    });

    test('currentLocator returns current chapter locator', () async {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'chapter'),
      );

      final locator = await document.currentLocator();
      expect(locator, isA<EpubLocator>());
    });

    test('extractText returns full text', () async {
      final bytes = [
        ...List<int>.filled(80, 0),
        ...'full text content for extraction test'.codeUnits,
      ];
      final document =
          MobiReaderDocument.parse(metadata: metadata, bytes: bytes);

      final text = await document.extractText(
        DocumentRange(
          start: const EpubLocator(href: 'text'),
          end: const EpubLocator(href: 'text'),
        ),
      );
      expect(text, contains('full text content'));
    });

    test('goTo navigates to chapter by href', () async {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'first', secondBody: 'second'),
      );

      expect(document.chapterIndex, 0);
      await document.goTo(EpubLocator(href: document.chapters[1].href));
      expect(document.chapterIndex, 1);
    });

    test('goTo ignores unknown href', () async {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'content'),
      );

      final initialIndex = document.chapterIndex;
      await document.goTo(const EpubLocator(href: 'unknown'));
      expect(document.chapterIndex, initialIndex);
    });

    test('progress emits normalized chapter progress', () async {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'first', secondBody: 'second'),
      );

      final progressValue = await document.progress.first;
      expect(progressValue, isA<double>());
      expect(progressValue, greaterThanOrEqualTo(0));
      expect(progressValue, lessThanOrEqualTo(1));
    });

    test('progress returns 0 for single chapter', () async {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'only chapter'),
      );

      expect(await document.progress.first, 0);
    });

    test('search finds matching chapters', () async {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'needle in haystack'),
      );

      final results = await document.search('needle');
      expect(results, hasLength(1));
      expect(results.first.excerpt, contains('needle'));
    });

    test('search returns empty for no matches', () async {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'content'),
      );

      final results = await document.search('notfound');
      expect(results, isEmpty);
    });

    test('search returns empty for empty query', () async {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'content'),
      );

      final results = await document.search('');
      expect(results, isEmpty);
    });

    test('getToc returns all chapters', () async {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'chapter one'),
      );

      final toc = await document.getToc();
      expect(toc, isNotEmpty);
      expect(toc.first.title, isNotEmpty);
      expect(toc.first.locator, isA<EpubLocator>());
    });

    test('truncated is always false', () {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'content'),
      );

      expect(document.truncated, isFalse);
    });

    test('currentChapter clamps index to valid range', () {
      final document = MobiReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(firstBody: 'content'),
      );

      document.sectionIndex = 999;
      final chapter = document.currentChapter;
      expect(chapter, isNotNull);
      expect(chapter.text, isNotEmpty);
    });
  });

  group('MOBI format edge cases', () {
    test('finds zip offset in middle of file', () {
      final zipSignature = [0x50, 0x4B, 0x03, 0x04];
      final bytes = [
        ...List<int>.filled(100, 0xFF),
        ...zipSignature,
        ...minimalEpubBytes(firstBody: 'embedded epub'),
      ];
      final document =
          MobiReaderDocument.parse(metadata: metadata, bytes: bytes);

      // Should successfully parse as EPUB (no exception thrown)
      expect(document.chapterCount, greaterThan(0));
      expect(document.currentChapterText, isNotEmpty);
    });

    test('filters out non-readable runs', () {
      final bytes = [
        ...List<int>.filled(80, 0),
        ...List<int>.filled(30, 0x01), // binary junk
        ...'This is valid English text that should be extracted'.codeUnits,
      ];
      final document =
          MobiReaderDocument.parse(metadata: metadata, bytes: bytes);

      expect(document.currentChapterText, contains('valid English text'));
    });

    test('escapes HTML entities in plain text conversion', () {
      final bytes = [
        ...List<int>.filled(80, 0),
        ...'text with <tags> & special "chars"'.codeUnits,
      ];
      final document =
          MobiReaderDocument.parse(metadata: metadata, bytes: bytes);

      expect(document.currentChapterHtml, contains('&lt;'));
      expect(document.currentChapterHtml, contains('&gt;'));
      expect(document.currentChapterHtml, contains('&amp;'));
    });
  });
}
