import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:app/core/sqlite_library_repository.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/library/shelf_store.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/reader_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'keeps imported bytes after a new connection opens the same file',
    () async {
      final dir = Directory.systemTemp.createTempSync('ur-sqlite-');
      final path = '${dir.path}/library.sqlite';
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final first = await SqliteLibraryRepository.open(path);
      final imported = await first.importBytes(
        'notes.txt',
        Uint8List.fromList('hello sqlite'.codeUnits),
      );
      expect(
        await first.readFile(imported.metadata.id),
        'hello sqlite'.codeUnits,
      );
      await first.close();

      final second = await SqliteLibraryRepository.open(path);
      expect(
        await second.readFile(imported.metadata.id),
        'hello sqlite'.codeUnits,
      );
      expect((await second.load()).single.metadata.title, 'notes');
      await second.close();
    },
  );

  test(
    'returns the existing book when the same bytes are imported again',
    () async {
      final repository = await SqliteLibraryRepository.memory();
      addTearDown(repository.close);
      final first = await repository.importBytes(
        'one.txt',
        Uint8List.fromList('same-bytes'.codeUnits),
      );
      final second = await repository.importBytes(
        'two.txt',
        Uint8List.fromList('same-bytes'.codeUnits),
      );
      expect(second.metadata.id, first.metadata.id);
      expect((await repository.load()), hasLength(1));
    },
  );

  test(
    'migrates a shared-preferences catalog without inventing a seed book',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLibraryRepository.storageKey: '[{"metadata":{"id":"old.txt","title":"old","author":"a","format":"txt","type":"reflow","coverColor":1},"readingState":{"progress":0.2,"lastOpened":"2026-01-01T00:00:00.000Z"}}]',
      });
      final preferences = await SharedPreferences.getInstance();
      final dir = Directory.systemTemp.createTempSync('ur-sqlite-mig-');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final repository = await SqliteLibraryRepository.open(
        '${dir.path}/library.sqlite',
      );
      addTearDown(repository.close);
      await repository.migrateFromPreferences(preferences);
      final loaded = await repository.load();
      expect(loaded.single.metadata.id, 'old.txt');
      expect(await repository.readFile('old.txt'), isNull);
    },
  );

  test('sqlite shelves persist without inventing seed favorites', () async {
    final repository = await SqliteLibraryRepository.memory();
    addTearDown(repository.close);
    final notes = await repository.importBytes(
      'notes.txt',
      Uint8List.fromList('hello shelves'.codeUnits),
    );
    final store = SqliteShelfRepository(repository);
    expect((await store.load()).favoriteIds, isEmpty);

    await store.save(toggleFavorite(const LibraryShelves(), notes.metadata.id));
    final loaded = await store.load();
    expect(loaded.favoriteIds, {notes.metadata.id});
    expect(loaded.favoriteIds.contains('design'), isFalse);
  });

  test('sqlite writeIdentity keeps the file and the renamed title', () async {
    final dir = Directory.systemTemp.createTempSync('ur-sqlite-rename-');
    final path = '${dir.path}/library.sqlite';
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final first = await SqliteLibraryRepository.open(path);
    final notes = await first.importBytes(
      'notes.txt',
      Uint8List.fromList('hello sqlite'.codeUnits),
    );
    await first.writeIdentity(
      id: notes.metadata.id,
      title: '设计笔记',
      author: '某作者',
    );
    await first.close();

    final second = await SqliteLibraryRepository.open(path);
    addTearDown(second.close);
    final loaded = (await second.load()).single;
    expect(loaded.metadata.title, '设计笔记');
    expect(loaded.metadata.author, '某作者');
    expect(await second.readFile(notes.metadata.id), 'hello sqlite'.codeUnits);
  });

  test('deleting a sqlite book drops its bytes and keeps the other', () async {
    final repository = await SqliteLibraryRepository.memory();
    addTearDown(repository.close);
    final notes = await repository.importBytes(
      'notes.txt',
      Uint8List.fromList('hello notes'.codeUnits),
    );
    final other = await repository.importBytes(
      'other.txt',
      Uint8List.fromList('hello other'.codeUnits),
    );
    await repository.saveAnnotations(notes.metadata.id, [
      ReaderAnnotation(
        id: 'n1',
        note: 'only this book',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);

    await repository.delete(notes.metadata.id);

    expect(await repository.readFile(notes.metadata.id), isNull);
    expect(
      await repository.readFile(other.metadata.id),
      'hello other'.codeUnits,
    );
    expect((await repository.load()).single.metadata.id, other.metadata.id);
    expect(await repository.loadAnnotations(notes.metadata.id), isEmpty);
    expect(await repository.loadConversations(notes.metadata.id), isNull);
  });

  test(
    'sqlite conversations stay on one book and survive without prefs',
    () async {
      final repository = await SqliteLibraryRepository.memory();
      addTearDown(repository.close);
      final notes = await repository.importBytes(
        'notes.txt',
        Uint8List.fromList('hello notes'.codeUnits),
      );
      final store = SqliteConversationRepository(repository);
      await store.save(notes.metadata.id, [
        ConversationTurn(
          kind: ReaderToolKind.ask,
          reply: '它在讲留白。',
          createdAt: DateTime.utc(2026, 8, 29),
        ),
      ]);
      expect((await store.load(notes.metadata.id)).single.reply, '它在讲留白。');
      expect(await store.load('other'), isEmpty);

      await repository.delete(notes.metadata.id);
      expect(await store.load(notes.metadata.id), isEmpty);
    },
  );

  test('sqlite readCover returns null when no cover was stored', () async {
    final repository = await SqliteLibraryRepository.memory();
    addTearDown(repository.close);
    final notes = await repository.importBytes(
      'notes.txt',
      Uint8List.fromList('hello cover'.codeUnits),
    );
    expect(await repository.readCover(notes.metadata.id), isNull);
    expect(await repository.readCover('missing'), isNull);
  });

  test(
    'sqlite writeReadingState updates progress without touching the bytes',
    () async {
      final repository = await SqliteLibraryRepository.memory();
      addTearDown(repository.close);
      final notes = await repository.importBytes(
        'notes.txt',
        Uint8List.fromList('hello state'.codeUnits),
      );
      final opened = DateTime.utc(2026, 9, 1);
      await repository.writeReadingState(
        id: notes.metadata.id,
        progress: 0.42,
        lastOpened: opened,
      );
      final loaded = (await repository.load()).single;
      expect(loaded.readingState.progress, 0.42);
      expect(loaded.readingState.lastOpened, opened);
      expect(
        await repository.readFile(notes.metadata.id),
        'hello state'.codeUnits,
      );
    },
  );

  test(
    'sqlite saveAnnotations then loadAnnotations round-trips each field',
    () async {
      final repository = await SqliteLibraryRepository.memory();
      addTearDown(repository.close);
      final notes = await repository.importBytes(
        'notes.txt',
        Uint8List.fromList('hello annotations'.codeUnits),
      );
      final created = DateTime.utc(2026, 8, 29, 12);
      await repository.saveAnnotations(notes.metadata.id, [
        ReaderAnnotation(
          id: 'a1',
          note: '留下批注',
          quote: 'quote body',
          locatorLabel: 'ch1.xhtml#frag',
          source: 'highlight',
          createdAt: created,
        ),
        ReaderAnnotation(
          id: 'a2',
          note: 'second note',
          createdAt: DateTime.utc(2026, 8, 30),
        ),
      ]);
      final loaded = await repository.loadAnnotations(notes.metadata.id);
      expect(loaded, hasLength(2));
      expect(loaded.first.id, 'a1');
      expect(loaded.first.note, '留下批注');
      expect(loaded.first.quote, 'quote body');
      expect(loaded.first.locatorLabel, 'ch1.xhtml#frag');
      expect(loaded.first.source, 'highlight');
      expect(loaded.first.createdAt, created);
      expect(loaded.last.id, 'a2');
      expect(loaded.last.note, 'second note');
    },
  );

  test(
    'SqliteAnnotationRepository delegates load and save to the library',
    () async {
      final repository = await SqliteLibraryRepository.memory();
      addTearDown(repository.close);
      final notes = await repository.importBytes(
        'notes.txt',
        Uint8List.fromList('hello delegation'.codeUnits),
      );
      final store = SqliteAnnotationRepository(repository);
      final created = DateTime.utc(2026, 8, 29);
      await store.save(notes.metadata.id, [
        ReaderAnnotation(id: 'd1', note: 'via repo', createdAt: created),
      ]);
      final loaded = await store.load(notes.metadata.id);
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'd1');
      expect(loaded.single.note, 'via repo');
      expect(loaded.single.createdAt, created);
    },
  );

  group('SqliteLibraryRepository.save', () {
    test('replaces the snapshot and drops missing books', () async {
      final repository = await SqliteLibraryRepository.memory();
      addTearDown(repository.close);
      await repository.importBytes(
        'keep.txt',
        Uint8List.fromList('keep'.codeUnits),
      );
      await repository.importBytes(
        'drop.txt',
        Uint8List.fromList('drop'.codeUnits),
      );
      await repository.saveAnnotations('drop.txt', [
        ReaderAnnotation(
          id: 'orphan',
          note: 'belongs to drop.txt',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);

      final keep = (await repository.load()).firstWhere(
        (item) => item.metadata.id == 'keep.txt',
      );
      await repository.save([keep]);

      final loaded = await repository.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.metadata.id, 'keep.txt');
      expect(await repository.loadAnnotations('drop.txt'), isEmpty);
    });

    test('preserves existing file and cover bytes when saving', () async {
      final repository = await SqliteLibraryRepository.memory();
      addTearDown(repository.close);
      final imported = await repository.importBytes(
        'keep.txt',
        Uint8List.fromList('keep-bytes'.codeUnits),
      );
      final refreshed = LibraryDocument(
        metadata: imported.metadata,
        readingState: ReadingState(
          progress: 0.5,
          lastOpened: DateTime.utc(2026, 9, 1),
        ),
      );
      await repository.save([refreshed]);
      expect(await repository.readFile('keep.txt'), 'keep-bytes'.codeUnits);
    });
  });

  group('SqliteLibraryRepository._documentFromRow defensive decoding', () {
    test('falls back to unknown format and reflow type', () async {
      // Open an in-memory db, run migrations, then poke a row directly to
      // simulate a legacy schema with an unrecognised format / type.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SqliteLibraryRepository.migrate(db);
      addTearDown(db.close);
      await db.insert('documents', {
        'id': 'legacy',
        'title': 'legacy',
        'author': '',
        'format': 'mystery-format',
        'type': 'mystery-type',
        'cover_color': 1,
        'progress': 0.1,
        'last_opened': DateTime.utc(2026, 1, 1).toIso8601String(),
        'file_name': 'legacy',
        'content_hash': '',
      });
      final repository = SqliteLibraryRepository(db);
      final loaded = (await repository.load()).single;
      expect(loaded.metadata.format, DocumentFormat.unknown);
      expect(loaded.metadata.type, DocumentType.reflow);
    });
  });

  test(
    'SqliteConversationRepository fallback loads from another store',
    () async {
      final library = await SqliteLibraryRepository.memory();
      addTearDown(library.close);
      await library.importBytes(
        'notes.txt',
        Uint8List.fromList('conv'.codeUnits),
      );
      final fallback = _StubFallbackConversationRepository([
        ConversationTurn(
          kind: ReaderToolKind.summarize,
          reply: '从 fallback 取回',
          createdAt: DateTime.utc(2026, 8, 29),
        ),
      ]);
      final store = SqliteConversationRepository(library, fallback: fallback);

      final loaded = await store.load('notes.txt');
      expect(loaded, hasLength(1));
      expect(loaded.single.reply, '从 fallback 取回');
      // The fallback result was persisted; a second load should not re-pull.
      expect(fallback.calls, 1);
      final again = await store.load('notes.txt');
      expect(again, hasLength(1));
      expect(fallback.calls, 1);
    },
  );
}

class _StubFallbackConversationRepository implements ConversationRepository {
  _StubFallbackConversationRepository(this._seed);
  final List<ConversationTurn> _seed;
  int calls = 0;

  @override
  Future<List<ConversationTurn>> load(String documentId) async {
    calls++;
    return _seed;
  }

  @override
  Future<void> save(String documentId, List<ConversationTurn> turns) async {}
}
