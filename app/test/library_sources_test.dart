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

  test('progressive scan starts and consumes server batches', () async {
    final requested = <String>[];
    final progress = <(int, int)>[];
    final client = MockClient((request) async {
      requested.add(request.url.path);
      if (request.url.path == '/v1/library/scan/start') {
        expect(request.body, contains('"path":"D:/books"'));
        return http.Response('{"session_id":"scan-1","total":3}', 200);
      }
      expect(request.url.path, '/v1/library/scan/next');
      expect(request.body, contains('"session_id":"scan-1"'));
      if (requested.where((path) => path.endsWith('/next')).length == 1) {
        return http.Response(
          '{"session_id":"scan-1","total":3,"processed":2,'
          '"imported":2,"skipped":0,"done":false}',
          200,
        );
      }
      return http.Response(
        '{"session_id":"scan-1","total":3,"processed":1,'
        '"imported":1,"skipped":0,"done":true}',
        200,
      );
    });

    final result = await scanLibraryFolderProgressive(
      HttpLibraryRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      ),
      'D:/books',
      batchSize: 2,
      onProgress: (processed, total) => progress.add((processed, total)),
    );

    expect(requested, [
      '/v1/library/scan/start',
      '/v1/library/scan/next',
      '/v1/library/scan/next',
    ]);
    expect(progress, [(2, 3), (3, 3)]);
    expect(result.imported, 3);
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

  test(
    'folder metadata sync posts the folder and parses merge counts',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/library/metadata/folder/sync');
        expect(request.body, contains('"path":"D:/books"'));
        return http.Response(
          '{"remote_found":true,"documents":3,"progress_updated":2,'
          '"annotations_updated":1,"unmatched_remote":4}',
          200,
        );
      });

      final result = await syncLibraryMetadataFolder(
        HttpLibraryRepository(
          baseUrl: 'http://127.0.0.1:8787',
          httpClient: client,
        ),
        'D:/books',
      );

      expect(result.remoteFound, isTrue);
      expect(result.documents, 3);
      expect(result.progressUpdated, 2);
      expect(result.annotationsUpdated, 1);
      expect(result.unmatchedRemote, 4);
    },
  );

  test('webdav metadata sync keeps an unset URL server-side', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/library/metadata/webdav/sync');
      expect(request.body, isNot(contains('base_url')));
      return http.Response(
        '{"remote_found":false,"documents":1,"progress_updated":0,'
        '"annotations_updated":0,"unmatched_remote":0}',
        200,
      );
    });

    final result = await syncLibraryMetadataWebDav(
      HttpLibraryRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      ),
      baseUrl: ' ',
    );

    expect(result.remoteFound, isFalse);
    expect(result.documents, 1);
  });

  test('S3 metadata sync posts credentials only to the local server', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/library/metadata/s3/sync');
      expect(request.body, contains('"bucket":"books"'));
      expect(request.body, contains('"access_key":"key"'));
      expect(request.body, isNot(contains('s3.example.test')));
      return http.Response(
        '{"remote_found":true,"documents":1,"progress_updated":1,'
        '"annotations_updated":1,"unmatched_remote":0}',
        200,
      );
    });

    final result = await syncLibraryMetadataS3(
      HttpLibraryRepository(
        baseUrl: 'http://127.0.0.1:8787',
        httpClient: client,
      ),
      endpoint: ' ',
      region: 'us-east-1',
      bucket: 'books',
      prefix: 'library',
      accessKey: 'key',
      secretKey: 'secret',
    );

    expect(result.remoteFound, isTrue);
    expect(result.annotationsUpdated, 1);
  });

  test('scan throws when the server returns a non-200 status', () async {
    final client = MockClient((request) async {
      return http.Response('server error', 500);
    });
    expect(
      () => scanLibraryFolder(
        HttpLibraryRepository(
          baseUrl: 'http://127.0.0.1:8787',
          httpClient: client,
        ),
        '/data/books',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('sync throws when the server returns a non-200 status', () async {
    final client = MockClient((request) async {
      return http.Response('sync error', 502);
    });
    expect(
      () => syncLibraryWebDav(
        HttpLibraryRepository(
          baseUrl: 'http://127.0.0.1:8787',
          httpClient: client,
        ),
        baseUrl: 'https://webdav.example.com',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('watch throws when the server returns a non-200 status', () async {
    final client = MockClient((request) async {
      return http.Response('watch error', 503);
    });
    expect(
      () => watchLibraryFolder(
        HttpLibraryRepository(
          baseUrl: 'http://127.0.0.1:8787',
          httpClient: client,
        ),
        '/data/books',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
