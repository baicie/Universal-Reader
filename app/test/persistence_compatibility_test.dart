import 'dart:convert';

import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:app/core/persistence_schema.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/library/shelf_store.dart';
import 'package:app/features/tools/ai/conversation_store.dart';
import 'package:app/features/tools/reader_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryDocument _document(String id) {
  return LibraryDocument(
    metadata: DocumentMetadata(
      id: id,
      title: id,
      author: '',
      format: DocumentFormat.txt,
      type: DocumentType.reflow,
    ),
    readingState: ReadingState(
      progress: 0.25,
      lastOpened: DateTime.utc(2026, 1, 1),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy payloads decode as schema version one', () {
    final decoded = decodePersistedPayload(const ['legacy'], store: 'test');

    expect(decoded.schemaVersion, 1);
    expect(decoded.payload, const ['legacy']);
    expect(decoded.migrated, isFalse);
  });

  test('known older versions run the migration chain', () {
    final decoded = decodePersistedPayload(
      encodePersistedPayload(schemaVersion: 1, payload: 'old'),
      store: 'test',
      currentVersion: 3,
      migrations: {1: (value) => '$value->2', 2: (value) => '$value->3'},
    );

    expect(decoded.schemaVersion, 3);
    expect(decoded.payload, 'old->2->3');
    expect(decoded.migrated, isTrue);
  });

  test('unknown future versions fail instead of falling back to defaults', () {
    expect(
      () => decodePersistedPayload(
        encodePersistedPayload(schemaVersion: 2, payload: const []),
        store: 'test',
      ),
      throwsA(isA<UnsupportedPersistenceVersionException>()),
    );
  });

  test(
    'library store dual-writes and prefers the versioned envelope',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesLibraryRepository(preferences);
      await repository.save([_document('new.txt')]);

      final versioned = jsonDecode(
        preferences.getString(
          SharedPreferencesLibraryRepository.versionedStorageKey,
        )!,
      ) as Map<String, dynamic>;
      final legacy = jsonDecode(
        preferences.getString(SharedPreferencesLibraryRepository.storageKey)!,
      );
      expect(versioned['schema_version'], persistenceSchemaVersion);
      expect(versioned['payload'], hasLength(1));
      expect(legacy, hasLength(1));

      await preferences.setString(
        SharedPreferencesLibraryRepository.versionedStorageKey,
        jsonEncode(
          encodePersistedPayload(
            schemaVersion: persistenceSchemaVersion,
            payload: [LibraryDocumentCodec.toJson(_document('versioned.txt'))],
          ),
        ),
      );
      await preferences.setString(
        SharedPreferencesLibraryRepository.storageKey,
        jsonEncode([LibraryDocumentCodec.toJson(_document('legacy.txt'))]),
      );
      expect((await repository.load()).single.metadata.id, 'versioned.txt');

      await preferences.remove(
        SharedPreferencesLibraryRepository.versionedStorageKey,
      );
      expect((await repository.load()).single.metadata.id, 'legacy.txt');
    },
  );

  test('annotation store dual-writes and reads legacy data', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAnnotationRepository(preferences);
    const documentId = 'notes.txt';
    await store.save(documentId, [
      ReaderAnnotation(
        id: 'a',
        note: 'new',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);

    expect(
      preferences.getString(
        '${SharedPreferencesAnnotationRepository.versionedPrefix}$documentId',
      ),
      isNotNull,
    );
    expect(
      preferences.getString(
        '${SharedPreferencesAnnotationRepository.prefix}$documentId',
      ),
      isNotNull,
    );

    await preferences.remove(
      '${SharedPreferencesAnnotationRepository.versionedPrefix}$documentId',
    );
    expect((await store.load(documentId)).single.id, 'a');
  });

  test('conversation store dual-writes and reads legacy data', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesConversationRepository(preferences);
    const documentId = 'notes.txt';
    await store.save(documentId, [
      ConversationTurn(
        kind: ReaderToolKind.ask,
        reply: 'answer',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);

    expect(
      preferences.getString(
        '${SharedPreferencesConversationRepository.versionedStoragePrefix}'
        '$documentId',
      ),
      isNotNull,
    );
    expect(
      preferences.getString(
        '${SharedPreferencesConversationRepository.storagePrefix}$documentId',
      ),
      isNotNull,
    );

    await preferences.remove(
      '${SharedPreferencesConversationRepository.versionedStoragePrefix}'
      '$documentId',
    );
    expect((await store.load(documentId)).single.reply, 'answer');
  });

  test('shelf store dual-writes and reads legacy data', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesShelfRepository(preferences);
    await store.save(const LibraryShelves(favoriteIds: {'notes.txt'}));

    expect(
      preferences.getString(
        SharedPreferencesShelfRepository.versionedStorageKey,
      ),
      isNotNull,
    );
    expect(
      preferences.getString(SharedPreferencesShelfRepository.storageKey),
      isNotNull,
    );

    await preferences.remove(
      SharedPreferencesShelfRepository.versionedStorageKey,
    );
    expect((await store.load()).favoriteIds, {'notes.txt'});
  });
}
