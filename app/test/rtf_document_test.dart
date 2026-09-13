import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/rtf_document.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/rtf_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'office.rtf',
    title: 'RTF Compatibility Book',
    author: 'Rich Text',
    format: DocumentFormat.rtf,
    type: DocumentType.reflow,
  );

  test('parses metadata, headings, formatting, unicode, and tables', () {
    final parsed = parseRtf(minimalRtfBytes());

    expect(parsed.title, 'RTF Compatibility Book');
    expect(parsed.author, 'Rich Text');
    expect(parsed.chapters.map((chapter) => chapter.title), [
      'Chapter One',
      'Chapter Two',
    ]);
    expect(parsed.chapters[0].html, contains('<strong>bold</strong>'));
    expect(parsed.chapters[0].html, contains('<em>italic</em>'));
    expect(parsed.chapters[0].text, contains('中文'));
    expect(parsed.chapters[0].text, contains('•\tFirst item'));
    expect(parsed.chapters[0].html, contains('<table>'));
  });

  test('opens through the shared reader factory', () {
    final document = openReaderDocument(
      metadata: metadata,
      bytes: minimalRtfBytes(),
    );

    expect(document, isA<RtfReaderDocument>());
    expect(document, isA<HtmlChapteredDocument>());
    expect((document as RtfReaderDocument).chapterCount, 2);
  });

  test('navigates and searches through the shared reflow contract', () async {
    final document = RtfReaderDocument.parse(
      metadata: metadata,
      bytes: minimalRtfBytes(),
    );

    await document.goTo(const EpubLocator(href: 'section-1'));
    expect(document.currentChapterTitle, 'Chapter Two');

    final hits = await document.search('SECOND CHAPTER');
    expect(hits, hasLength(1));
    expect((hits.single.locator as EpubLocator).href, 'section-1');
  });

  test('rejects bytes without an RTF header', () {
    expect(
      () => parseRtf([...minimalRtfBytes().skip(1)]),
      throwsA(isA<FormatException>()),
    );
  });
}
