import 'dart:convert';

import 'package:app/core/epub_document.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: '1-0',
    title: 'imported',
    author: '',
    format: DocumentFormat.epub,
    type: DocumentType.reflow,
  );

  test('opens a minimal epub with toc, excerpt, and chapter jump', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    final toc = await document.getToc();
    expect(toc.map((item) => item.title), ['第一章', '第二章']);
    expect(document.currentChapterText, contains('hello from epub'));
    expect(
      await document.extractText(
        const DocumentRange(
          start: TextLocator(offset: 0),
          end: TextLocator(offset: 4000),
        ),
      ),
      contains('hello from epub'),
    );

    await document.goTo(const EpubLocator(href: 'OEBPS/ch2.xhtml'));
    expect(document.currentChapterText, contains('second chapter text'));
    expect(await document.currentLocator(), isA<EpubLocator>());
  });

  test('search stays inside the current epub', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(secondBody: 'unique-needle-in-chapter-two'),
    );

    final hits = await document.search('unique-needle-in-chapter-two');
    expect(hits, hasLength(1));
    expect(hits.single.locator, isA<EpubLocator>());
    expect(hits.single.excerpt, contains('unique-needle-in-chapter-two'));
  });

  test('corrupt epub bytes are corrupt, not a sample or empty book', () {
    expect(
      () => parseEpub(utf8.encode('not-a-zip')),
      throwsA(isA<FormatException>()),
    );
    expect(
      openReaderDocument(metadata: metadata, bytes: [1, 2, 3]),
      isA<CorruptReaderDocument>(),
    );
  });

  test('openReaderDocument uses the epub adapter for imported bytes', () {
    final opened = openReaderDocument(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );
    expect(opened, isA<EpubReaderDocument>());
  });

  test('chapter html inlines images and keeps class names', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: illustratedEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('class="caption"'));
    expect(document.currentChapterHtml, contains('data:image/png'));
    expect(document.currentChapterHtml, contains('font-style: italic'));
    expect(
      document.currentChapterHtml,
      isNot(contains('src="images/spot.png"')),
    );
    expect(document.currentChapterHtml, isNot(contains('href="styles.css"')));
  });

  test('a missing chapter image stays missing', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: illustratedEpubBytes(includeImage: false),
    );
    expect(document.currentChapterHtml, contains('src="images/spot.png"'));
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });
}
