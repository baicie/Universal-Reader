import 'package:app/core/http_library_repository.dart';
import 'package:app/core/library_controller.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/features/library/library_sources.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'importNamedBytes copies supported files and skips unknown ones',
    () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
        initialDocuments: const [],
      );
      await controller.load();

      final outcome = await controller.importNamedBytes([
        (name: 'notes.txt', bytes: [1]),
        (name: 'skip.bin', bytes: [2]),
      ]);

      expect(outcome.count, 1);
      expect(controller.documents.single.metadata.title, 'notes');
    },
  );

  test('scan posts the folder path to the local server', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/library/scan');
      expect(request.body, contains('"path":"D:/books"'));
      expect(request.body, isNot(contains('http://evil')));
      return http.Response('{"imported":2,"skipped":1}', 200);
    });

    final result = await scanLibraryFolder(
      HttpLibraryRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      ),
      'D:/books',
    );

    expect(result.imported, 2);
    expect(result.skipped, 1);
  });

  test(
    'webdav import does not let the client pick an arbitrary host when empty',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/library/webdav/import');
        expect(request.body, isNot(contains('base_url')));
        return http.Response('{"imported":0,"skipped":0}', 200);
      });

      final result = await importLibraryWebDav(
        HttpLibraryRepository(
          baseUrl: 'http://127.0.0.1:8787',
          httpClient: client,
        ),
        baseUrl: '  ',
      );
      expect(result.imported, 0);
    },
  );

  test('webdav sync posts to the sync endpoint', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/library/webdav/sync');
      return http.Response('{"imported":1,"skipped":0,"pushed":2}', 200);
    });
    final result = await syncLibraryWebDav(
      HttpLibraryRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      ),
      baseUrl: '',
    );
    expect(result.imported, 1);
    expect(result.pushed, 2);
  });

  test('watch posts the folder path to the local server', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/library/watch');
      expect(request.body, contains('"path":"D:/books"'));
      return http.Response('{"imported":0,"skipped":0}', 200);
    });
    final result = await watchLibraryFolder(
      HttpLibraryRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      ),
      'D:/books',
    );
    expect(result.imported, 0);
  });
}
