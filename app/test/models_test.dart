import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentFormat.label', () {
    test('returns a human-readable label for every format', () {
      expect(DocumentFormat.epub.label, 'EPUB');
      expect(DocumentFormat.pdf.label, 'PDF');
      expect(DocumentFormat.mobi.label, 'MOBI');
      expect(DocumentFormat.azw3.label, 'AZW3');
      expect(DocumentFormat.fb2.label, 'FB2');
      expect(DocumentFormat.txt.label, 'TXT');
      expect(DocumentFormat.markdown.label, 'MD');
      expect(DocumentFormat.html.label, 'HTML');
      expect(DocumentFormat.cbz.label, 'CBZ');
      expect(DocumentFormat.cbr.label, 'CBR');
      expect(DocumentFormat.unknown.label, 'FILE');
    });
  });

  group('DocumentFormat.type', () {
    test('maps fixed-page formats to fixedPage', () {
      expect(DocumentFormat.pdf.type, DocumentType.fixedPage);
    });

    test('maps comic formats to comic', () {
      expect(DocumentFormat.cbz.type, DocumentType.comic);
      expect(DocumentFormat.cbr.type, DocumentType.comic);
    });

    test('maps all other formats to reflow', () {
      for (final format in [
        DocumentFormat.epub,
        DocumentFormat.mobi,
        DocumentFormat.azw3,
        DocumentFormat.fb2,
        DocumentFormat.txt,
        DocumentFormat.markdown,
        DocumentFormat.html,
        DocumentFormat.unknown,
      ]) {
        expect(
          format.type,
          DocumentType.reflow,
          reason: '$format should be reflow',
        );
      }
    });
  });

  group('DocumentSource', () {
    test('stores name, optional path, and optional bytes', () {
      const source = DocumentSource(
        name: 'book.epub',
        path: '/data/books',
        bytes: [0x50, 0x4B],
      );
      expect(source.name, 'book.epub');
      expect(source.path, '/data/books');
      expect(source.bytes, [0x50, 0x4B]);
    });

    test('bytes is nullable', () {
      const source = DocumentSource(name: 'book.epub');
      expect(source.bytes, isNull);
      expect(source.path, isNull);
    });
  });

  group('DocumentMetadata.copyWith', () {
    const base = DocumentMetadata(
      id: 'design',
      title: 'Design Notes',
      author: 'Some Author',
      format: DocumentFormat.epub,
      type: DocumentType.reflow,
      coverColor: 0xFF4F7C8A,
      contentHash: 'abc123',
      hasCover: true,
    );

    test('replaces only the specified fields', () {
      final updated = base.copyWith(title: 'Updated Title');
      expect(updated.id, 'design');
      expect(updated.title, 'Updated Title');
      expect(updated.author, 'Some Author');
      expect(updated.format, DocumentFormat.epub);
      expect(updated.coverColor, 0xFF4F7C8A);
      expect(updated.hasCover, isTrue);
    });

    test('can replace all fields at once', () {
      final updated = base.copyWith(
        id: 'other',
        title: 'Other',
        author: 'X',
        format: DocumentFormat.pdf,
        type: DocumentType.fixedPage,
        coverColor: 0xFF000000,
        contentHash: 'xyz',
        hasCover: false,
      );
      expect(updated.id, 'other');
      expect(updated.title, 'Other');
      expect(updated.author, 'X');
      expect(updated.format, DocumentFormat.pdf);
      expect(updated.type, DocumentType.fixedPage);
      expect(updated.coverColor, 0xFF000000);
      expect(updated.contentHash, 'xyz');
      expect(updated.hasCover, isFalse);
    });
  });

  group('ReadingState', () {
    test('stores progress and lastOpened', () {
      final openedAt = DateTime.utc(2026, 9, 7);
      final state = ReadingState(progress: 0.42, lastOpened: openedAt);
      expect(state.progress, 0.42);
      expect(state.lastOpened, openedAt);
    });
  });

  group('LibraryDocument.copyWith', () {
    final base = LibraryDocument(
      metadata: const DocumentMetadata(
        id: 'design',
        title: 'Design Notes',
        author: 'Some Author',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
      readingState: ReadingState(
        progress: 0.3,
        lastOpened: DateTime.utc(2026, 1, 1),
      ),
    );

    test('replaces only the specified fields', () {
      final updated = base.copyWith(
        metadata: base.metadata.copyWith(title: 'Renamed'),
      );
      expect(updated.metadata.title, 'Renamed');
      expect(updated.readingState.progress, 0.3);
    });

    test('can replace reading state', () {
      final newState = ReadingState(
        progress: 0.75,
        lastOpened: DateTime.utc(2026, 9, 7),
      );
      final updated = base.copyWith(readingState: newState);
      expect(updated.metadata.id, 'design');
      expect(updated.readingState.progress, 0.75);
    });
  });

  group('Locator subclasses equality', () {
    test('PdfLocator with same page is equal', () {
      const a = PdfLocator(page: 3);
      const b = PdfLocator(page: 3);
      expect(a, equals(b));
    });

    test('PdfLocator with different pages are not equal', () {
      const a = PdfLocator(page: 3);
      const b = PdfLocator(page: 4);
      expect(a, isNot(equals(b)));
    });

    test('EpubLocator with same fields are equal', () {
      const a = EpubLocator(
        href: 'ch1.xhtml',
        cfi: '/6/4',
        progression: 0.5,
        fragment: 'note',
      );
      const b = EpubLocator(
        href: 'ch1.xhtml',
        cfi: '/6/4',
        progression: 0.5,
        fragment: 'note',
      );
      expect(a, equals(b));
    });

    test('EpubLocator with different hrefs are not equal', () {
      const a = EpubLocator(href: 'ch1.xhtml');
      const b = EpubLocator(href: 'ch2.xhtml');
      expect(a, isNot(equals(b)));
    });

    test('TextLocator with same offset is equal', () {
      const a = TextLocator(offset: 1024);
      const b = TextLocator(offset: 1024);
      expect(a, equals(b));
    });

    test('ComicLocator with same page is equal', () {
      const a = ComicLocator(page: 7);
      const b = ComicLocator(page: 7);
      expect(a, equals(b));
    });
  });
}
