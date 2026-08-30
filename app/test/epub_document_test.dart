import 'dart:convert';

import 'package:app/core/epub_document.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';

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
    expect(toc.every((item) => item.children.isEmpty), isTrue);
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

  test('nav nested entries keep a fragment on the current chapter', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: nestedNavEpubBytes(),
    );

    final toc = await document.getToc();
    expect(toc.map((item) => item.title), ['第一章', '第二章']);
    expect(toc.first.children, hasLength(1));
    expect(toc.first.children.single.title, '注释');
    final child = toc.first.children.single.locator;
    expect(child, isA<EpubLocator>());
    expect((child as EpubLocator).fragment, 'note');
    expect((toc.first.locator as EpubLocator).fragment, isNull);
    expect(toc.last.children, isEmpty);
  });

  test('ncx nested navPoints keep fragments on subsections', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: nestedNcxEpubBytes(),
    );

    final toc = await document.getToc();
    expect(toc.map((item) => item.title), ['第一章', '第二章']);
    expect(toc.first.children, hasLength(2));
    expect(toc.first.children.first.title, '第一节');
    expect(toc.first.children.last.title, '第二节');
    final firstChild = toc.first.children.first.locator;
    expect(firstChild, isA<EpubLocator>());
    expect((firstChild as EpubLocator).fragment, 'section1');
    final secondChild = toc.first.children.last.locator;
    expect(secondChild, isA<EpubLocator>());
    expect((secondChild as EpubLocator).fragment, 'section2');
    expect((toc.first.locator as EpubLocator).fragment, isNull);
    expect(toc.last.children, isEmpty);
  });

  test('a missing chapter href stays on the current chapter', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );
    await document.goTo(const EpubLocator(href: 'OEBPS/missing.xhtml'));
    expect(document.currentChapterText, contains('hello from epub'));
    expect(document.currentChapterText, isNot(contains('second chapter text')));
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
    expect(document.currentChapterHtml, contains('src="data:image/png'));
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

  test('chapter html inlines srcset images', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: srcsetEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('data:image/png'));
    expect(document.currentChapterHtml, contains('srcset='));
    expect(document.currentChapterHtml, isNot(contains('images/spot.png')));
  });

  test('a missing srcset image stays missing', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: srcsetEpubBytes(includeImage: false),
    );
    expect(document.currentChapterHtml, contains('images/spot.png'));
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });

  test('a remote srcset is not fetched', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: srcsetEpubBytes(remote: true),
    );
    expect(
      document.currentChapterHtml,
      contains('srcset="https://example.com/spot.png 1x"'),
    );
  });

  test('chapter html inlines svg image href', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: svgImageEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('data:image/png'));
    expect(document.currentChapterHtml, contains('<image'));
    expect(document.currentChapterHtml, isNot(contains('images/spot.png')));
  });

  test('chapter html inlines svg xlink href', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: svgImageEpubBytes(xlink: true),
    );
    expect(document.currentChapterHtml, contains('data:image/png'));
    expect(document.currentChapterHtml, contains('xlink:href='));
    expect(document.currentChapterHtml, isNot(contains('images/spot.png')));
  });

  test('a missing svg image stays missing', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: svgImageEpubBytes(includeImage: false),
    );
    expect(document.currentChapterHtml, contains('href="images/spot.png"'));
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });

  test('a remote svg image is not fetched', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: svgImageEpubBytes(remote: true),
    );
    expect(
      document.currentChapterHtml,
      contains('href="https://example.com/spot.png"'),
    );
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });

  test('chapter html inlines object data images', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: objectImageEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('data:image/png'));
    expect(document.currentChapterHtml, contains('<object'));
    expect(document.currentChapterHtml, isNot(contains('images/spot.png')));
  });

  test('a missing object image stays missing', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: objectImageEpubBytes(includeImage: false),
    );
    expect(document.currentChapterHtml, contains('data="images/spot.png"'));
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });

  test('a remote object image is not fetched', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: objectImageEpubBytes(remote: true),
    );
    expect(
      document.currentChapterHtml,
      contains('data="https://example.invalid/spot.png"'),
    );
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });

  test('chapter html inlines embed src images', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: embedImageEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('data:image/png'));
    expect(document.currentChapterHtml, contains('<embed'));
    expect(document.currentChapterHtml, isNot(contains('images/spot.png')));
  });

  test('a missing embed image stays missing', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: embedImageEpubBytes(includeImage: false),
    );
    expect(document.currentChapterHtml, contains('src="images/spot.png"'));
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });

  test('a remote embed image is not fetched', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: embedImageEpubBytes(remote: true),
    );
    expect(
      document.currentChapterHtml,
      contains('src="https://example.invalid/spot.png"'),
    );
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });

  test('chapter html inlines video poster images', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: videoPosterEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('data:image/png'));
    expect(document.currentChapterHtml, contains('<video'));
    expect(document.currentChapterHtml, contains('src="clip.mp4"'));
    expect(document.currentChapterHtml, isNot(contains('images/spot.png')));
  });

  test('a missing video poster stays missing', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: videoPosterEpubBytes(includeImage: false),
    );
    expect(document.currentChapterHtml, contains('poster="images/spot.png"'));
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });

  test('a remote video poster is not fetched', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: videoPosterEpubBytes(remote: true),
    );
    expect(
      document.currentChapterHtml,
      contains('poster="https://example.invalid/spot.png"'),
    );
    expect(document.currentChapterHtml, isNot(contains('data:image')));
  });

  test('chapter html drops inline scripts and keeps the body', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        firstMarkup: '<script>alert(1)</script><p>kept body</p>',
      ),
    );
    expect(document.currentChapterHtml, isNot(contains('<script')));
    expect(document.currentChapterHtml, isNot(contains('alert(1)')));
    expect(document.currentChapterHtml, contains('kept body'));
    expect(document.currentChapterText, contains('hello from epub'));
    expect(document.currentChapterText, contains('kept body'));
  });

  test('chapter html drops a script src instead of inlining it', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        firstMarkup: '<script src="js/app.js"></script><p>kept body</p>',
        extraFiles: {'OEBPS/js/app.js': utf8.encode('alert(1)')},
      ),
    );
    expect(document.currentChapterHtml, isNot(contains('<script')));
    expect(document.currentChapterHtml, isNot(contains('js/app.js')));
    expect(document.currentChapterHtml, isNot(contains('alert(1)')));
    expect(document.currentChapterHtml, contains('kept body'));
  });

  test('chapter html drops onclick handlers and keeps the body', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        firstMarkup: '<p onclick="alert(1)">kept body</p>',
      ),
    );
    expect(document.currentChapterHtml, isNot(contains('onclick')));
    expect(document.currentChapterHtml, isNot(contains('alert(1)')));
    expect(document.currentChapterHtml, contains('kept body'));
    expect(document.currentChapterText, contains('kept body'));
  });

  test('chapter html drops onerror without dropping the image', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        firstMarkup:
            '<img src="images/spot.png" onerror="alert(1)" alt="spot"/>',
        extraFiles: {'OEBPS/images/spot.png': tinyPngBytes()},
      ),
    );
    expect(document.currentChapterHtml, isNot(contains('onerror')));
    expect(document.currentChapterHtml, isNot(contains('alert(1)')));
    expect(document.currentChapterHtml, contains('src="data:image/png'));
    expect(document.currentChapterHtml, contains('alt="spot"'));
  });

  test('chapter css inlines embedded fonts', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: fontedEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('font-family: Body'));
    expect(document.currentChapterHtml, contains('data:font/ttf'));
    expect(document.currentChapterHtml, isNot(contains('url(fonts/body.ttf)')));
  });

  test('a missing chapter font stays missing', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: fontedEpubBytes(includeFont: false),
    );
    expect(document.currentChapterHtml, contains('url(fonts/body.ttf)'));
    expect(document.currentChapterHtml, isNot(contains('data:font')));
  });

  test('chapter css inlines imported stylesheets', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: importedCssEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('font-family: Body'));
    expect(document.currentChapterHtml, contains('data:font/ttf'));
    expect(
      document.currentChapterHtml,
      isNot(contains('@import url(theme.css)')),
    );
    expect(document.currentChapterHtml, isNot(contains('url(fonts/body.ttf)')));
  });

  test('a missing css import stays missing', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: importedCssEpubBytes(includeImported: false),
    );
    expect(document.currentChapterHtml, contains('@import url(theme.css)'));
    expect(document.currentChapterHtml, isNot(contains('data:font')));
  });

  test('a remote css import is not fetched', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: importedCssEpubBytes(remoteImport: true),
    );
    expect(
      document.currentChapterHtml,
      contains('@import url(https://example.com/theme.css)'),
    );
  });

  test('a circular css import still opens the chapter', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: importedCssEpubBytes(circular: true),
    );
    expect(document.currentChapterHtml, contains('color: red'));
    expect(
      document.currentChapterHtml,
      isNot(contains('@import url(styles.css)')),
    );
  });

  test('imported css urls resolve against the imported file', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: nestedImportedCssEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('data:font/ttf'));
    expect(
      document.currentChapterHtml,
      isNot(contains('url(../fonts/body.ttf)')),
    );
  });
}
