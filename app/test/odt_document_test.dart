import 'package:app/core/models.dart';
import 'package:app/core/odt_document.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/odt_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'office.odt',
    title: 'ODT Compatibility Book',
    author: 'Libre Writer',
    format: DocumentFormat.odt,
    type: DocumentType.reflow,
  );

  test('parses metadata, headings, inline styles, lists, and tables', () {
    final parsed = parseOdt(minimalOdtBytes());

    expect(parsed.title, 'ODT Compatibility Book');
    expect(parsed.author, 'Libre Writer');
    expect(parsed.chapters.map((chapter) => chapter.title), [
      'Chapter One',
      'Chapter Two',
    ]);
    expect(parsed.chapters[0].html, contains('<strong>bold</strong>'));
    expect(parsed.chapters[0].html, contains('<em>italic</em>'));
    expect(
      parsed.chapters[0].html,
      contains('<u><strong>strong underline</strong></u>'),
    );
    expect(parsed.chapters[0].html, contains('<ul>'));
    expect(parsed.chapters[0].html, contains('<table>'));
    expect(parsed.chapters[0].html, contains('href="https://example.com"'));
    expect(parsed.chapters[0].text, contains('- First item'));
  });

  test('opens through the shared reader factory', () {
    final document = openReaderDocument(
      metadata: metadata,
      bytes: minimalOdtBytes(),
    );

    expect(document, isA<OdtReaderDocument>());
    expect(document, isA<HtmlChapteredDocument>());
    expect((document as OdtReaderDocument).chapterCount, 2);
  });

  test('navigates and searches through the shared reflow contract', () async {
    final document = OdtReaderDocument.parse(
      metadata: metadata,
      bytes: minimalOdtBytes(),
    );

    await document.goTo(const EpubLocator(href: 'section-1'));
    expect(document.currentChapterTitle, 'Chapter Two');

    final hits = await document.search('SECOND CHAPTER');
    expect(hits, hasLength(1));
    expect((hits.single.locator as EpubLocator).href, 'section-1');
  });

  test('rejects a docx-like zip without the ODT mimetype', () {
    expect(
      () => parseOdt(minimalOdtBytes().sublist(0, 3)),
      throwsA(isA<FormatException>()),
    );
  });
}
