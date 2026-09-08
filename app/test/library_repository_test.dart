import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/epub_fixture.dart';
import 'support/fb2_fixture.dart';

void main() {
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
}
