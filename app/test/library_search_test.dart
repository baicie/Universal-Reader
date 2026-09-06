import 'package:app/core/models.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/library/library_search.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryDocument _doc({
  required String id,
  required String title,
  String author = '本地书库',
  DocumentFormat format = DocumentFormat.txt,
  DocumentType type = DocumentType.reflow,
  DateTime? lastOpened,
}) {
  return LibraryDocument(
    metadata: DocumentMetadata(
      id: id,
      title: title,
      author: author,
      format: format,
      type: type,
      coverColor: 0xFF527882,
      contentHash: 'hash-$id',
    ),
    readingState: ReadingState(
      progress: 0,
      lastOpened: lastOpened ?? DateTime.utc(2026, 1, 1),
    ),
  );
}

ReaderAnnotation _note({
  required String id,
  String quote = '',
  String note = '',
  String locatorLabel = '',
}) {
  return ReaderAnnotation(
    id: id,
    note: note,
    quote: quote,
    locatorLabel: locatorLabel,
    source: userNoteSource,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('librarySearchAll', () {
    test('empty query returns all documents as metadata hits', () {
      final docs = [_doc(id: 'a', title: 'Alpha'), _doc(id: 'b', title: 'Beta')];

      final hits = librarySearchAll(documents: docs, query: '');

      expect(hits, hasLength(2));
      expect(hits.every((hit) => hit.kind == LibrarySearchHitKind.metadata), isTrue);
      expect(hits.map((hit) => hit.document.metadata.id).toSet(),
          equals({'a', 'b'}));
    });

    test('does not invent results for an unknown title', () {
      final docs = [_doc(id: 'a', title: 'Alpha')];

      expect(librarySearchAll(documents: docs, query: 'zzz'), isEmpty);
    });

    test('matches by title case-insensitively', () {
      final docs = [
        _doc(id: 'design', title: '设计中的设计'),
        _doc(id: 'plain', title: 'Notes'),
      ];

      final hits =
          librarySearchAll(documents: docs, query: 'design').toList();
      expect(hits.map((hit) => hit.document.metadata.id), contains('design'));
    });

    test('matches by author as well as title', () {
      final docs = [
        _doc(id: 'book1', title: 'Book', author: 'Haruki'),
        _doc(id: 'book2', title: 'Other', author: 'Someone Else'),
      ];

      final hits =
          librarySearchAll(documents: docs, query: 'Haruki').toList();
      expect(hits, hasLength(1));
      expect(hits.first.document.metadata.id, 'book1');
    });

    test('metadata hits come before note hits', () async {
      final docs = [
        _doc(id: 'meta', title: 'match', lastOpened: DateTime.utc(2026, 2, 1)),
        _doc(id: 'note', title: 'unrelated', lastOpened: DateTime.utc(2026, 3, 1)),
      ];

      final hits = await librarySearchAllAsync(
        documents: docs,
        query: 'match',
        annotationsFor: (id) async => id == 'note'
            ? [_note(id: 'n1', quote: 'match')]
            : const <ReaderAnnotation>[],
      );

      expect(hits, hasLength(2));
      expect(hits.first.document.metadata.id, 'meta');
      expect(hits.last.document.metadata.id, 'note');
      expect(hits.first.kind, LibrarySearchHitKind.metadata);
      expect(hits.last.kind, LibrarySearchHitKind.note);
    });

    test('skips annotation scan when annotationsFor is null', () {
      final docs = [
        _doc(id: 'a', title: 'Alpha'),
      ];

      final hits = librarySearchAll(
        documents: docs,
        query: 'zzz-not-here',
        annotationsFor: null,
      );

      expect(hits, isEmpty);
    });

    test('returns each document at most once even if both fields match', () {
      final docs = [
        _doc(id: 'book', title: 'match', author: 'match'),
      ];

      final hits =
          librarySearchAll(documents: docs, query: 'match').toList();
      expect(hits, hasLength(1));
      expect(hits.first.kind, LibrarySearchHitKind.metadata);
    });
  });

  group('librarySearchAllAsync', () {
    test('matches annotations by quote', () async {
      final docs = [
        _doc(id: 'a', title: 'Alpha'),
      ];

      final hits = await librarySearchAllAsync(
        documents: docs,
        query: 'needle',
        annotationsFor: (id) async => [
          _note(id: 'n1', quote: 'this contains needle'),
        ],
      );

      expect(hits, hasLength(1));
      expect(hits.first.kind, LibrarySearchHitKind.note);
      expect(hits.first.document.metadata.id, 'a');
      expect(hits.first.annotation?.quote, contains('needle'));
    });

    test('matches annotations by note text', () async {
      final docs = [
        _doc(id: 'a', title: 'Alpha'),
      ];

      final hits = await librarySearchAllAsync(
        documents: docs,
        query: 'important',
        annotationsFor: (id) async => [
          _note(id: 'n1', note: 'this is important annotation'),
        ],
      );

      expect(hits, hasLength(1));
      expect(hits.first.kind, LibrarySearchHitKind.note);
    });

    test('matches annotations by locator label', () async {
      final docs = [
        _doc(id: 'a', title: 'Alpha'),
      ];

      final hits = await librarySearchAllAsync(
        documents: docs,
        query: 'chapter-7',
        annotationsFor: (id) async => [
          _note(id: 'n1', quote: 'something', locatorLabel: 'chapter-7'),
        ],
      );

      expect(hits, hasLength(1));
    });

    test('returns metadata and note hits in the correct order', () async {
      final metaDoc = _doc(
        id: 'meta',
        title: 'match',
        lastOpened: DateTime.utc(2026, 2, 1),
      );
      final noteDoc = _doc(
        id: 'note',
        title: 'unrelated',
        lastOpened: DateTime.utc(2026, 1, 1),
      );

      final hits = await librarySearchAllAsync(
        documents: [metaDoc, noteDoc],
        query: 'match',
        annotationsFor: (id) async => id == 'note'
            ? [_note(id: 'n1', quote: 'match')]
            : const <ReaderAnnotation>[],
      );

      // metadata hits first, then note hits.
      final firstHitKind = hits.first.kind;
      final lastHitKind = hits.last.kind;
      expect(firstHitKind, equals(LibrarySearchHitKind.metadata));
      expect(lastHitKind, equals(LibrarySearchHitKind.note));
    });

    test('does not duplicate a document between metadata and note hit',
        () async {
      final docs = [
        _doc(id: 'a', title: 'Alpha match'),
      ];

      final hits = await librarySearchAllAsync(
        documents: docs,
        query: 'match',
        annotationsFor: (id) async => [
          _note(id: 'n1', quote: 'match too'),
        ],
      );

      expect(hits.where((hit) => hit.document.metadata.id == 'a'), hasLength(1));
      expect(hits.first.kind, LibrarySearchHitKind.metadata);
    });

    test('returns metadata hits even when annotations throw', () async {
      final docs = [
        _doc(id: 'a', title: 'Alpha match'),
      ];

      final hits = await librarySearchAllAsync(
        documents: docs,
        query: 'match',
        annotationsFor: (id) async => throw StateError('disk full'),
      );

      expect(hits, hasLength(1));
      expect(hits.first.kind, LibrarySearchHitKind.metadata);
      expect(hits.first.document.metadata.id, 'a');
    });

    test('empty query short-circuits metadata hits and skips annotation scan',
        () async {
      final docs = [
        _doc(id: 'a', title: 'Alpha'),
        _doc(id: 'b', title: 'Beta'),
      ];

      var scanned = 0;
      final hits = await librarySearchAllAsync(
        documents: docs,
        query: '',
        annotationsFor: (id) async {
          scanned++;
          return const <ReaderAnnotation>[];
        },
      );

      expect(hits, hasLength(2));
      expect(scanned, equals(0));
      expect(hits.every((hit) => hit.kind == LibrarySearchHitKind.metadata), isTrue);
    });
  });

  group('LibrarySearchHit', () {
    test('note kind carries the matching annotation', () {
      final doc = _doc(id: 'a', title: 'Alpha');
      final annotation = _note(id: 'n1', quote: 'match');

      final hit = LibrarySearchHit(
        document: doc,
        kind: LibrarySearchHitKind.note,
        annotation: annotation,
      );

      expect(hit.annotation, same(annotation));
    });

    test('metadata kind has a null annotation field', () {
      final doc = _doc(id: 'a', title: 'Alpha');

      final hit = LibrarySearchHit(
        document: doc,
        kind: LibrarySearchHitKind.metadata,
      );

      expect(hit.annotation, isNull);
    });
  });
}
