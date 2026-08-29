import 'package:app/core/comic_document.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'comic-1',
    title: 'Pages',
    author: 'A',
    format: DocumentFormat.cbz,
    type: DocumentType.comic,
  );

  test('opens a cbz as ordered image pages', () {
    final bytes = zipNamedFiles({
      'page-02.png': tinyPngBytes(),
      'page-01.png': tinyPngBytes(),
      'readme.txt': [1, 2, 3],
    });
    final document = ComicReaderDocument.parse(
      metadata: metadata,
      bytes: bytes,
    );
    expect(document.chapterCount, 2);
    expect(document.currentPage.name, 'page-01.png');
    expect(document.currentPage.bytes, tinyPngBytes());
  });

  test('cbr that is not a zip is corrupt', () {
    expect(
      () => ComicReaderDocument.parse(
        metadata: metadata.copyWith(format: DocumentFormat.cbr),
        bytes: [0, 1, 2, 3, 4],
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
