import 'dart:convert';
import 'dart:io';

import 'package:app/core/http_library_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a [MockClient] whose response depends on the request URL path.
/// Anything not in [responses] falls back to [defaultResponse] (defaults to
/// 404 so unhandled paths fail the test loudly).
http.Client _scripted(
  Map<String, http.Response Function(http.Request)> responses, {
  http.Response? defaultResponse,
}) {
  return MockClient((request) async {
    for (final entry in responses.entries) {
      if (request.url.path.endsWith(entry.key)) {
        return entry.value(request);
      }
    }
    return defaultResponse ?? http.Response('not found', 404);
  });
}

/// Stub path_provider's platform channel with a deterministic temp dir so
/// `openLocalLibrary` can run inside the VM test environment. The fallback
/// path inside resolveLibraryRepository calls
/// `getApplicationSupportDirectory()`, which without a real Android/iOS
/// channel would throw MissingPluginException and make the test fail.
///
/// path_provider's method-channel surface is described in
/// `path_provider_platform_interface/lib/src/method_channel_path_provider.dart`.
/// Method names are the public names (e.g. `getApplicationSupportDirectory`),
/// not the property names on `PathProviderPlatform`.
void _installPathProviderStub() {
  final tempDir = Directory.systemTemp.createTempSync('ur_test_path_provider');
  Future<String?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getApplicationSupportDirectory':
      case 'getApplicationDocumentsDirectory':
      case 'getTemporaryDirectory':
      case 'getApplicationCacheDirectory':
      case 'getExternalStorageDirectory':
      case 'getDownloadsDirectory':
      case 'getLibraryDirectory':
        return tempDir.path;
      default:
        return null;
    }
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    handle,
  );
}

void main() {
  setUp(() {
    // Fallback in resolveLibraryRepository eventually instantiates
    // SharedPreferences via the platform channel mock.
    SharedPreferences.setMockInitialValues({});
  });

  group('HttpLibraryRepository', () {
    test('usesRemoteStore is true', () {
      final repo = HttpLibraryRepository(baseUrl: 'http://127.0.0.1:8787');
      expect(repo.usesRemoteStore, isTrue);
    });

    test('uri trims a trailing slash on the base URL', () {
      final repo = HttpLibraryRepository(baseUrl: 'http://x/');
      expect(repo.uri('/v1/library/documents').toString(),
          'http://x/v1/library/documents');
    });

    test('load() decodes the documents list', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents': (_) => http.Response(
                jsonEncode({
                  'documents': [
                    {
                      'id': 'a',
                      'title': 'Alpha',
                      'author': 'A',
                      'format': 'epub',
                      'document_type': 'reflow',
                      'cover_color': 1,
                      'content_hash': 'h',
                      'has_cover': false,
                      'progress': 0.5,
                      'last_opened_ms': 0,
                    },
                  ],
                }),
                200,
              ),
        }),
      );
      final docs = await repo.load();
      expect(docs, hasLength(1));
      expect(docs.first.metadata.title, 'Alpha');
      expect(docs.first.readingState.progress, 0.5);
    });

    test('load() returns [] when the payload is not an object', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents':
              (_) => http.Response(jsonEncode(['nope']), 200),
        }),
      );
      expect(await repo.load(), isEmpty);
    });

    test('load() returns [] when documents key is not a list', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents':
              (_) => http.Response(jsonEncode({'documents': {}}), 200),
        }),
      );
      expect(await repo.load(), isEmpty);
    });

    test('load() throws FormatException on non-200', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents': (_) => http.Response('boom', 500),
        }),
      );
      await expectLater(repo.load(), throwsFormatException);
    });

    test('importBytes returns the new document on 201', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/files': (req) {
            expect(req.method, 'POST');
            return http.Response(
              jsonEncode({
                'id': 'b',
                'title': 'Bravo',
                'author': 'B',
                'format': 'pdf',
                'document_type': 'fixed_page',
                'cover_color': 2,
                'content_hash': 'h2',
                'has_cover': false,
                'progress': 0.0,
                'last_opened_ms': 0,
              }),
              201,
            );
          },
        }),
      );
      final doc = await repo.importBytes('b.pdf', [1, 2, 3]);
      expect(doc.metadata.id, 'b');
      expect(doc.metadata.title, 'Bravo');
    });

    test('importBytes maps 415 to an unsupported-format error', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/files': (_) => http.Response('no', 415),
        }),
      );
      await expectLater(
        repo.importBytes('x.bin', [0]),
        throwsA(isA<FormatException>()),
      );
    });

    test('importBytes throws on unexpected status codes', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/files': (_) => http.Response('no', 503),
        }),
      );
      await expectLater(
        repo.importBytes('x.bin', [0]),
        throwsFormatException,
      );
    });

    test('readFile returns null on 404', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents/missing/file':
              (_) => http.Response('', 404),
        }),
      );
      expect(await repo.readFile('missing'), isNull);
    });

    test('readFile returns bytes on 200', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents/has/file':
              (_) => http.Response.bytes([1, 2, 3], 200),
        }),
      );
      expect(await repo.readFile('has'), [1, 2, 3]);
    });

    test('readFile throws on non-200/404', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents/x/file':
              (_) => http.Response('boom', 403),
        }),
      );
      await expectLater(repo.readFile('x'), throwsFormatException);
    });

    test('readCover returns null on 404', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents/missing/cover':
              (_) => http.Response('', 404),
        }),
      );
      expect(await repo.readCover('missing'), isNull);
    });

    test('readCover returns the bytes on 200', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents/has/cover':
              (_) => http.Response.bytes([9, 8, 7], 200),
        }),
      );
      expect(await repo.readCover('has'), [9, 8, 7]);
    });

    test('readCover throws on unexpected status codes', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents/x/cover':
              (_) => http.Response('boom', 500),
        }),
      );
      await expectLater(repo.readCover('x'), throwsFormatException);
    });

    test('writeReadingState sends JSON with epoch millis and is ok on 200',
        () async {
      late http.Request seen;
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response('', 200);
        }),
      );
      final lastOpened = DateTime.utc(2026, 1, 2, 3, 4, 5);
      await repo.writeReadingState(
        id: 'a',
        progress: 0.42,
        lastOpened: lastOpened,
      );
      expect(seen.method, 'PATCH');
      expect(seen.headers['content-type'], 'application/json');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['progress'], 0.42);
      expect(body['last_opened_ms'], lastOpened.millisecondsSinceEpoch);
    });

    test('writeReadingState throws on non-200', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents/a': (_) => http.Response('nope', 500),
        }),
      );
      await expectLater(
        repo.writeReadingState(
          id: 'a',
          progress: 0,
          lastOpened: DateTime.now(),
        ),
        throwsFormatException,
      );
    });

    test('writeIdentity succeeds on 200', () async {
      late http.Request seen;
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response('', 200);
        }),
      );
      await repo.writeIdentity(id: 'a', title: 't', author: 'au');
      expect(seen.method, 'PATCH');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['title'], 't');
      expect(body['author'], 'au');
    });

    test('writeIdentity throws on non-200', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents/a': (_) => http.Response('nope', 404),
        }),
      );
      await expectLater(
        repo.writeIdentity(id: 'a', title: 't', author: 'au'),
        throwsFormatException,
      );
    });

    test('delete succeeds on 200, 204, or 404', () async {
      for (final code in [200, 204, 404]) {
        final repo = HttpLibraryRepository(
          baseUrl: 'http://x',
          httpClient: _scripted({
            '/v1/library/documents/a': (_) => http.Response('', code),
          }),
        );
        await repo.delete('a');
      }
    });

    test('delete throws on unexpected status codes', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: _scripted({
          '/v1/library/documents/a': (_) => http.Response('nope', 500),
        }),
      );
      await expectLater(repo.delete('a'), throwsFormatException);
    });

    test('save is a no-op (remote server is the source of truth)', () async {
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      await repo.save(const []);
    });

    test('readFile URL-encodes document ids with reserved characters', () async {
      // Document ids often come from filenames; Chinese, spaces, '#' or '%'
      // in an id would otherwise produce an ambiguous URL. Encode the id so
      // the server receives the original characters verbatim.
      late http.Request seen;
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: MockClient((req) async {
          seen = req;
          if (req.url.path.endsWith('/file')) {
            return http.Response.bytes([1, 2, 3], 200);
          }
          return http.Response('', 404);
        }),
      );
      await repo.readFile('书 名 #1.epub');
      expect(seen.url.path, '/v1/library/documents/${Uri.encodeComponent('书 名 #1.epub')}/file');
    });

    test('writeReadingState URL-encodes document ids with reserved characters',
        () async {
      late http.Request seen;
      final repo = HttpLibraryRepository(
        baseUrl: 'http://x',
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response('', 200);
        }),
      );
      await repo.writeReadingState(
        id: 'book with space',
        progress: 0,
        lastOpened: DateTime.utc(2026, 1, 1),
      );
      expect(
        seen.url.path,
        '/v1/library/documents/${Uri.encodeComponent('book with space')}',
      );
    });
  });

  group('resolveLibraryRepository', () {
    setUp(_installPathProviderStub);

    test('returns HttpLibraryRepository on healthy server', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = await resolveLibraryRepository(
        prefs,
        baseUrl: 'http://x',
        httpClient: MockClient((req) async {
          expect(req.url.path, '/health');
          return http.Response('universal-reader-server ok', 200);
        }),
      );
      expect(repo.usesRemoteStore, isTrue);
    });

    test('falls back to local when health probe returns 5xx', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = await resolveLibraryRepository(
        prefs,
        baseUrl: 'http://x',
        httpClient: MockClient((_) async => http.Response('no', 500)),
      );
      expect(repo.usesRemoteStore, isFalse);
    });

    test('falls back to local when health body is unrecognized', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = await resolveLibraryRepository(
        prefs,
        baseUrl: 'http://x',
        httpClient: MockClient(
          (req) async => http.Response('something else', 200),
        ),
      );
      expect(repo.usesRemoteStore, isFalse);
    });

    test('falls back to local when the probe throws', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = await resolveLibraryRepository(
        prefs,
        baseUrl: 'http://x',
        httpClient: MockClient((_) async {
          throw Exception('connection refused');
        }),
      );
      expect(repo.usesRemoteStore, isFalse);
    });

    test('default baseUrl path falls back when no client override is given',
        () async {
      // Pass a custom httpClient; this exercises the `baseUrl ?? libraryBaseUrl()`
      // path without forcing `libraryBaseUrl()` to consult Uri.base.
      final prefs = await SharedPreferences.getInstance();
      final repo = await resolveLibraryRepository(
        prefs,
        httpClient: MockClient((_) async => http.Response('no', 500)),
      );
      expect(repo.usesRemoteStore, isFalse);
    });

    test(
      'falls back to local when no httpClient is provided and the probe fails',
      () async {
        // Pass null httpClient so the `?? http.Client()` branch is exercised.
        // The default client will fail to reach the loopback address inside
        // the test VM and trigger the catch-all fallback.
        final prefs = await SharedPreferences.getInstance();
        final repo = await resolveLibraryRepository(
          prefs,
          baseUrl: 'http://127.0.0.1:1',
          timeout: const Duration(milliseconds: 10),
          httpClient: null,
        );
        expect(repo.usesRemoteStore, isFalse);
      },
    );
  });

  group('libraryBaseUrl', () {
    test('returns the default loopback origin on the VM', () {
      expect(libraryBaseUrl(), 'http://127.0.0.1:8787');
    });
  });
}
