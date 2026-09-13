import 'package:app/core/docx_document.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/docx_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'office.docx',
    title: 'DOCX Compatibility Book',
    author: 'Ada Reader',
    format: DocumentFormat.docx,
    type: DocumentType.reflow,
  );

  test('parses document metadata, headings, and inline formatting', () {
    final parsed = parseDocx(minimalDocxBytes());

    expect(parsed.title, 'DOCX Compatibility Book');
    expect(parsed.author, 'Ada Reader');
    expect(parsed.chapters.map((chapter) => chapter.title), [
      'DOCX Compatibility Book',
      'Chapter One',
      'Chapter Two',
    ]);
    expect(parsed.chapters[1].html, contains('<strong>bold</strong>'));
    expect(parsed.chapters[1].html, contains('<em>italic</em>'));
    expect(parsed.chapters[1].html, contains('<table>'));
    expect(parsed.chapters[1].html, contains('href="https://example.com"'));
    expect(parsed.chapters[1].text, contains('- First item'));
  });

  test('opens through the shared reader factory', () {
    final document = openReaderDocument(
      metadata: metadata,
      bytes: minimalDocxBytes(),
    );

    expect(document, isA<DocxReaderDocument>());
    expect(document, isA<HtmlChapteredDocument>());
    expect((document as DocxReaderDocument).chapterCount, 3);
  });

  test('navigates by shared reflow locator', () async {
    final document = DocxReaderDocument.parse(
      metadata: metadata,
      bytes: minimalDocxBytes(),
    );

    await document.goTo(const EpubLocator(href: 'section-2'));
    expect(document.chapterIndex, 2);
    expect(document.currentChapterTitle, 'Chapter Two');
    expect(document.currentChapterText, contains('Second chapter body.'));
  });

  test('searches all chapters case-insensitively', () async {
    final document = DocxReaderDocument.parse(
      metadata: metadata,
      bytes: minimalDocxBytes(),
    );

    final hits = await document.search('CHAPTER TWO');
    expect(hits, hasLength(1));
    expect((hits.single.locator as EpubLocator).href, 'section-2');
  });

  test('rejects a zip without word/document.xml', () {
    expect(
      () => parseDocx(minimalDocxBytes().sublist(0, 3)),
      throwsA(isA<FormatException>()),
    );
  });
}
