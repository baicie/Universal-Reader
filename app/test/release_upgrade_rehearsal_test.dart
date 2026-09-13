import 'dart:convert';
import 'dart:io';

import 'package:app/core/library_repository.dart';
import 'package:app/core/persistence_schema.dart';
import 'package:app/core/sqlite_library_repository.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/library/shelf_store.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _fixtureDirectory = 'test/fixtures/release_upgrade/v0.0.1-dev.11';
const _legacyDocumentId = 'legacy.epub';

Map<String, dynamic> _jsonFile(String name) {
  return jsonDecode(File('$_fixtureDirectory/$name').readAsStringSync())
      as Map<String, dynamic>;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('released persistence fixture matches its manifest and source tag', () {
    final manifest = _jsonFile('manifest.json');
    expect(manifest['source_tag'], 'v0.0.1-dev.11');
    expect(
      manifest['source_commit'],
      '74ef6b7104ee0ad0019311b78c96e95876a4a44a',
    );
    expect(manifest['source_version'], '0.0.1-dev.11+12');

    final requestedTag = Platform.environment['PREVIOUS_RELEASE_TAG'];
    if (requestedTag != null && requestedTag.isNotEmpty) {
      expect(manifest['source_tag'], requestedTag);
    }

    final files = manifest['files'] as Map<String, dynamic>;
    for (final entry in files.entries) {
      final digest = sha256.convert(
        File('$_fixtureDirectory/${entry.key}').readAsBytesSync(),
      );
      expect(digest.toString(), entry.value, reason: entry.key);
    }
  });

  test('upgrades and rolls back released shared-preferences data', () async {
    final fixture = _jsonFile('shared_preferences.json');
    SharedPreferences.setMockInitialValues({
      SharedPreferencesLibraryRepository.storageKey: jsonEncode(
        fixture['library'],
      ),
      SharedPreferencesShelfRepository.storageKey: jsonEncode(
        fixture['shelves'],
      ),
      '${SharedPreferencesAnnotationRepository.prefix}$_legacyDocumentId':
          jsonEncode(fixture['annotations']),
      '${SharedPreferencesConversationRepository.storagePrefix}'
          '$_legacyDocumentId': jsonEncode(
        fixture['conversations'],
      ),
    });
    final preferences = await SharedPreferences.getInstance();
    final library = SharedPreferencesLibraryRepository(preferences);
    final shelves = SharedPreferencesShelfRepository(preferences);
    final annotations = SharedPreferencesAnnotationRepository(preferences);
    final conversations = SharedPreferencesConversationRepository(preferences);

    expect((await library.load()).single.metadata.id, _legacyDocumentId);
    expect((await shelves.load()).favoriteIds, {_legacyDocumentId});
    expect(
      (await annotations.load(_legacyDocumentId)).single.note,
      'Read before upgrading',
    );
    expect(
      (await conversations.load(_legacyDocumentId)).single.reply,
      'Legacy answer',
    );

    await library.save(await library.load());
    await shelves.save(await shelves.load());
    await annotations.save(
      _legacyDocumentId,
      await annotations.load(_legacyDocumentId),
    );
    await conversations.save(
      _legacyDocumentId,
      await conversations.load(_legacyDocumentId),
    );

    final versionedLibrary = jsonDecode(
      preferences.getString(
        SharedPreferencesLibraryRepository.versionedStorageKey,
      )!,
    ) as Map<String, dynamic>;
    expect(versionedLibrary['schema_version'], persistenceSchemaVersion);

    await preferences.remove(
      SharedPreferencesLibraryRepository.versionedStorageKey,
    );
    await preferences.remove(
      SharedPreferencesShelfRepository.versionedStorageKey,
    );
    await preferences.remove(
      '${SharedPreferencesAnnotationRepository.versionedPrefix}'
      '$_legacyDocumentId',
    );
    await preferences.remove(
      '${SharedPreferencesConversationRepository.versionedStoragePrefix}'
      '$_legacyDocumentId',
    );

    expect((await library.load()).single.metadata.id, _legacyDocumentId);
    expect((await shelves.load()).favoriteIds, {_legacyDocumentId});
    expect(
      (await annotations.load(_legacyDocumentId)).single.id,
      'note-legacy',
    );
    expect(
      (await conversations.load(_legacyDocumentId)).single.question,
      'What is this?',
    );
  });

  test('upgrades a released SQLite v0 fixture in place', () async {
    final fixture = _jsonFile('sqlite_v0.json');
    final statements = (fixture['statements'] as List).cast<String>();
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    for (final statement in statements) {
      await db.execute(statement);
    }

    await SqliteLibraryRepository.migrate(db);
    final repository = SqliteLibraryRepository(db);
    final versionRows = await db.rawQuery('PRAGMA user_version');
    expect(
      (versionRows.first['user_version'] as num).toInt(),
      persistenceSchemaVersion,
    );
    expect((await repository.load()).single.metadata.id, 'sqlite-legacy.epub');
    expect(
      (await repository.loadAnnotations('sqlite-legacy.epub')).single.note,
      'SQLite note',
    );
    expect(
      (await repository.loadConversations('sqlite-legacy.epub'))!.single.reply,
      'SQLite answer',
    );
  });
}
