import 'package:app/core/mobi_document.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'mobi-1',
    title: 'Local',
    author: 'Local',
    format: DocumentFormat.mobi,
    type: DocumentType.reflow,
  );

  test('opens a zip-based azw3 as an epub spine', () {
    final document = MobiReaderDocument.parse(
      metadata: metadata.copyWith(format: DocumentFormat.azw3),
      bytes: minimalEpubBytes(firstBody: 'hello from azw3'),
    );
    expect(document.currentChapterText, contains('hello from azw3'));
    expect(document.currentChapterHtml, contains('hello from azw3'));
  });

  test('extracts a readable run from a raw mobi payload', () {
    final bytes = [
      ...List<int>.filled(80, 0),
      ...'hello from mobi and more text for the engine'.codeUnits,
    ];
    final document = MobiReaderDocument.parse(metadata: metadata, bytes: bytes);
    expect(document.currentChapterText, contains('hello from mobi'));
  });

  test('empty mobi bytes are corrupt', () {
    expect(
      () =>
          MobiReaderDocument.parse(metadata: metadata, bytes: const [0, 1, 2]),
      throwsA(isA<FormatException>()),
    );
  });
}
