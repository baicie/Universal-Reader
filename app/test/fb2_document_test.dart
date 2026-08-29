import 'package:app/core/fb2_document.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fb2_fixture.dart';

void main() {
  test('opens fictionbook chapters from the xml body', () {
    final document = Fb2ReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'fb2-1',
        title: 'Local',
        author: 'Local',
        format: DocumentFormat.fb2,
        type: DocumentType.reflow,
      ),
      bytes: minimalFb2Bytes(),
    );
    expect(document.currentChapterText, contains('hello from fb2'));
    expect(document.parsed.title, 'FB2 Book');
    expect(document.parsed.author, 'Ann Author');
    expect(document.currentChapterHtml, contains('hello from fb2'));
  });

  test('rejects xml that is not a fictionbook', () {
    expect(
      () => Fb2ReaderDocument.parse(
        metadata: const DocumentMetadata(
          id: 'fb2-bad',
          title: 'x',
          author: 'x',
          format: DocumentFormat.fb2,
          type: DocumentType.reflow,
        ),
        bytes: '<not-fb2/>'.codeUnits,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
