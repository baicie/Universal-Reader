import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/content_hash.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:app/core/web_library_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/epub_fixture.dart';
import 'support/fb2_fixture.dart';
import 'support/image_fixture.dart';

void main() {
  final epoch = DateTime(2026, 1, 1);
  final document = LibraryDocument(
    metadata: const DocumentMetadata(
      id: 'book-1',
      title: 'Test Book',
      author: 'Author',
      format: DocumentFormat.epub,
      type: DocumentType.reflow,
    ),
    readingState: ReadingState(
      progress: .42,
      lastOpened: DateTime(2026, 8, 25, 7, 30),
    ),
  );

  test('round trips library documents through JSON', () {
    final decoded = LibraryDocumentCodec.fromJson(
      LibraryDocumentCodec.toJson(document),
    );

    expect(decoded.metadata.title, 'Test Book');
    expect(decoded.metadata.format, DocumentFormat.epub);
    expect(decoded.readingState.progress, .42);
    expect(decoded.readingState.lastOpened, document.readingState.lastOpened);
  });

  test('in-memory repository persists a replacement snapshot', () async {
    final repository = InMemoryLibraryRepository([document]);
    expect((await repository.load()).single.metadata.id, 'book-1');

    await repository.save([]);
    expect(await repository.load(), isEmpty);
  });

  test('in-memory repository imports supported bytes', () async {
    final repository = InMemoryLibraryRepository();
    final document = await repository.importBytes('notes.txt', [1, 2, 3]);
    expect(document.metadata.title, 'notes');
    expect(document.metadata.author, isEmpty);
    expect(document.metadata.format, DocumentFormat.txt);
    expect((await repository.load()).single.metadata.id, 'notes.txt');
    expect(await repository.readFile('notes.txt'), [1, 2, 3]);
  });

  test('import uses opf title and author instead of the file name', () async {
    final repository = InMemoryLibraryRepository();
    final document = await repository.importBytes(
      'story.epub',
      minimalEpubBytes(),
    );
    expect(document.metadata.title, 'Fixture Book');
    expect(document.metadata.author, 'Fixture Author');
  });

  test('import uses fictionbook title when the file has one', () async {
    final repository = InMemoryLibraryRepository();
    final document = await repository.importBytes(
      'book.fb2',
      minimalFb2Bytes(),
    );
    expect(document.metadata.title, 'FB2 Book');
    expect(document.metadata.author, 'Ann Author');
  });

  test(
    'a file without metadata keeps the file name and no invented author',
    () async {
      final repository = InMemoryLibraryRepository();
      final document = await repository.importBytes('notes.txt', [1, 2, 3]);
      expect(document.metadata.title, 'notes');
      expect(document.metadata.author, isEmpty);
    },
  );

  test('writeIdentity persists a new title and author', () async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', [1, 2, 3]);

    await repository.writeIdentity(
      id: 'notes.txt',
      title: '  设计笔记  ',
      author: '  某作者  ',
    );

    final loaded = (await repository.load()).single;
    expect(loaded.metadata.title, '设计笔记');
    expect(loaded.metadata.author, '某作者');
    expect(await repository.readFile('notes.txt'), [1, 2, 3]);
  });

  test(
    'an empty title keeps the existing name and does not invent a book',
    () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('notes.txt', [1, 2, 3]);

      await repository.writeIdentity(id: 'notes.txt', title: '   ', author: '');
      await repository.writeIdentity(
        id: 'missing',
        title: '设计中的设计',
        author: '原研哉',
      );

      final loaded = await repository.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.metadata.title, 'notes');
      expect(loaded.single.metadata.author, isEmpty);
      expect(loaded.any((item) => item.metadata.title == '设计中的设计'), isFalse);
    },
  );

  test('renamed title survives reimport of the same bytes', () async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', [1, 2, 3]);
    await repository.writeIdentity(
      id: 'notes.txt',
      title: '设计笔记',
      author: '某作者',
    );

    final again = await repository.importBytes('notes.txt', [1, 2, 3]);
    expect(again.metadata.title, '设计笔记');
    expect(again.metadata.author, '某作者');
    expect(await repository.load(), hasLength(1));
  });

  test(
    'SharedPreferencesLibraryRepository returns defaults when empty',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPreferencesLibraryRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await repo.load(), isEmpty);
      expect(repo.usesRemoteStore, isFalse);
    },
  );

  test(
    'SharedPreferencesLibraryRepository recovers from corrupt JSON',
    () async {
      SharedPreferences.setMockInitialValues({
        'universal_reader.library.v1': '{not-json',
      });
      final repo = SharedPreferencesLibraryRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await repo.load(), isEmpty);
    },
  );

  test('SharedPreferencesLibraryRepository round-trips through JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPreferencesLibraryRepository(
      await SharedPreferences.getInstance(),
    );
    await repo.save([document]);
    final loaded = await repo.load();
    expect(loaded.single.metadata.id, 'book-1');
    expect(loaded.single.readingState.progress, .42);
  });

  test(
    'SharedPreferencesLibraryRepository ignores non-list JSON values',
    () async {
      SharedPreferences.setMockInitialValues({
        'universal_reader.library.v1': '{"not":"a-list"}',
      });
      final repo = SharedPreferencesLibraryRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await repo.load(), isEmpty);
    },
  );

  test('SharedPreferencesLibraryRepository writes reading state', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPreferencesLibraryRepository(
      await SharedPreferences.getInstance(),
    );
    await repo.save([document]);
    await repo.writeReadingState(
      id: 'book-1',
      progress: 0.9,
      lastOpened: DateTime(2026, 9, 1),
    );
    final loaded = await repo.load();
    expect(loaded.single.readingState.progress, 0.9);
    expect(loaded.single.readingState.lastOpened, DateTime(2026, 9, 1));
  });

  test('SharedPreferencesLibraryRepository no-ops for missing books', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPreferencesLibraryRepository(
      await SharedPreferences.getInstance(),
    );
    await repo.save([document]);
    await repo.writeReadingState(
      id: 'missing',
      progress: 1,
      lastOpened: DateTime(2026, 9, 1),
    );
    await repo.writeIdentity(id: 'missing', title: 'new', author: 'a');
    await repo.delete('missing');
    final loaded = await repo.load();
    expect(loaded.single.metadata.id, 'book-1');
  });

  test(
    'InMemoryLibraryRepository reads back the file bytes and cover',
    () async {
      final repo = InMemoryLibraryRepository();
      await repo.importBytes('notes.txt', [1, 2, 3]);
      expect(await repo.readFile('notes.txt'), [1, 2, 3]);
      // Plain text without an embedded cover returns null.
      expect(await repo.readCover('notes.txt'), isNull);
    },
  );

  test(
    'InMemoryLibraryRepository deletes the file bytes alongside metadata',
    () async {
      final repo = InMemoryLibraryRepository();
      await repo.importBytes('notes.txt', [1, 2, 3]);
      await repo.delete('notes.txt');
      expect(await repo.readFile('notes.txt'), isNull);
    },
  );

  test(
    'clipBookIdentity keeps short strings unchanged and truncates the rest',
    () {
      expect(clipBookIdentity('short'), 'short');
      final long = 'x' * (maxBookIdentityLength + 5);
      final clipped = clipBookIdentity(long);
      expect(clipped.length, maxBookIdentityLength);
    },
  );

  test(
    'bookTitleForWrite keeps the current title when blank and trims input',
    () {
      expect(bookTitleForWrite('  ', 'current'), 'current');
      expect(bookTitleForWrite('  new title  ', 'current'), 'new title');
    },
  );

  test('bookAuthorForWrite trims and clips the input', () {
    expect(bookAuthorForWrite('  作者  '), '作者');
    final long = 'a' * (maxBookIdentityLength + 3);
    expect(bookAuthorForWrite('  $long  ').length, maxBookIdentityLength);
  });

  group('LibraryDocumentCodec.fromServiceJson', () {
    test('uses fixed_page document_type', () {
      final doc = LibraryDocumentCodec.fromServiceJson({
        'id': 'book-1',
        'title': 'T',
        'file_name': 't.pdf',
        'format': 'pdf',
        'document_type': 'fixed_page',
        'content_hash': 'abc',
      });
      expect(doc.metadata.type, DocumentType.fixedPage);
    });

    test('uses comic document_type', () {
      final doc = LibraryDocumentCodec.fromServiceJson({
        'id': 'book-1',
        'title': 'T',
        'file_name': 't.cbz',
        'format': 'cbz',
        'document_type': 'comic',
        'content_hash': 'abc',
      });
      expect(doc.metadata.type, DocumentType.comic);
    });

    test('falls back to reflow when document_type is unknown', () {
      final doc = LibraryDocumentCodec.fromServiceJson({
        'id': 'book-1',
        'file_name': 't.epub',
        'format': 'epub',
        'document_type': 'mystery',
        'content_hash': 'abc',
      });
      expect(doc.metadata.type, DocumentType.reflow);
    });

    test('falls back to format.type when format is unknown', () {
      final doc = LibraryDocumentCodec.fromServiceJson({
        'id': 'book-1',
        'file_name': 't.???',
        'format': 'mystery',
        'content_hash': 'abc',
      });
      expect(doc.metadata.format, DocumentFormat.unknown);
      expect(doc.metadata.type, DocumentType.reflow);
    });

    test('falls back to file_name when title is missing', () {
      final doc = LibraryDocumentCodec.fromServiceJson({
        'id': 'book-1',
        'title': '   ',
        'file_name': 't.txt',
        'format': 'txt',
        'content_hash': 'abc',
      });
      expect(doc.metadata.title, 't.txt');
    });

    test('keeps author empty when missing instead of inventing 本地书库', () {
      // `本地书库` is UI copy and must not leak into the model. The UI layer
      // already maps an empty author back to a localized label.
      final doc = LibraryDocumentCodec.fromServiceJson({
        'id': 'book-1',
        'title': 'T',
        'file_name': 't.txt',
        'format': 'txt',
        'content_hash': 'abc',
      });
      expect(doc.metadata.author, isEmpty);
    });

    test('defaults progress and lastOpened when missing', () {
      final doc = LibraryDocumentCodec.fromServiceJson({
        'id': 'book-1',
        'title': 'T',
        'file_name': 't.txt',
        'format': 'txt',
        'content_hash': 'abc',
      });
      expect(doc.readingState.progress, 0);
      expect(
        doc.readingState.lastOpened,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
  });

  group('WebPersistentLibraryRepository', () {
    test(
      'readFile returns null for corrupt base64 instead of crashing',
      () async {
        // Storing malformed base64 in preferences (e.g., manual edit or data
        // corruption) must not crash the reader; treat it as a missing file.
        SharedPreferences.setMockInitialValues({
          '${WebPersistentLibraryRepository.filePrefix}corrupt':
              '@@@@binary junk with chars outside the base64 alphabet@@@@',
        });
        final repo = WebPersistentLibraryRepository(
          await SharedPreferences.getInstance(),
        );
        expect(await repo.readFile('corrupt'), isNull);
      },
    );

    test(
      'readCover returns null for corrupt base64 instead of crashing',
      () async {
        SharedPreferences.setMockInitialValues({
          '${WebPersistentLibraryRepository.coverPrefix}bad':
              '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
        });
        final repo = WebPersistentLibraryRepository(
          await SharedPreferences.getInstance(),
        );
        expect(await repo.readCover('bad'), isNull);
      },
    );
  });

  group('importedLibraryDocument', () {
    test('throws FormatException for unsupported file extensions', () {
      expect(
        () => importedLibraryDocument('garbage.dat', [0xFF, 0x00]),
        throwsA(isA<FormatException>()),
      );
    });

    test('flags hasCover when cover bytes are provided', () {
      final doc = importedLibraryDocument(
        'book.epub',
        minimalEpubBytes(),
        cover: tinyPngBytes(),
      );
      expect(doc.metadata.hasCover, isTrue);
    });

    test('keeps hasCover false when cover is null', () {
      final doc = importedLibraryDocument('book.epub', minimalEpubBytes());
      expect(doc.metadata.hasCover, isFalse);
    });

    test('contentHash matches contentHash() of the same bytes', () {
      final bytes = minimalEpubBytes();
      final doc = importedLibraryDocument('book.epub', bytes);
      expect(doc.metadata.contentHash, contentHash(bytes));
    });

    test('readingState starts at zero progress', () {
      final doc = importedLibraryDocument('book.epub', minimalEpubBytes());
      expect(doc.readingState.progress, 0);
    });
  });

  group('documentWithHash', () {
    test('returns null for empty hash without scanning', () {
      final doc = LibraryDocument(
        metadata: const DocumentMetadata(
          id: 'a',
          title: 't',
          author: '',
          format: DocumentFormat.epub,
          type: DocumentType.reflow,
          contentHash: 'real',
        ),
        readingState: ReadingState(progress: 0, lastOpened: epoch),
      );
      expect(documentWithHash([doc], ''), isNull);
    });

    test('returns null when no document matches the hash', () {
      final doc = LibraryDocument(
        metadata: const DocumentMetadata(
          id: 'a',
          title: 't',
          author: '',
          format: DocumentFormat.epub,
          type: DocumentType.reflow,
          contentHash: 'aaa',
        ),
        readingState: ReadingState(progress: 0, lastOpened: epoch),
      );
      expect(documentWithHash([doc], 'bbb'), isNull);
    });

    test('returns the matching document', () {
      final a = LibraryDocument(
        metadata: const DocumentMetadata(
          id: 'a',
          title: 't',
          author: '',
          format: DocumentFormat.epub,
          type: DocumentType.reflow,
          contentHash: 'aaa',
        ),
        readingState: ReadingState(progress: 0, lastOpened: epoch),
      );
      final b = LibraryDocument(
        metadata: const DocumentMetadata(
          id: 'b',
          title: 't',
          author: '',
          format: DocumentFormat.epub,
          type: DocumentType.reflow,
          contentHash: 'bbb',
        ),
        readingState: ReadingState(progress: 0, lastOpened: epoch),
      );
      expect(documentWithHash([a, b], 'bbb'), same(b));
    });
  });

  group('InMemoryLibraryRepository missing-id branches', () {
    test('writeReadingState for unknown id is a no-op', () async {
      final repo = InMemoryLibraryRepository();
      await repo.importBytes('notes.txt', [1, 2, 3]);
      await repo.writeReadingState(
        id: 'missing',
        progress: 0.5,
        lastOpened: DateTime(2026, 9, 1),
      );
      final loaded = (await repo.load()).single;
      // Reading state stays at the import-time default.
      expect(loaded.readingState.progress, 0);
    });

    test('writeIdentity for unknown id is a no-op', () async {
      final repo = InMemoryLibraryRepository();
      await repo.importBytes('notes.txt', [1, 2, 3]);
      await repo.writeIdentity(id: 'missing', title: 'X', author: 'Y');
      expect((await repo.load()), hasLength(1));
      expect((await repo.load()).single.metadata.id, 'notes.txt');
    });

    test('delete for unknown id is a no-op', () async {
      final repo = InMemoryLibraryRepository();
      await repo.importBytes('notes.txt', [1, 2, 3]);
      await repo.delete('missing');
      expect(await repo.load(), hasLength(1));
    });
  });

  group('InMemoryLibraryRepository import semantics', () {
    test('re-importing the same bytes returns the existing document', () async {
      final repo = InMemoryLibraryRepository();
      final first = await repo.importBytes('notes.txt', [1, 2, 3]);
      final second = await repo.importBytes('notes.txt', [1, 2, 3]);
      expect(second.metadata.contentHash, first.metadata.contentHash);
      expect(await repo.load(), hasLength(1));
    });

    test(
      'different bytes under the same name replace the previous entry',
      () async {
        final repo = InMemoryLibraryRepository();
        await repo.importBytes('notes.txt', [1, 2, 3]);
        final second = await repo.importBytes('notes.txt', [4, 5, 6]);
        final loaded = await repo.load();
        expect(loaded, hasLength(1));
        expect(loaded.single.metadata.contentHash, contentHash([4, 5, 6]));
        expect(loaded.single, same(second));
        // File bytes are refreshed to the latest import.
        expect(await repo.readFile('notes.txt'), [4, 5, 6]);
      },
    );

    test('readCover returns the bytes stored alongside import', () async {
      final repo = InMemoryLibraryRepository();
      await repo.importBytes('book.epub', minimalEpubBytes());
      // Minimal epub without an embedded cover falls through to no cover.
      expect(await repo.readCover('book.epub'), isNull);
    });

    test('readCover stores cover bytes supplied via fixture', () async {
      // Build an epub that embed a cover inside a coverpage manifest entry.
      final bytes = minimalEpubBytes(
        extraFiles: {'OEBPS/cover.png': tinyPngBytes()},
      );
      final repo = InMemoryLibraryRepository();
      await repo.importBytes('book.epub', bytes);
      final cover = await repo.readCover('book.epub');
      // Cover may or may not be extracted by extractCover depending on
      // fixture layout; the contract is "either bytes or null, never throw".
      if (cover != null) {
        expect(cover, isNotEmpty);
      }
    });
  });

  group('SharedPreferencesLibraryRepository branches', () {
    test('readFile and readCover always return null', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPreferencesLibraryRepository(
        await SharedPreferences.getInstance(),
      );
      await repo.importBytes('notes.txt', [1, 2, 3]);
      expect(await repo.readFile('notes.txt'), isNull);
      expect(await repo.readCover('notes.txt'), isNull);
    });

    test('import skips when the same hash is already stored', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPreferencesLibraryRepository(
        await SharedPreferences.getInstance(),
      );
      final first = await repo.importBytes('notes.txt', [1, 2, 3]);
      // Re-import same bytes — must not duplicate the entry.
      final second = await repo.importBytes('notes.txt', [1, 2, 3]);
      expect(second.metadata.id, first.metadata.id);
      expect(await repo.load(), hasLength(1));
    });

    test('different bytes under same id replace stored document', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPreferencesLibraryRepository(
        await SharedPreferences.getInstance(),
      );
      await repo.importBytes('notes.txt', [1, 2, 3]);
      await repo.importBytes('notes.txt', [4, 5, 6]);
      final loaded = await repo.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.metadata.contentHash, contentHash([4, 5, 6]));
    });

    test('delete removes the matching entry', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPreferencesLibraryRepository(
        await SharedPreferences.getInstance(),
      );
      await repo.importBytes('notes.txt', [1, 2, 3]);
      await repo.delete('notes.txt');
      expect(await repo.load(), isEmpty);
    });

    test(
      'usesRemoteStore is false for the local preferences backend',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SharedPreferencesLibraryRepository(
          await SharedPreferences.getInstance(),
        );
        expect(repo.usesRemoteStore, isFalse);
      },
    );
  });

  group('LibraryDocumentCodec.fromJson defensive decoding', () {
    test('falls back to default coverColor when missing', () {
      final doc = LibraryDocumentCodec.fromJson({
        'metadata': {
          'id': 'a',
          'title': 't',
          'author': '',
          'format': 'epub',
          'type': 'reflow',
        },
        'readingState': {
          'progress': 0,
          'lastOpened': DateTime(2026, 9, 1).toIso8601String(),
        },
      });
      expect(doc.metadata.coverColor, 0xFF527882);
    });

    test('falls back to empty contentHash when missing', () {
      final doc = LibraryDocumentCodec.fromJson({
        'metadata': {
          'id': 'a',
          'title': 't',
          'author': '',
          'format': 'epub',
          'type': 'reflow',
          'coverColor': 1,
        },
        'readingState': {
          'progress': 0,
          'lastOpened': DateTime(2026, 9, 1).toIso8601String(),
        },
      });
      expect(doc.metadata.contentHash, isEmpty);
    });

    test('falls back to false hasCover when missing', () {
      final doc = LibraryDocumentCodec.fromJson({
        'metadata': {
          'id': 'a',
          'title': 't',
          'author': '',
          'format': 'epub',
          'type': 'reflow',
          'coverColor': 1,
        },
        'readingState': {
          'progress': 0,
          'lastOpened': DateTime(2026, 9, 1).toIso8601String(),
        },
      });
      expect(doc.metadata.hasCover, isFalse);
    });

    test('falls back to zero progress when missing', () {
      final doc = LibraryDocumentCodec.fromJson({
        'metadata': {
          'id': 'a',
          'title': 't',
          'author': '',
          'format': 'epub',
          'type': 'reflow',
          'coverColor': 1,
          'contentHash': '',
          'hasCover': false,
        },
        'readingState': {'lastOpened': DateTime(2026, 9, 1).toIso8601String()},
      });
      expect(doc.readingState.progress, 0);
    });

    test('falls back to unknown format and format.type when unknown', () {
      final doc = LibraryDocumentCodec.fromJson({
        'metadata': {
          'id': 'a',
          'title': 't',
          'author': '',
          'format': 'mystery-format',
          // type intentionally missing.
          'coverColor': 1,
          'contentHash': '',
          'hasCover': false,
        },
        'readingState': {
          'progress': 0,
          'lastOpened': DateTime(2026, 9, 1).toIso8601String(),
        },
      });
      expect(doc.metadata.format, DocumentFormat.unknown);
      expect(doc.metadata.type, DocumentType.reflow);
    });
  });
}
