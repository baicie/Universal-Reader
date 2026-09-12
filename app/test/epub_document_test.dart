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

  test('chapter css keeps @import with media query', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: mediaImportCssEpubBytes(),
    );
    expect(document.currentChapterHtml, contains('@import url("print.css") print'));
    expect(document.currentChapterHtml, contains('@import url(\'screen.css\') screen'));
    expect(document.currentChapterHtml, isNot(contains('body { margin: 0; }')));
  });

  test('extractText across two chapters joins with blank lines', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    final text = await document.extractText(
      const DocumentRange(
        start: EpubLocator(href: 'OEBPS/ch1.xhtml'),
        end: EpubLocator(href: 'OEBPS/ch2.xhtml'),
      ),
    );
    expect(text, contains('hello from epub'));
    expect(text, contains('second chapter text'));
    expect(text, contains('\n\n'));
  });

  test('extractText returns empty when either EpubLocator href is unknown',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    expect(
      await document.extractText(
        const DocumentRange(
          start: EpubLocator(href: 'OEBPS/missing.xhtml'),
          end: EpubLocator(href: 'OEBPS/ch2.xhtml'),
        ),
      ),
      '',
    );
    expect(
      await document.extractText(
        const DocumentRange(
          start: EpubLocator(href: 'OEBPS/ch1.xhtml'),
          end: EpubLocator(href: 'OEBPS/missing.xhtml'),
        ),
      ),
      '',
    );
  });

  test('extractText defaults the missing end locator to the last chapter',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    final text = await document.extractText(
      const DocumentRange(
        start: EpubLocator(href: 'OEBPS/ch1.xhtml'),
        end: TextLocator(offset: 1),
      ),
    );
    expect(text, contains('hello from epub'));
    expect(text, contains('second chapter text'));
  });

  test('extractText defaults a missing start locator to the first chapter',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    final text = await document.extractText(
      const DocumentRange(
        start: TextLocator(offset: 0),
        end: EpubLocator(href: 'OEBPS/ch2.xhtml'),
      ),
    );
    expect(text, contains('hello from epub'));
    expect(text, contains('second chapter text'));
  });

  test('extractText returns empty when the text offset is past the end',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    expect(
      await document.extractText(
        const DocumentRange(
          start: TextLocator(offset: 99999999),
          end: TextLocator(offset: 99999999),
        ),
      ),
      '',
    );
  });

  test('extractText clamps a text range past the end of the book', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    final text = await document.extractText(
      const DocumentRange(
        start: TextLocator(offset: 0),
        end: TextLocator(offset: 99999999),
      ),
    );
    expect(text, contains('hello from epub'));
    expect(text, contains('second chapter text'));
  });

  test('extractText falls back to fullText.length when the end locator is '
      'neither Epub nor Text', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    final text = await document.extractText(
      const DocumentRange(
        start: TextLocator(offset: 0),
        end: ComicLocator(page: 1),
      ),
    );
    expect(text, contains('hello from epub'));
    expect(text, contains('second chapter text'));
  });

  test('goTo with a TextLocator jumps to the chapter that owns the offset',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    await document.goTo(TextLocator(offset: 99999999));
    expect(document.currentChapterText, contains('second chapter text'));
  });

  test('goTo with a TextLocator before the first chapter stays at index 0',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    await document.goTo(const EpubLocator(href: 'OEBPS/ch2.xhtml'));
    expect(document.currentChapterText, contains('second chapter text'));

    await document.goTo(TextLocator(offset: -1));
    expect(document.currentChapterText, contains('hello from epub'));
  });

  test('goTo ignores locator types other than Epub or Text', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    await document.goTo(ComicLocator(page: 3));
    expect(document.currentChapterText, contains('hello from epub'));
  });

  test('search reports the metadata title when the chapter has no title',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        firstTitle: '',
        firstBody: 'unique-needle-without-title',
      ),
    );

    final hits = await document.search('unique-needle-without-title');
    expect(hits, hasLength(1));
    expect(hits.single.title, isNotEmpty);
  });

  test('locatorForProgress at 1.0 clamps to the chapter before the last',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    final lastLocator = document.locatorForProgress(0.999) as EpubLocator;
    final overflowLocator = document.locatorForProgress(1.0) as EpubLocator;
    expect(lastLocator.href, overflowLocator.href);
    expect(overflowLocator.progression, 1.0);
  });

  test('currentLocator divides by chapters - 1 when there is more than one',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );
    document.sectionIndex = 1;
    final locator = await document.currentLocator();
    expect(locator, isA<EpubLocator>());
    expect((locator as EpubLocator).progression, 1.0);
  });

  test('currentLocator returns the first chapter href when sectionIndex is 0',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );
    expect(document.sectionIndex, 0);
    final locator = await document.currentLocator();
    expect(locator, isA<EpubLocator>());
    expect((locator as EpubLocator).progression, 0.0);
    expect(locator.href, document.currentChapterHref);
  });

  test('truncated flag stays false when the chapter fits in the byte limit',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );
    expect(document.truncated, isFalse);
  });

  test('long chapters are split into sections and only the first keeps html',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        firstBody: 'a' * 9000,
        secondBody: 'b' * 9000,
      ),
    );
    // Sanity: each chapter text really exceeds the pack threshold (4000).
    final chapters = document.parsed.chapters;
    expect(chapters, hasLength(6));
    // Pack sizes: 4000 / 4000 / (remainder). The remainder keeps the
    // tail of the original body so the last section ends with the last
    // character of `firstBody`.
    expect(chapters[0].text.length, 4000);
    expect(chapters[1].text.length, 4000);
    expect(
      chapters[2].text.length,
      lessThanOrEqualTo(textSectionCharLimit.toInt()),
    );
    expect(chapters[2].text.length, greaterThan(0));
    final firstSections =
        chapters.where((chapter) => chapter.href == 'oebps/ch1.xhtml').toList();
    expect(firstSections, hasLength(3));
    expect(firstSections.first.html, isNotEmpty,
        reason: 'first section keeps the original html');
    expect(
      firstSections.skip(1).every((chapter) => chapter.html.isEmpty),
      isTrue,
      reason: 'follow-up sections drop html to avoid duplicate inlining',
    );
    // Sub-sections concatenate back to the original body byte-for-byte.
    // The body includes the h1 title line that stripHtml preserves, so
    // the total length is slightly larger than the raw `firstBody` string.
    final reassembled = firstSections.map((c) => c.text).join();
    expect(reassembled.length, greaterThan(9000));
    expect(reassembled, endsWith('a' * 9000));
    expect(reassembled, contains('第一章'));
  });

  test('a nav file without the toc marker falls back to spine flat toc',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        extraFiles: {
          'OEBPS/nav.xhtml': utf8.encode(
            '<?xml version="1.0"?>'
            '<html xmlns="http://www.w3.org/1999/xhtml">'
            '<body><nav><ol></ol></nav></body>'
            '</html>',
          ),
        },
      ),
    );
    final toc = await document.getToc();
    // The nav never matched, so each chapter is flattened with its own title.
    expect(toc, hasLength(2));
    expect(toc.first.title, '第一章');
    expect(toc.last.title, '第二章');
  });

  test('a nav anchor without href is skipped instead of producing an entry',
      () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        extraFiles: {
          'OEBPS/nav.xhtml': utf8.encode('''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a>no href</a></li>
        <li><a href="ch1.xhtml">第一章</a></li>
        <li><a href="ch2.xhtml">第二章</a></li>
      </ol>
    </nav>
  </body>
</html>
'''),
        },
      ),
    );
    final toc = await document.getToc();
    expect(toc.map((item) => item.title), ['第一章', '第二章']);
  });

  test('nav with type declared via the epub namespace still resolves toc',
      () async {
    // The fixture only annotates `type` via `xmlns:type`; the bare and
    // `epub:type` attributes are absent, so only the namespace branch of
    // `_isTocNav` should match.
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        extraFiles: {
          'OEBPS/nav.xhtml': utf8.encode('''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav xmlns:type="http://www.idpf.org/2007/ops" type="toc">
      <ol>
        <li><a href="ch1.xhtml">第一章</a></li>
        <li><a href="ch2.xhtml">第二章</a></li>
      </ol>
    </nav>
  </body>
</html>
'''),
        },
      ),
    );
    final toc = await document.getToc();
    expect(toc.map((item) => item.title), ['第一章', '第二章']);
  });

  test(
    'nav type declared only via the epub namespace prefix still resolves toc',
    () async {
      // The previous fixture declared both `xmlns:type` and the bare
      // `type="toc"` attribute, which short-circuited the lookup before
      // the namespace branch. Here the only marker is `epub:type="toc"`,
      // so `_isTocNav` must walk past the bare-attribute and the
      // unprefixed namespace check before matching.
      final document = EpubReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(
          extraFiles: {
            'OEBPS/nav.xhtml': utf8.encode('''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="ch1.xhtml">第一章</a></li>
        <li><a href="ch2.xhtml">第二章</a></li>
      </ol>
    </nav>
  </body>
</html>
'''),
          },
        ),
      );
      final toc = await document.getToc();
      expect(toc.map((item) => item.title), ['第一章', '第二章']);
    },
  );

  test(
    'nav marker is only present on a non-toc nav so the resolver falls '
    'back to the document root',
    () async {
      // The pre-filter accepts any xhtml whose source text mentions
      // `epub:type="toc"`; the actual `<nav>` carrying that marker has
      // no `<ol>` inside, so the resolver must walk past `tocNav == null`
      // and start scanning from `nav.rootElement` instead.
      final document = EpubReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(
          extraFiles: {
            'OEBPS/nav.xhtml': utf8.encode('''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc"></nav>
    <nav>
      <ol>
        <li><a href="ch1.xhtml">第一章</a></li>
        <li><a href="ch2.xhtml">第二章</a></li>
      </ol>
    </nav>
  </body>
</html>
'''),
          },
        ),
      );
      final toc = await document.getToc();
      expect(toc.map((item) => item.title), ['第一章', '第二章']);
    },
  );

  test(
    'nav marker only appears in prose so the resolver falls back to the root',
    () async {
      // The pre-filter looks at the raw text for `epub:type="toc"`; if
      // that string only shows up inside a `<desc>` element, the
      // `_isTocNav` selector will not match any `<nav>` and the resolver
      // has to fall back to scanning from `nav.rootElement` to find the
      // unordered `<ol>`.
      final document = EpubReaderDocument.parse(
        metadata: metadata,
        bytes: minimalEpubBytes(
          extraFiles: {
            'OEBPS/nav.xhtml': utf8.encode('''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav><desc>epub:type="toc"</desc></nav>
    <ol>
      <li><a href="ch1.xhtml">第一章</a></li>
      <li><a href="ch2.xhtml">第二章</a></li>
    </ol>
  </body>
</html>
'''),
          },
        ),
      );
      final toc = await document.getToc();
      expect(toc.map((item) => item.title), ['第一章', '第二章']);
    },
  );

  test(
    'a nav item without an anchor still drills into its nested list',
    () async {
      // The outer `<li>` carries only a `<span>` so the resolver walks
      // past the missing anchor and recurses into the inner `<ol>` to
      // recover the actual entries.
      final document = EpubReaderDocument.parse(
        metadata: metadata,
        bytes: headerOnlyNestedNavEpubBytes(),
      );
      final toc = await document.getToc();
      expect(toc.map((item) => item.title), ['注释', '第二章']);
    },
  );

  test('a chapter with no matching nav item falls back to a plain title',
      () async {
    // The spine declares ch1, ch2, ch3 but nav only lists ch1 and ch2; ch3
    // should still resolve via the fallback branch in `_tocItemForChapter`.
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        extraFiles: {
          'OEBPS/content.opf': utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Fixture Book</dc:title>
    <dc:creator>Fixture Author</dc:creator>
    <dc:language>zh</dc:language>
    <dc:identifier id="bookid">urn:uuid:fixture</dc:identifier>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch3" href="ch3.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
    <itemref idref="ch3"/>
  </spine>
</package>
'''),
          'OEBPS/ch3.xhtml': utf8.encode(
            '<?xml version="1.0"?>'
            '<html xmlns="http://www.w3.org/1999/xhtml">'
            '<body><h1>第三章</h1><p>third chapter body</p></body>'
            '</html>',
          ),
          'OEBPS/nav.xhtml': utf8.encode('''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="ch1.xhtml">第一章</a></li>
        <li><a href="ch2.xhtml">第二章</a></li>
      </ol>
    </nav>
  </body>
</html>
'''),
        },
      ),
    );
    final toc = await document.getToc();
    expect(toc, hasLength(3));
    expect(toc.last.title, '第三章');
  });

  test('progress emits the chapter offset over total length', () async {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );

    final stream = document.progress;
    expect(stream, isA<Stream<double>>());
    final value = await stream.first;
    expect(value, 0.0);

    // After jumping past chapter 1, progress should reflect the new
    // chapter's start offset rather than 0.
    await document.goTo(const EpubLocator(href: 'OEBPS/ch2.xhtml'));
    final after = await document.progress.first;
    expect(after, greaterThan(0.0));
    expect(after, lessThanOrEqualTo(1.0));
  });

  test('a chapter longer than the byte limit gets truncated and flagged',
      () {
    // The byte limit is 2 MiB, so a body of ~3 MiB has to be sliced in
    // half. The truncated flag must be set and the surviving text length
    // must equal the configured cap exactly.
    final longBody = 'a' * (3 * 1024 * 1024);
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        firstBody: longBody,
        firstTitle: '',
      ),
    );
    expect(document.truncated, isTrue);
    expect(document.parsed.fullText.length, epubTextByteLimit);
  });

  test('chapterIndex, chapterCount, and chapter title getters surface values',
      () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(),
    );
    expect(document.chapterCount, document.parsed.chapters.length);
    expect(document.chapterIndex, 0);
    expect(document.currentChapterTitle, document.parsed.chapters.first.title);
    document.sectionIndex = 1;
    expect(document.chapterIndex, 1);
    expect(document.currentChapterTitle, document.parsed.chapters[1].title);
  });

  test('chapter html keeps a data: img and a remote img as-is', () {
    final document = EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(
        firstMarkup:
            '<img src="data:image/png;base64,AAAA" alt="data"/>'
            '<img src="https://example.com/remote.png" alt="remote"/>',
      ),
    );
    final html = document.currentChapterHtml;
    expect(html, contains('src="data:image/png;base64,AAAA"'));
    expect(html, contains('src="https://example.com/remote.png"'));
    expect(html, contains('alt="data"'));
    expect(html, contains('alt="remote"'));
  });
}
