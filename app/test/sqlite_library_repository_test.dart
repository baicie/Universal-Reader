import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/library_repository.dart';
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
}
