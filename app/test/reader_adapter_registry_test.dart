import 'dart:convert';

import 'package:app/core/models.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/reader_adapter_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';

DocumentMetadata _metadata(DocumentFormat format) {
  return DocumentMetadata(
    id: 'book.${format.name}',
    title: 'Book',
    author: '',
    format: format,
    type: format.type,
  );
}

void main() {
  test('standard registry covers every direct-read format once', () {
    expect(ReaderAdapterRegistry.standard.formats, {
      DocumentFormat.txt,
      DocumentFormat.markdown,
      DocumentFormat.html,
      DocumentFormat.docx,
      DocumentFormat.odt,
      DocumentFormat.rtf,
      DocumentFormat.epub,
      DocumentFormat.pdf,
      DocumentFormat.fb2,
      DocumentFormat.mobi,
      DocumentFormat.azw3,
      DocumentFormat.cbz,
      DocumentFormat.cbr,
      DocumentFormat.cbt,
      DocumentFormat.cb7,
    });
  });

  test('registry rejects duplicate adapters for the same format', () {
    expect(
      () => ReaderAdapterRegistry(const [
        TextFormatAdapter(),
        TextFormatAdapter(),
      ]),
      throwsStateError,
    );
  });

  test('adapter sniff accepts its formats and rejects others', () async {
    const adapter = TextFormatAdapter();
    expect(
      await adapter.sniff(
        DocumentSource(name: 'book.txt', bytes: utf8.encode('plain')),
      ),
      1,
    );
    expect(
      await adapter.sniff(
        DocumentSource(name: 'book.epub', bytes: minimalEpubBytes()),
      ),
      0,
    );
  });

  test('adapter open can derive metadata from the source', () async {
    final document = await const TextFormatAdapter().open(
      DocumentSource(name: 'plain.txt', bytes: utf8.encode('plain')),
    );
    expect(document, isA<TextReaderDocument>());
    expect(document.metadata.format, DocumentFormat.txt);
  });

  test('registry preserves corrupt and unavailable fallbacks', () async {
    final corrupt = await ReaderAdapterRegistry.standard.open(
      metadata: _metadata(DocumentFormat.epub),
      bytes: const [1, 2, 3],
    );
    expect(corrupt, isA<CorruptReaderDocument>());

    final unavailable = await ReaderAdapterRegistry.standard.open(
      metadata: _metadata(DocumentFormat.unknown),
      bytes: const [1, 2, 3],
    );
    expect(unavailable, isA<UnavailableReaderDocument>());
  });

  test('registry leaves missing bytes unavailable', () {
    final document = ReaderAdapterRegistry.standard.openSync(
      metadata: _metadata(DocumentFormat.txt),
      bytes: null,
    );
    expect(document, isA<UnavailableReaderDocument>());
  });
}
