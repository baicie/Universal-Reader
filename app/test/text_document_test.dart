import 'dart:convert';

import 'package:app/core/models.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/tools/sample_reader_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      metadata: const DocumentMetadata(
        id: 'notes',
        title: 'notes',
        author: '本地书库',
        format: DocumentFormat.txt,
        type: DocumentType.reflow,
      ),
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
    final text = openReaderDocument(
      metadata: const DocumentMetadata(
        id: '1-0',
        title: 'notes',
        author: '',
        format: DocumentFormat.txt,
        type: DocumentType.reflow,
      ),
      bytes: utf8.encode('from disk'),
    );
    expect(text, isA<TextReaderDocument>());

    final pdf = openReaderDocument(
      metadata: const DocumentMetadata(
        id: '2-0',
        title: 'scan',
        author: '',
        format: DocumentFormat.pdf,
        type: DocumentType.fixedPage,
      ),
      bytes: [1, 2, 3],
    );
    expect(pdf, isA<CorruptReaderDocument>());

    final seed = openReaderDocument(
      metadata: const DocumentMetadata(
        id: 'design',
        title: '设计中的设计',
        author: '原研哉',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
    );
    expect(seed, isA<SampleReaderDocument>());
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
}
