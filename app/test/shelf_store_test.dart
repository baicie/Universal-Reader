import 'dart:convert';

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
}
