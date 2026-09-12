import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/web_library_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';

void main() {
  test('usesRemoteStore is false even though it persists to SharedPreferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = WebPersistentLibraryRepository(
      await SharedPreferences.getInstance(),
    );
    expect(repo.usesRemoteStore, isFalse);
  });

  test('importBytes writes the file bytes under a per-id key', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = WebPersistentLibraryRepository(
      await SharedPreferences.getInstance(),
    );

    await repo.importBytes('notes.txt', [1, 2, 3]);
    expect(await repo.readFile('notes.txt'), [1, 2, 3]);
  });

  test('importBytes does not write a cover key for plain text', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = WebPersistentLibraryRepository(prefs);

    await repo.importBytes('notes.txt', [1, 2, 3]);
    final coverKey = 'universal_reader.covers.v1.notes.txt';
    expect(prefs.getString(coverKey), isNull);
  });

  test('importBytes writes a base64 cover key when cover bytes are provided',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = WebPersistentLibraryRepository(prefs);

    // An epub with an OEBPS/cover.png entry triggers extractCover → the
    // cover != null branch persists a `covers.v1.<id>` key.
    final bytes = minimalEpubBytes(extraFiles: {
      'OEBPS/cover.png': tinyPngBytes(),
    });
    await repo.importBytes('cover.epub', bytes);
    final coverKey = 'universal_reader.covers.v1.cover.epub';
    expect(prefs.getString(coverKey), isNotNull);
    expect(await repo.readCover('cover.epub'), isNotNull);
  });

  test('readFile returns null when no bytes were ever stored', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = WebPersistentLibraryRepository(
      await SharedPreferences.getInstance(),
    );
    expect(await repo.readFile('missing'), isNull);
  });

  test('readCover returns null when no cover was ever stored', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = WebPersistentLibraryRepository(
      await SharedPreferences.getInstance(),
    );
    expect(await repo.readCover('missing'), isNull);
  });

  test('importBytes with duplicate content returns the existing record',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = WebPersistentLibraryRepository(
      await SharedPreferences.getInstance(),
    );

    final first = await repo.importBytes('notes.txt', [1, 2, 3]);
    final second = await repo.importBytes('notes.txt', [1, 2, 3]);
    expect(second.metadata.id, first.metadata.id);
    expect((await repo.load()), hasLength(1));
  });

  test('writeReadingState updates the catalog without touching the bytes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = WebPersistentLibraryRepository(prefs);

    await repo.importBytes('notes.txt', [1, 2, 3]);
    final beforeBytes = await repo.readFile('notes.txt');

    await repo.writeReadingState(
      id: 'notes.txt',
      progress: 0.5,
      lastOpened: DateTime.utc(2026, 1, 1),
    );
    expect(await repo.readFile('notes.txt'), beforeBytes);
    final loaded = await repo.load();
    expect(loaded.single.readingState.progress, 0.5);
  });

  test('writeIdentity updates the catalog and leaves bytes untouched',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = WebPersistentLibraryRepository(prefs);

    await repo.importBytes('notes.txt', [1, 2, 3]);

    await repo.writeIdentity(
      id: 'notes.txt',
      title: 'Renamed',
      author: 'New Author',
    );
    expect(await repo.readFile('notes.txt'), [1, 2, 3]);
    final loaded = await repo.load();
    expect(loaded.single.metadata.title, 'Renamed');
    expect(loaded.single.metadata.author, 'New Author');
  });

  test('delete clears the catalog entry plus the file and cover keys',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = WebPersistentLibraryRepository(prefs);

    await repo.importBytes('notes.txt', [1, 2, 3]);
    // Manually plant a cover key so we can verify it is wiped on delete.
    await prefs.setString(
      'universal_reader.covers.v1.notes.txt',
      'cHJldGVuZCBjb3Zlcg==',
    );
    expect(await repo.readCover('notes.txt'), isNotNull);

    await repo.delete('notes.txt');

    expect(await repo.load(), isEmpty);
    expect(await repo.readFile('notes.txt'), isNull);
    expect(await repo.readCover('notes.txt'), isNull);
  });

  test('migrateFromPreferences is a no-op and does not throw', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await WebPersistentLibraryRepository(prefs).migrateFromPreferences(prefs);
    // Subsequent reads still work; nothing was removed.
    final repo = WebPersistentLibraryRepository(prefs);
    expect(await repo.load(), isEmpty);
  });
}
