import 'package:app/core/models.dart';
import 'package:app/core/pdf_document.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pdf_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: '2-0',
    title: 'scan',
    author: '',
    format: DocumentFormat.pdf,
    type: DocumentType.fixedPage,
  );

  test('opens a simple pdf by page text', () async {
    final document = PdfReaderDocument.parse(
      metadata: metadata,
      bytes: minimalPdfBytes(pages: ['first page text', 'second page text']),
    );

    final toc = await document.getToc();
    expect(toc, hasLength(2));
    expect(document.currentChapterText, contains('first page text'));

    await document.goTo(const PdfLocator(page: 2));
    expect(document.currentChapterText, contains('second page text'));
    expect(
      await document.extractText(
        const DocumentRange(
          start: PdfLocator(page: 2),
          end: PdfLocator(page: 2),
        ),
      ),
      contains('second page text'),
    );
  });

  test('unreadable pdf bytes stay corrupt', () {
    expect(
      openReaderDocument(metadata: metadata, bytes: [1, 2, 3]),
      isA<CorruptReaderDocument>(),
    );
  });
}
