import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:app/core/comic_document.dart';
import 'package:app/core/docx_document.dart';
import 'package:app/core/epub_document.dart';
import 'package:app/core/fb2_document.dart';
import 'package:app/core/mobi_document.dart';
import 'package:app/core/models.dart';
import 'package:app/core/odt_document.dart';
import 'package:app/core/pdf_document.dart';
import 'package:app/core/rtf_document.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';
import 'support/docx_fixture.dart';
import 'support/fb2_fixture.dart';
import 'support/image_fixture.dart';
import 'support/pdf_fixture.dart';
import 'support/odt_fixture.dart';
import 'support/rar_fixture.dart';
import 'support/rtf_fixture.dart';

DocumentMetadata _metadata({
  required String id,
  required DocumentFormat format,
  DocumentType? type,
}) {
  return DocumentMetadata(
    id: id,
    title: id,
    author: 'Test',
    format: format,
    type: type ?? format.type,
  );
}

List<int> _comicBytes() {
  final archive = Archive();
  archive.add(
    ArchiveFile('pages/01.png', tinyPngBytes().length, tinyPngBytes()),
  );
  archive.add(
    ArchiveFile('pages/02.png', tinyPngBytes().length, tinyPngBytes()),
  );
  return ZipEncoder().encode(archive);
}

void main() {
  group('openReaderDocument with empty bytes', () {
    test('returns UnavailableReaderDocument', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.txt', format: DocumentFormat.txt),
        bytes: null,
      );
      expect(document, isA<UnavailableReaderDocument>());
    });

    test('returns UnavailableReaderDocument for an empty list', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.txt', format: DocumentFormat.txt),
        bytes: const [],
      );
      expect(document, isA<UnavailableReaderDocument>());
    });
  });

  group('openReaderDocument for plain text formats', () {
    test('parses plain text', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.txt', format: DocumentFormat.txt),
        bytes: utf8.encode('hello from txt'),
      );
      expect(document, isA<TextReaderDocument>());
      expect(document.metadata.format, DocumentFormat.txt);
    });

    test('parses markdown as text', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.md', format: DocumentFormat.markdown),
        bytes: utf8.encode('# heading'),
      );
      expect(document, isA<TextReaderDocument>());
    });

    test('parses html as text', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.html', format: DocumentFormat.html),
        bytes: utf8.encode('<p>hi</p>'),
      );
      expect(document, isA<TextReaderDocument>());
    });
  });

  group('openReaderDocument for epub', () {
    test('parses a valid epub', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.epub', format: DocumentFormat.epub),
        bytes: minimalEpubBytes(),
      );
      expect(document, isA<EpubReaderDocument>());
    });

    test('returns a corrupt document when the epub cannot be unzipped', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.epub', format: DocumentFormat.epub),
        bytes: const [1, 2, 3],
      );
      expect(document, isA<CorruptReaderDocument>());
    });
  });

  group('openReaderDocument for docx', () {
    test('parses a valid docx', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.docx', format: DocumentFormat.docx),
        bytes: minimalDocxBytes(),
      );
      expect(document, isA<DocxReaderDocument>());
    });

    test('returns a corrupt document when the docx cannot be unzipped', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.docx', format: DocumentFormat.docx),
        bytes: const [1, 2, 3],
      );
      expect(document, isA<CorruptReaderDocument>());
    });
  });

  group('openReaderDocument for odt', () {
    test('parses a valid odt', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.odt', format: DocumentFormat.odt),
        bytes: minimalOdtBytes(),
      );
      expect(document, isA<OdtReaderDocument>());
    });

    test('returns a corrupt document when the odt cannot be unzipped', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.odt', format: DocumentFormat.odt),
        bytes: const [1, 2, 3],
      );
      expect(document, isA<CorruptReaderDocument>());
    });
  });

  group('openReaderDocument for rtf', () {
    test('parses a valid rtf', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.rtf', format: DocumentFormat.rtf),
        bytes: minimalRtfBytes(),
      );
      expect(document, isA<RtfReaderDocument>());
    });

    test('returns a corrupt document for malformed rtf', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.rtf', format: DocumentFormat.rtf),
        bytes: const [1, 2, 3],
      );
      expect(document, isA<CorruptReaderDocument>());
    });
  });

  group('openReaderDocument for pdf', () {
    test('parses a valid pdf', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.pdf', format: DocumentFormat.pdf),
        bytes: minimalPdfBytes(),
      );
      expect(document, isA<PdfReaderDocument>());
    });

    test('returns a corrupt document when the pdf is malformed', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.pdf', format: DocumentFormat.pdf),
        bytes: const [1, 2, 3],
      );
      expect(document, isA<CorruptReaderDocument>());
    });
  });

  group('openReaderDocument for comics', () {
    test('parses a cbz archive of images', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.cbz', format: DocumentFormat.cbz),
        bytes: _comicBytes(),
      );
      expect(document, isA<ComicReaderDocument>());
      expect((document as ComicReaderDocument).pages, hasLength(2));
    });

    test('parses a cbr archive of images', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.cbr', format: DocumentFormat.cbr),
        bytes: _comicBytes(),
      );
      expect(document, isA<ComicReaderDocument>());
    });

    test('parses a cbt archive of images', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.cbt', format: DocumentFormat.cbt),
        bytes: tarNamedFiles({
          'page-01.png': tinyPngBytes(),
          'page-02.png': tinyPngBytes(),
        }),
      );
      expect(document, isA<ComicReaderDocument>());
      expect((document as ComicReaderDocument).pages, hasLength(2));
    });

    test('parses a non-zip cbr archive of images', () async {
      final document = await openReaderDocumentAsync(
        metadata: _metadata(id: 'book.cbr', format: DocumentFormat.cbr),
        bytes: syntheticCbrBytes(),
      );
      expect(document, isA<ComicReaderDocument>());
      expect((document as ComicReaderDocument).pages, hasLength(3));
    });

    test('returns a corrupt document when the archive is invalid', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.cbz', format: DocumentFormat.cbz),
        bytes: const [1, 2, 3],
      );
      expect(document, isA<CorruptReaderDocument>());
    });

    test('returns a corrupt document when the archive has no images', () {
      final archive = Archive();
      archive.add(ArchiveFile('notes.txt', 4, utf8.encode('note')));
      final bytes = ZipEncoder().encode(archive);
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.cbz', format: DocumentFormat.cbz),
        bytes: bytes,
      );
      expect(document, isA<CorruptReaderDocument>());
    });
  });

  group('openReaderDocument for fb2', () {
    test('parses a valid fb2', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.fb2', format: DocumentFormat.fb2),
        bytes: minimalFb2Bytes(),
      );
      expect(document, isA<Fb2ReaderDocument>());
    });

    test('returns a corrupt document when the fb2 is malformed', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.fb2', format: DocumentFormat.fb2),
        bytes: const [1, 2, 3],
      );
      expect(document, isA<CorruptReaderDocument>());
    });
  });

  group('openReaderDocument for mobi', () {
    test('parses a zip-based azw3 as a mobi document', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.azw3', format: DocumentFormat.azw3),
        bytes: minimalEpubBytes(firstBody: 'hello from azw3'),
      );
      expect(document, isA<MobiReaderDocument>());
    });

    test('parses a raw mobi payload', () {
      final bytes = [
        ...List<int>.filled(80, 0),
        ...'hello from mobi and more text for the engine'.codeUnits,
      ];
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.mobi', format: DocumentFormat.mobi),
        bytes: bytes,
      );
      expect(document, isA<MobiReaderDocument>());
    });

    test('returns a corrupt document when mobi bytes cannot be read', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.mobi', format: DocumentFormat.mobi),
        bytes: const [0, 1, 2],
      );
      expect(document, isA<CorruptReaderDocument>());
    });
  });

  group('openReaderDocument for unknown formats', () {
    test('returns UnavailableReaderDocument for an unsupported extension', () {
      final document = openReaderDocument(
        metadata: _metadata(id: 'book.xyz', format: DocumentFormat.unknown),
        bytes: const [1, 2, 3],
      );
      expect(document, isA<UnavailableReaderDocument>());
    });
  });
}
