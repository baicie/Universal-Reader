import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app/core/http_library_repository.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';

void main() {
  test('parses rust library documents including fixed-page types', () {
    final document = LibraryDocumentCodec.fromServiceJson({
      'id': '1-0',
      'file_name': 'Design.pdf',
      'stored_name': '1-0.pdf',
      'title': 'Design',
      'author': '',
      'format': 'pdf',
      'document_type': 'fixed_page',
      'size': 12,
      'cover_color': 0xFF4F7C8A,
      'progress': 0.25,
      'last_opened_ms': 0,
    });

    expect(document.metadata.id, '1-0');
    expect(document.metadata.title, 'Design');
    expect(document.metadata.author, '本地书库');
    expect(document.metadata.format, DocumentFormat.pdf);
    expect(document.metadata.type, DocumentType.fixedPage);
    expect(document.readingState.progress, 0.25);
  });

  test('loads and imports documents through the rust library API', () async {
    final requests = <http.BaseRequest>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/v1/library/documents') {
        return http.Response(
          '{"documents":[{"id":"9-0","file_name":"a.epub","title":"a","author":"","format":"epub","document_type":"reflow","size":4,"cover_color":1,"progress":0,"last_opened_ms":0}]}',
          200,
        );
      }
      if (request.method == 'POST' && request.url.path == '/v1/library/files') {
        return http.Response(
          '{"id":"9-1","file_name":"b.txt","title":"b","author":"","format":"txt","document_type":"reflow","size":5,"cover_color":1,"progress":0,"last_opened_ms":1}',
          201,
        );
      }
      if (request.method == 'PATCH') {
        return http.Response(
          '{"id":"9-0","file_name":"a.epub","title":"a","author":"","format":"epub","document_type":"reflow","size":4,"cover_color":1,"progress":0.5,"last_opened_ms":2}',
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/v1/library/documents/9-1/file') {
        return http.Response('hello', 200);
      }
      return http.Response('missing', 404);
    });

    final repository = HttpLibraryRepository(
      baseUrl: 'http://127.0.0.1:8787',
      httpClient: client,
    );

    final loaded = await repository.load();
    expect(loaded.single.metadata.title, 'a');

    final imported = await repository.importBytes('b.txt', [1, 2, 3]);
    expect(imported.metadata.id, '9-1');
    expect(imported.metadata.format, DocumentFormat.txt);

    await repository.writeReadingState(
      id: '9-0',
      progress: 0.5,
      lastOpened: DateTime.now(),
    );
    expect(await repository.readFile('9-1'), utf8.encode('hello'));

    expect(requests.map((request) => request.method).toList(), [
      'GET',
      'POST',
      'PATCH',
      'GET',
    ]);
  });
}
