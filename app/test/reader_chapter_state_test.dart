import 'package:app/core/models.dart';
import 'package:app/core/reader_chapter_state.dart';
import 'package:app/core/text_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LibraryDocument library(DocumentFormat format) {
    final epoch = DateTime.utc(2024);
    return LibraryDocument(
      metadata: DocumentMetadata(
        id: 'a',
        title: 'A',
        author: 'A',
        format: format,
        type: DocumentType.reflow,
      ),
      readingState: ReadingState(progress: 0, lastOpened: epoch),
    );
  }

  group('loading flag dominates everything else', () {
    test('loading returns a loading state even when corrupt opened', () {
      final state = resolveReaderChapterState(
        loading: true,
        opened: CorruptReaderDocument(
          metadata: library(DocumentFormat.epub).metadata,
        ),
        document: library(DocumentFormat.epub),
        isTruncated: false,
      );
      expect(state.kind, ReaderChapterKind.loading);
      expect(state.truncated, isFalse);
    });

    test('loading wins over an unavailable opener', () {
      final state = resolveReaderChapterState(
        loading: true,
        opened: UnavailableReaderDocument(
          metadata: library(DocumentFormat.epub).metadata,
        ),
        document: library(DocumentFormat.epub),
        isTruncated: true,
      );
      expect(state.kind, ReaderChapterKind.loading);
    });
  });

  group('corrupt opener', () {
    test('returns a corrupt state even when document is missing', () {
      final state = resolveReaderChapterState(
        loading: false,
        opened: CorruptReaderDocument(
          metadata: library(DocumentFormat.pdf).metadata,
        ),
        document: null,
        isTruncated: false,
      );
      expect(state.kind, ReaderChapterKind.corrupt);
      expect(state.missingFile, isFalse);
      // DocumentFormat.unknown maps to "FILE" in the format label list.
    });
  });

  group('unavailable opener', () {
    test('marks missingFile when the library entry is gone', () {
      final state = resolveReaderChapterState(
        loading: false,
        opened: UnavailableReaderDocument(
          metadata: library(DocumentFormat.epub).metadata,
        ),
        document: null,
        isTruncated: false,
      );
      expect(state.kind, ReaderChapterKind.unavailable);
      expect(state.missingFile, isTrue);
    });

    test('marks missingFile when the format is a reader-engine format', () {
      // epub is a reader-engine format, so even with a document, missingFile is true
      final doc = library(DocumentFormat.epub);
      final state = resolveReaderChapterState(
        loading: false,
        opened: UnavailableReaderDocument(metadata: doc.metadata),
        document: doc,
        isTruncated: false,
      );
      expect(state.missingFile, isTrue);
      expect(state.formatLabel, 'EPUB');
    });

    test('marks missingFile=true even when the library entry exists for plain text', () {
      // txt is a reader-engine format, so the file is considered missing
      // regardless of whether the library entry is present.
      final doc = library(DocumentFormat.txt);
      final state = resolveReaderChapterState(
        loading: false,
        opened: UnavailableReaderDocument(metadata: doc.metadata),
        document: doc,
        isTruncated: false,
      );
      expect(state.missingFile, isTrue);
      expect(state.formatLabel, 'TXT');
    });

    test('marks missingFile=false for unknown formats when the document is present', () {
      // unknown is not a reader-engine format, so a present document means
      // the file is reachable.
      final doc = library(DocumentFormat.unknown);
      final state = resolveReaderChapterState(
        loading: false,
        opened: UnavailableReaderDocument(metadata: doc.metadata),
        document: doc,
        isTruncated: false,
      );
      expect(state.missingFile, isFalse);
      // unknown → "FILE" label
    });

    test('falls back to empty format label when document is null', () {
      // Open the unavailable branch using a metadata-less UnavailableReaderDocument;
      // the document parameter is null, so formatLabel must default to empty.
      final state = resolveReaderChapterState(
        loading: false,
        opened: UnavailableReaderDocument(
          metadata: const DocumentMetadata(
            id: 'x',
            title: 't',
            author: '',
            format: DocumentFormat.epub,
            type: DocumentType.reflow,
          ),
        ),
        document: null,
        isTruncated: false,
      );
      expect(state.kind, ReaderChapterKind.unavailable);
      expect(state.missingFile, isTrue);
      expect(state.formatLabel, isEmpty);
    });
  });

  group('ready (default)', () {
    test('truncated flag is forwarded', () {
      final state = resolveReaderChapterState(
        loading: false,
        opened: null,
        document: library(DocumentFormat.txt),
        isTruncated: true,
      );
      expect(state.kind, ReaderChapterKind.ready);
      expect(state.truncated, isTrue);
      expect(state.missingFile, isFalse);
    });

    test('truncated=false when the chapter is complete', () {
      final state = resolveReaderChapterState(
        loading: false,
        opened: null,
        document: library(DocumentFormat.txt),
        isTruncated: false,
      );
      expect(state.kind, ReaderChapterKind.ready);
      expect(state.truncated, isFalse);
    });

    test('null opener + null document drops straight to ready', () {
      final state = resolveReaderChapterState(
        loading: false,
        opened: null,
        document: null,
        isTruncated: false,
      );
      expect(state.kind, ReaderChapterKind.ready);
      expect(state.formatLabel, isEmpty);
      expect(state.missingFile, isFalse);
    });

    test('truncated=false survives a corrupt opener when loading=false', () {
      // Documented behaviour: the corrupt branch ignores isTruncated and
      // pins the truncated flag to false because corrupt shows its own copy.
      final state = resolveReaderChapterState(
        loading: false,
        opened: CorruptReaderDocument(
          metadata: library(DocumentFormat.epub).metadata,
        ),
        document: library(DocumentFormat.epub),
        isTruncated: true,
      );
      expect(state.kind, ReaderChapterKind.corrupt);
      expect(state.truncated, isFalse);
    });
  });

  group('priority order: loading > corrupt > unavailable > ready', () {
    test('corrupt beats unavailable when both kinds could match', () {
      final state = resolveReaderChapterState(
        loading: false,
        opened: CorruptReaderDocument(
          metadata: library(DocumentFormat.epub).metadata,
        ),
        document: null,
        isTruncated: false,
      );
      expect(state.kind, ReaderChapterKind.corrupt);
    });

    test('unavailable beats ready when opener is unavailable', () {
      final state = resolveReaderChapterState(
        loading: false,
        opened: UnavailableReaderDocument(
          metadata: library(DocumentFormat.html).metadata,
        ),
        document: library(DocumentFormat.html),
        isTruncated: true,
      );
      expect(state.kind, ReaderChapterKind.unavailable);
      // ready's truncated flag must not leak through
      expect(state.truncated, isFalse);
    });
  });
}
