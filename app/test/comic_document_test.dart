import 'package:app/core/comic_document.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'comic-1',
    title: 'Pages',
    author: 'A',
    format: DocumentFormat.cbz,
    type: DocumentType.comic,
  );

  test('opens a cbz as ordered image pages', () {
    final bytes = zipNamedFiles({
      'page-02.png': tinyPngBytes(),
      'page-01.png': tinyPngBytes(),
      'readme.txt': [1, 2, 3],
    });
    final document = ComicReaderDocument.parse(
      metadata: metadata,
      bytes: bytes,
    );
    expect(document.chapterCount, 2);
    expect(document.currentPage.name, 'page-01.png');
    expect(document.currentPage.bytes, tinyPngBytes());
  });

  test('cbr that is not a zip is corrupt', () {
    expect(
      () => ComicReaderDocument.parse(
        metadata: metadata.copyWith(format: DocumentFormat.cbr),
        bytes: [0, 1, 2, 3, 4],
      ),
      throwsA(isA<FormatException>()),
    );
  });

  group('ComicReaderDocument API', () {
    test('provides page navigation properties', () {
      final bytes = zipNamedFiles({
        'page-01.jpg': tinyPngBytes(),
        'page-02.jpg': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      expect(document.chapterIndex, 0);
      expect(document.chapterCount, 2);
      expect(document.currentChapterText, 'page-01.jpg');
    });

    test('locatorForProgress maps to page', () {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'page-02.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final locator = document.locatorForProgress(0.5);
      expect(locator, isA<ComicLocator>());
      expect((locator as ComicLocator).page, greaterThan(0));
    });

    test('locatorForProgress clamps to valid range', () {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final locator0 = document.locatorForProgress(0.0);
      expect((locator0 as ComicLocator).page, 1);

      final locator1 = document.locatorForProgress(1.5);
      expect((locator1 as ComicLocator).page, 1);
    });

    test('currentLocator returns current page locator', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final locator = await document.currentLocator();
      expect(locator, isA<ComicLocator>());
      expect((locator as ComicLocator).page, 1);
    });

    test('extractText returns current page name', () async {
      final bytes = zipNamedFiles({
        'cover.jpg': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final text = await document.extractText(
        DocumentRange(
          start: const ComicLocator(page: 1),
          end: const ComicLocator(page: 1),
        ),
      );
      expect(text, 'cover.jpg');
    });

    test('goTo navigates to page by ComicLocator', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'page-02.png': tinyPngBytes(),
        'page-03.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      expect(document.pageIndex, 0);
      await document.goTo(const ComicLocator(page: 3));
      expect(document.pageIndex, 2);
    });

    test('goTo navigates to page by TextLocator offset', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'page-02.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      await document.goTo(const TextLocator(offset: 1));
      expect(document.pageIndex, 1);
    });

    test('goTo clamps page to valid range', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      await document.goTo(const ComicLocator(page: 999));
      expect(document.pageIndex, 0);

      await document.goTo(const ComicLocator(page: 0));
      expect(document.pageIndex, 0);
    });

    test('goTo ignores unsupported locator types', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final initialIndex = document.pageIndex;
      await document.goTo(const EpubLocator(href: 'unknown'));
      expect(document.pageIndex, initialIndex);
    });

    test('progress emits normalized page progress', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'page-02.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final progressValue = await document.progress.first;
      expect(progressValue, isA<double>());
      expect(progressValue, greaterThanOrEqualTo(0));
      expect(progressValue, lessThanOrEqualTo(1));
    });

    test('progress returns 0 for single page', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      expect(await document.progress.first, 0);
    });

    test('search finds matching pages by name', () async {
      final bytes = zipNamedFiles({
        'chapter01-page01.jpg': tinyPngBytes(),
        'chapter02-page01.jpg': tinyPngBytes(),
        'cover.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final results = await document.search('chapter01');
      expect(results, hasLength(1));
      expect(results.first.title, 'chapter01-page01.jpg');
      expect(results.first.locator, isA<ComicLocator>());
    });

    test('search is case-insensitive', () async {
      final bytes = zipNamedFiles({
        'PageOne.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final results = await document.search('pageone');
      expect(results, hasLength(1));
    });

    test('search returns empty for no matches', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final results = await document.search('notfound');
      expect(results, isEmpty);
    });

    test('search returns empty for empty query', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final results = await document.search('');
      expect(results, isEmpty);
    });

    test('getToc returns all pages', () async {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'page-02.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      final toc = await document.getToc();
      expect(toc, hasLength(2));
      expect(toc[0].title, 'page-01.png');
      expect(toc[0].locator, isA<ComicLocator>());
      expect((toc[0].locator as ComicLocator).page, 1);
      expect(toc[1].title, 'page-02.png');
      expect(toc[1].locator, isA<ComicLocator>());
      expect((toc[1].locator as ComicLocator).page, 2);
    });

    test('truncated is always false', () {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      expect(document.truncated, isFalse);
    });

    test('currentPage clamps index to valid range', () {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      document.pageIndex = 999;
      final page = document.currentPage;
      expect(page.name, 'page-01.png');
    });
  });

  group('Comic format edge cases', () {
    test('sorts pages case-insensitively', () {
      final bytes = zipNamedFiles({
        'Page-02.png': tinyPngBytes(),
        'page-01.png': tinyPngBytes(),
        'PAGE-03.PNG': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      expect(document.pages[0].name, 'page-01.png');
      expect(document.pages[1].name, 'Page-02.png');
      expect(document.pages[2].name, 'PAGE-03.PNG');
    });

    test('handles nested directories with backslashes', () {
      final bytes = zipNamedFiles({
        r'subdir\page-01.jpg': tinyPngBytes(),
        'page-02.jpg': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      expect(document.pages[0].name, 'page-01.jpg');
      expect(document.pages[1].name, 'page-02.jpg');
    });

    test('filters out non-image files', () {
      final bytes = zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'readme.txt': [1, 2, 3],
        'metadata.xml': [4, 5, 6],
        'page-02.jpg': tinyPngBytes(),
      });
      final document = ComicReaderDocument.parse(
        metadata: metadata,
        bytes: bytes,
      );

      expect(document.chapterCount, 2);
      expect(document.pages.every((p) => p.name.endsWith('.png') || p.name.endsWith('.jpg')), isTrue);
    });

    test('empty archive is corrupt', () {
      final bytes = zipNamedFiles({
        'readme.txt': [1, 2, 3],
      });

      expect(
        () => ComicReaderDocument.parse(metadata: metadata, bytes: bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('archive with only directories is corrupt', () {
      final bytes = zipNamedFiles({});

      expect(
        () => ComicReaderDocument.parse(metadata: metadata, bytes: bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
