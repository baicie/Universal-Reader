import 'dart:convert';

import 'package:app/core/library_repository.dart';
import 'package:app/features/library/shelf_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('empty favorites do not include seed book ids', () {
    const shelves = LibraryShelves();

    expect(shelves.favoriteIds, isEmpty);
    expect(
      documentMatchesSection(
        section: favoritesSection,
        documentId: 'design',
        progress: 0.37,
        shelves: shelves,
      ),
      isFalse,
    );
  });

  test('toggling favorite does not mark another book', () {
    final shelves = toggleFavorite(const LibraryShelves(), 'notes');

    expect(shelves.favoriteIds, {'notes'});
    expect(
      documentMatchesSection(
        section: favoritesSection,
        documentId: 'notes',
        progress: 0,
        shelves: shelves,
      ),
      isTrue,
    );
    expect(
      documentMatchesSection(
        section: favoritesSection,
        documentId: 'design',
        progress: 0.37,
        shelves: shelves,
      ),
      isFalse,
    );
  });

  test('prune drops unknown ids and keeps empty collections', () {
    final shelves = pruneShelves(
      const LibraryShelves(
        favoriteIds: {'notes', 'ghost'},
        collections: [
          LibraryCollection(
            id: 'c-1',
            name: '今晚读',
            color: 0xFFC69355,
            documentIds: ['notes', 'missing'],
          ),
        ],
      ),
      {'notes'},
    );

    expect(shelves.favoriteIds, {'notes'});
    expect(shelves.collections.single.documentIds, ['notes']);
  });

  test('empty collection names are not created', () {
    expect(
      addCollection(const LibraryShelves(), name: '  ').collections,
      isEmpty,
    );
    expect(
      addCollection(const LibraryShelves(), name: '').collections,
      isEmpty,
    );
  });

  test('unknown collection section is empty, not the whole library', () {
    expect(
      documentMatchesSection(
        section: collectionSection('missing'),
        documentId: 'design',
        progress: 0.37,
        shelves: const LibraryShelves(),
      ),
      isFalse,
    );
  });

  test('corrupt shelves json is an error, not an empty shelf', () {
    expect(() => parseShelves('{not-json'), throwsA(isA<FormatException>()));
  });

  test(
    'shared preferences shelves persist without inventing favorites',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesShelfRepository(
        await SharedPreferences.getInstance(),
      );

      expect((await store.load()).favoriteIds, isEmpty);

      await store.save(toggleFavorite(const LibraryShelves(), 'notes'));

      expect((await store.load()).favoriteIds, {'notes'});
      expect((await store.load()).favoriteIds.contains('design'), isFalse);
    },
  );

  test(
    'http shelves round-trip and treat a missing endpoint as empty',
    () async {
      final requests = <http.BaseRequest>[];
      var stored = '';
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/v1/library/shelves') {
          if (stored.isEmpty) return http.Response('missing', 404);
          return http.Response.bytes(
            utf8.encode(stored),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.method == 'PUT' &&
            request.url.path == '/v1/library/shelves') {
          stored = request.body;
          return http.Response.bytes(
            utf8.encode(stored),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('nope', 500);
      });

      final store = HttpShelfRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      );

      expect((await store.load()).favoriteIds, isEmpty);

      await store.save(
        const LibraryShelves(
          favoriteIds: {'notes'},
          collections: [
            LibraryCollection(
              id: 'c-1',
              name: '今晚读',
              color: 1,
              documentIds: ['notes'],
            ),
          ],
        ),
      );
      final loaded = await store.load();
      expect(loaded.favoriteIds, {'notes'});
      expect(loaded.collections.single.name, '今晚读');
      expect(
        requests.every((item) => item.url.path == '/v1/library/shelves'),
        isTrue,
      );
    },
  );

  group('documentMatchesSection', () {
    const shelves = LibraryShelves(
      favoriteIds: {'fav-1'},
      collections: [
        LibraryCollection(
          id: 'col-1',
          name: 'A',
          color: 0xFFC69355,
          documentIds: ['col-doc'],
        ),
      ],
    );

    test('reading section uses progress between 0 and 1', () {
      expect(
        documentMatchesSection(
          section: 'reading',
          documentId: 'x',
          progress: 0,
          shelves: shelves,
        ),
        isFalse,
      );
      expect(
        documentMatchesSection(
          section: 'reading',
          documentId: 'x',
          progress: 0.5,
          shelves: shelves,
        ),
        isTrue,
      );
      expect(
        documentMatchesSection(
          section: 'reading',
          documentId: 'x',
          progress: 1,
          shelves: shelves,
        ),
        isFalse,
      );
    });

    test('collection section returns true only for matching collections', () {
      expect(
        documentMatchesSection(
          section: collectionSection('col-1'),
          documentId: 'col-doc',
          progress: 0,
          shelves: shelves,
        ),
        isTrue,
      );
      expect(
        documentMatchesSection(
          section: collectionSection('col-1'),
          documentId: 'fav-1',
          progress: 0,
          shelves: shelves,
        ),
        isFalse,
      );
    });

    test('an empty section matches every document', () {
      expect(
        documentMatchesSection(
          section: '',
          documentId: 'design',
          progress: 0,
          shelves: const LibraryShelves(),
        ),
        isTrue,
      );
    });
  });

  group('toggleFavorite', () {
    test('an empty document id is ignored', () {
      final next = toggleFavorite(const LibraryShelves(), '');
      expect(next.favoriteIds, isEmpty);
    });

    test('toggling again removes the favorite', () {
      final first = toggleFavorite(const LibraryShelves(), 'notes');
      final second = toggleFavorite(first, 'notes');
      expect(second.favoriteIds, isEmpty);
    });
  });

  group('addCollection', () {
    test('clips names longer than the cap', () {
      final next = addCollection(
        const LibraryShelves(),
        name: 'x' * (maxCollectionName + 10),
      );
      expect(next.collections.single.name.length, maxCollectionName);
    });

    test('refuses to exceed the maximum number of collections', () {
      var shelves = const LibraryShelves();
      for (var i = 0; i < maxCollections; i++) {
        shelves = addCollection(shelves, name: 'col $i');
      }
      final overflow = addCollection(shelves, name: 'one more');
      expect(overflow.collections.length, maxCollections);
      expect(overflow.collections.last.name, 'col ${maxCollections - 1}');
    });

    test('honours an explicit color override', () {
      final next = addCollection(
        const LibraryShelves(),
        name: 'custom',
        color: 0xFF112233,
      );
      expect(next.collections.single.color, 0xFF112233);
    });
  });

  group('collection membership', () {
    final shelves = const LibraryShelves(
      collections: [
        LibraryCollection(
          id: 'col-1',
          name: 'A',
          color: 0xFFC69355,
          documentIds: ['doc-1'],
        ),
      ],
    );

    test('addToCollection appends and is idempotent', () {
      final once = addToCollection(shelves, 'col-1', 'doc-2');
      expect(once.collections.single.documentIds, ['doc-1', 'doc-2']);
      final again = addToCollection(once, 'col-1', 'doc-2');
      expect(again.collections.single.documentIds, ['doc-1', 'doc-2']);
    });

    test('addToCollection ignores empty ids', () {
      final next = addToCollection(shelves, '', 'doc-2');
      expect(next.collections.single.documentIds, ['doc-1']);
      final next2 = addToCollection(shelves, 'col-1', '');
      expect(next2.collections.single.documentIds, ['doc-1']);
    });

    test('removeFromCollection drops a single document', () {
      final next = removeFromCollection(shelves, 'col-1', 'doc-1');
      expect(next.collections.single.documentIds, isEmpty);
    });

    test('toggleInCollection flips membership', () {
      final added = toggleInCollection(shelves, 'col-1', 'doc-2');
      expect(added.collections.single.documentIds, ['doc-1', 'doc-2']);
      final removed = toggleInCollection(added, 'col-1', 'doc-2');
      expect(removed.collections.single.documentIds, ['doc-1']);
    });

    test('removeCollection drops the named collection', () {
      final next = removeCollection(
        const LibraryShelves(
          collections: [
            LibraryCollection(id: 'a', name: 'A', color: 1),
            LibraryCollection(id: 'b', name: 'B', color: 2),
          ],
        ),
        'a',
      );
      expect(next.collections.map((c) => c.id), ['b']);
    });
  });

  group('LibraryShelves equality', () {
    test('two collections with the same data are equal', () {
      final a = const LibraryShelves(favoriteIds: {'x'});
      final b = const LibraryShelves(favoriteIds: {'x'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different favorite sets are not equal', () {
      const a = LibraryShelves(favoriteIds: {'x'});
      const b = LibraryShelves(favoriteIds: {'y'});
      expect(a, isNot(b));
    });
  });

  group('LibraryCollection equality', () {
    test('two collections with the same data are equal and share hash', () {
      const a = LibraryCollection(
        id: 'c-1',
        name: 'A',
        color: 0xFFC69355,
        documentIds: ['doc-1', 'doc-2'],
      );
      const b = LibraryCollection(
        id: 'c-1',
        name: 'A',
        color: 0xFFC69355,
        documentIds: ['doc-1', 'doc-2'],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('documentIds of equal length but different order are not equal', () {
      // Forces the inner loop inside `_sameList` to run on a non-trivial
      // mismatch (lengths equal, contents diverge).
      const a = LibraryCollection(
        id: 'c-1',
        name: 'A',
        color: 0xFFC69355,
        documentIds: ['doc-1', 'doc-2'],
      );
      const b = LibraryCollection(
        id: 'c-1',
        name: 'A',
        color: 0xFFC69355,
        documentIds: ['doc-2', 'doc-1'],
      );
      expect(a, isNot(b));
    });

    test('different ids, names, or colors are not equal', () {
      const base = LibraryCollection(
        id: 'c-1',
        name: 'A',
        color: 0xFFC69355,
        documentIds: ['doc-1'],
      );
      const diffId = LibraryCollection(
        id: 'c-2',
        name: 'A',
        color: 0xFFC69355,
        documentIds: ['doc-1'],
      );
      const diffName = LibraryCollection(
        id: 'c-1',
        name: 'B',
        color: 0xFFC69355,
        documentIds: ['doc-1'],
      );
      const diffColor = LibraryCollection(
        id: 'c-1',
        name: 'A',
        color: 0xFF000000,
        documentIds: ['doc-1'],
      );
      expect(base, isNot(diffId));
      expect(base, isNot(diffName));
      expect(base, isNot(diffColor));
    });
  });

  group('LibraryCollection.copyWith', () {
    test('omitting documentIds keeps the original list', () {
      // Verifies the `documentIds ?? this.documentIds` fallback branch.
      const collection = LibraryCollection(
        id: 'c-1',
        name: 'A',
        color: 0xFFC69355,
        documentIds: ['doc-1', 'doc-2'],
      );
      final next = collection.copyWith();
      expect(next.documentIds, collection.documentIds);
      expect(next.documentIds, ['doc-1', 'doc-2']);
    });
  });

  group('multi-collection membership', () {
    const shelves = LibraryShelves(
      collections: [
        LibraryCollection(
          id: 'col-1',
          name: 'A',
          color: 0xFFC69355,
          documentIds: ['doc-1'],
        ),
        LibraryCollection(
          id: 'col-2',
          name: 'B',
          color: 0xFF6C9EB4,
          documentIds: ['doc-2'],
        ),
      ],
    );

    test('addToCollection touches only the matching collection, '
        'leaving the others untouched', () {
      final next = addToCollection(shelves, 'col-1', 'doc-3');
      expect(next.collections, hasLength(2));
      expect(next.collections.firstWhere((c) => c.id == 'col-1').documentIds, [
        'doc-1',
        'doc-3',
      ]);
      // The other collection must be the exact same instance (untouched).
      final untouched = shelves.collections.firstWhere((c) => c.id == 'col-2');
      expect(
        identical(
          next.collections.firstWhere((c) => c.id == 'col-2'),
          untouched,
        ),
        isTrue,
      );
    });

    test('removeFromCollection touches only the matching collection, '
        'leaving the others untouched', () {
      final next = removeFromCollection(shelves, 'col-1', 'doc-1');
      expect(next.collections, hasLength(2));
      expect(
        next.collections.firstWhere((c) => c.id == 'col-1').documentIds,
        isEmpty,
      );
      // The other collection's documentIds stay intact.
      expect(next.collections.firstWhere((c) => c.id == 'col-2').documentIds, [
        'doc-2',
      ]);
    });
  });

  group('LibraryCollection JSON', () {
    test('round-trips through toServiceJson / fromJson', () {
      const original = LibraryCollection(
        id: 'c-1',
        name: '今晚读',
        color: 0xFFC69355,
        documentIds: ['notes', 'design'],
      );
      final decoded = LibraryCollection.fromJson(original.toServiceJson());
      expect(decoded, original);
    });

    test('fromJson handles documentIds snake_case and empty ids', () {
      final collection = LibraryCollection.fromJson({
        'id': 'c-1',
        'name': 'A',
        'color': 1,
        'document_ids': ['notes', '', 'design'],
      });
      expect(collection.documentIds, ['notes', 'design']);
    });

    test('fromJson falls back to the first palette colour', () {
      final collection = LibraryCollection.fromJson({'id': 'c-1', 'name': 'A'});
      expect(collection.color, collectionColors.first);
      expect(collection.documentIds, isEmpty);
    });
  });

  group('parseShelves', () {
    test('throws when the value is not a map', () {
      expect(() => parseShelves(['not', 'a', 'map']), throwsFormatException);
    });

    test('ignores collection with a missing id (same pattern as annotation id)', () {
      final shelves = parseShelves({
        'favorites': ['notes'],
        'collections': [
          {'id': 'c-1', 'name': 'A', 'color': 1, 'document_ids': []},
          {'name': 'no-id-collection'}, // missing id
        ],
      });
      // The collection with no id must not appear — otherwise the empty string
      // id would corrupt shelf operations.
      expect(shelves.collections.length, 1);
      expect(shelves.collections.single.id, 'c-1');
    });

    test('ignores a collection entry whose factory throws', () {
      final shelves = parseShelves({
        'collections': [
          {'id': 'c-1', 'name': 'A', 'color': 1, 'document_ids': []},
          // name as an int causes `as String?` to throw.
          {'id': 'c-2', 'name': 42, 'color': 1, 'document_ids': []},
        ],
      });
      expect(shelves.collections.length, 1);
      expect(shelves.collections.single.id, 'c-1');
    });

    test('ignores non-string favorite ids and non-string collection ids', () {
      final shelves = parseShelves({
        'favorites': ['notes', 42, null, ''],
        'collections': [
          {
            'id': 'c-1',
            'name': 'A',
            'color': 1,
            'document_ids': ['notes'],
          },
          'not a map',
        ],
      });
      expect(shelves.favoriteIds, {'notes'});
      expect(shelves.collections.single.id, 'c-1');
    });
  });

  group('ShelfRepository implementations', () {
    test(
      'SharedPreferencesShelfRepository returns empty for empty value',
      () async {
        SharedPreferences.setMockInitialValues({
          'universal_reader.shelves.v1': '',
        });
        final repo = SharedPreferencesShelfRepository(
          await SharedPreferences.getInstance(),
        );
        final shelves = await repo.load();
        expect(shelves.favoriteIds, isEmpty);
      },
    );

    test(
      'HttpShelfRepository strips a trailing slash on the base URL',
      () async {
        late http.Request seen;
        final client = MockClient((req) async {
          seen = req;
          return http.Response('missing', 404);
        });
        final repo = HttpShelfRepository(
          baseUrl: 'http://127.0.0.1:8787/',
          httpClient: client,
        );
        await repo.load();
        expect(seen.url.toString(), 'http://127.0.0.1:8787/v1/library/shelves');
      },
    );

    test('HttpShelfRepository throws on non-200 non-404 responses', () async {
      final client = MockClient((_) async => http.Response('no', 503));
      final repo = HttpShelfRepository(baseUrl: 'http://x', httpClient: client);
      await expectLater(repo.load(), throwsFormatException);
    });

    test('HttpShelfRepository throws when the PUT fails', () async {
      final client = MockClient((_) async => http.Response('no', 500));
      final repo = HttpShelfRepository(baseUrl: 'http://x', httpClient: client);
      await expectLater(
        repo.save(const LibraryShelves()),
        throwsFormatException,
      );
    });
  });

  group('resolveShelfRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'falls back to SharedPreferencesShelfRepository for any other library',
      () async {
        final prefs = await SharedPreferences.getInstance();
        // A repository that is neither HttpLibraryRepository nor
        // SqliteLibraryRepository (e.g. WebLibraryRepository or an
        // InMemoryLibraryRepository used in tests) must degrade gracefully
        // to the SharedPreferences-backed shelves instead of throwing.
        final repo = resolveShelfRepository(InMemoryLibraryRepository(), prefs);
        expect(repo, isA<SharedPreferencesShelfRepository>());
      },
    );
  });
}
