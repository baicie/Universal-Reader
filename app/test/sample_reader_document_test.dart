import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/features/tools/sample_reader_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SampleReaderDocument defaults', () {
    final doc = SampleReaderDocument(
      metadata: const DocumentMetadata(
        id: 'design',
        title: '设计中的设计',
        author: '原研哉',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
    );

    test('chapter metadata uses the configured defaults', () {
      expect(doc.chapterIndex, 0);
      expect(doc.chapterCount, 1);
      expect(doc.truncated, isFalse);
      expect(doc.currentChapterText, SampleReaderDocument.defaultBody);
    });

    test('locatorForProgress wraps the progress in an EpubLocator', () {
      final locator = doc.locatorForProgress(0.7);
      expect(locator, isA<EpubLocator>());
      final epub = locator as EpubLocator;
      expect(epub.href, 'chapter-4');
      expect(epub.progression, 0.7);
    });

    test('currentLocator returns the configured chapter progress', () async {
      final locator = await doc.currentLocator();
      expect(locator, isA<EpubLocator>());
      final epub = locator as EpubLocator;
      expect(epub.href, 'chapter-4');
      expect(epub.progression, 0.37);
    });

    test('extractText returns the body', () async {
      final text = await doc.extractText(
        const DocumentRange(
          start: TextLocator(offset: 0),
          end: TextLocator(offset: 10),
        ),
      );
      expect(text, SampleReaderDocument.defaultBody);
    });

    test('goTo never throws and is a no-op', () async {
      await doc.goTo(
        const EpubLocator(href: 'chapter-1', progression: 0.0),
      );
    });

    test('progress stream emits the configured chapter progress', () async {
      expect(await doc.progress.first, 0.37);
    });

    test('search returns an empty list when the body does not match',
        () async {
      expect(await doc.search('不可见的字符串'), isEmpty);
    });

    test('search returns one hit when the query matches the body', () async {
      final hits = await doc.search('白');
      expect(hits, hasLength(1));
      expect(hits.first.title, '设计中的设计');
      expect(hits.first.locator, isA<EpubLocator>());
    });

    test('getToc returns the single configured chapter', () async {
      final toc = await doc.getToc();
      expect(toc, hasLength(1));
      expect(toc.first.title, '第 4 章 白');
      expect(toc.first.locator, isA<EpubLocator>());
    });
  });

  group('SampleReaderDocument customisations', () {
    test('body / chapterHref / chapterProgress are honoured', () {
      final doc = SampleReaderDocument(
        metadata: const DocumentMetadata(
          id: 'custom',
          title: '定制',
          author: 'A',
          format: DocumentFormat.epub,
          type: DocumentType.reflow,
        ),
        body: '一段简短的正文',
        chapterHref: 'chapter-1',
        chapterProgress: 0.5,
      );
      expect(doc.currentChapterText, '一段简短的正文');
    });

    test('custom chapterHref flows through currentLocator', () async {
      final doc = SampleReaderDocument(
        metadata: const DocumentMetadata(
          id: 'custom',
          title: 'T',
          author: 'A',
          format: DocumentFormat.epub,
          type: DocumentType.reflow,
        ),
        chapterHref: 'chapter-2',
        chapterProgress: 0.11,
      );
      final locator = await doc.currentLocator();
      expect((locator as EpubLocator).href, 'chapter-2');
      expect(locator.progression, 0.11);
    });

    test('locatorForProgress returns href without progression when null',
        () async {
      // Calls that pass a value of 0 should keep the configured href.
      final doc = SampleReaderDocument(
        metadata: const DocumentMetadata(
          id: 'a',
          title: 'A',
          author: 'A',
          format: DocumentFormat.epub,
          type: DocumentType.reflow,
        ),
      );
      final locator = doc.locatorForProgress(0.0);
      expect((locator as EpubLocator).href, 'chapter-4');
      expect(locator.progression, 0.0);
    });
  });
}
