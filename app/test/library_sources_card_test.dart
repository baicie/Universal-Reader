import 'dart:async';

import 'package:app/core/http_library_repository.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/library/library_sources_card.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _FakeRemoteRepository implements LibraryRepository {
  const _FakeRemoteRepository();

  @override
  bool get usesRemoteStore => true;

  @override
  Future<List<LibraryDocument>> load() async => [];
  @override
  Future<void> save(List<LibraryDocument> documents) async {}
  @override
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes) async =>
      throw UnimplementedError();
  @override
  Future<List<int>?> readFile(String id) async => null;
  @override
  Future<List<int>?> readCover(String id) async => null;
  @override
  Future<void> writeReadingState({
    required String id,
    required double progress,
    required DateTime lastOpened,
  }) async {}
  @override
  Future<void> writeIdentity({
    required String id,
    required String title,
    required String author,
  }) async {}
  @override
  Future<void> delete(String id) async {}
}

class _FakeLocalRepository implements LibraryRepository {
  @override
  bool get usesRemoteStore => false;
  @override
  Future<List<LibraryDocument>> load() async => [];
  @override
  Future<void> save(List<LibraryDocument> documents) async {}
  @override
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes) async =>
      throw UnimplementedError();
  @override
  Future<List<int>?> readFile(String id) async => null;
  @override
  Future<List<int>?> readCover(String id) async => null;
  @override
  Future<void> writeReadingState({
    required String id,
    required double progress,
    required DateTime lastOpened,
  }) async {}
  @override
  Future<void> writeIdentity({
    required String id,
    required String title,
    required String author,
  }) async {}
  @override
  Future<void> delete(String id) async {}
}

Widget _wrap(Widget child, {required LibraryRepository repository}) {
  return ProviderScope(
    overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('hides itself when the library is local', (tester) async {
    await tester.pumpWidget(
      _wrap(const LibrarySourcesCard(), repository: _FakeLocalRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LibrarySourcesCard), findsOneWidget);
    expect(find.text('Library sources'), findsNothing);
  });

  testWidgets('shows scan + watch fields when the library is remote', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const LibrarySourcesCard(),
        repository: const _FakeRemoteRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Library sources'), findsOneWidget);
    expect(find.text('Scan folder'), findsAtLeastNWidgets(1));
    expect(find.text('Watch folder'), findsOneWidget);
    expect(find.text('Import from WebDAV'), findsOneWidget);
    expect(find.text('Sync WebDAV both ways'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('typing into the folder field records the value', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LibrarySourcesCard(),
        repository: const _FakeRemoteRepository(),
      ),
    );
    await tester.pumpAndSettle();
    final folderField = find.byType(TextField).first;
    await tester.enterText(folderField, '/data/books');
    expect(find.text('/data/books'), findsOneWidget);
  });

  testWidgets(
    'tapping Scan folder triggers a network call to /v1/library/scan',
    (tester) async {
      final spying = _SpyingClient(
        Uri.parse('http://fake/v1/library/scan'),
        http.Response('{"imported":1,"skipped":0}', 200),
      );
      final repo = _FakeHttpRepositoryWithClient(spying);
      await tester.pumpWidget(_wrap(LibrarySourcesCard(), repository: repo));
      await tester.pumpAndSettle();
      final scanButton = find.widgetWithText(OutlinedButton, 'Scan folder');
      await tester.ensureVisible(scanButton);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();
      expect(spying.requestedPaths, contains('/v1/library/scan'));
    },
  );

  testWidgets('displays the error message when scan fails', (tester) async {
    final repo = _FakeHttpRepositoryWithClient(
      _SpyingClient(
        Uri.parse('http://fake/v1/library/scan'),
        http.Response('boom', 500),
      ),
    );
    await tester.pumpWidget(_wrap(LibrarySourcesCard(), repository: repo));
    await tester.pumpAndSettle();
    final scanButton = find.widgetWithText(OutlinedButton, 'Scan folder');
    await tester.ensureVisible(scanButton);
    await tester.tap(scanButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('FormatException'), findsOneWidget);
  });

  testWidgets('disables other action buttons while a scan is in flight', (
    tester,
  ) async {
    final completer = Completer<http.Response>();
    final slow = _CompleterClient(completer.future);
    final repo = _FakeHttpRepositoryWithClient(slow);
    await tester.pumpWidget(_wrap(LibrarySourcesCard(), repository: repo));
    await tester.pumpAndSettle();
    final scanButton = find.widgetWithText(OutlinedButton, 'Scan folder');
    await tester.ensureVisible(scanButton);
    await tester.tap(scanButton);
    await tester.pump();
    final scanBtnWidget = tester.widget<OutlinedButton>(scanButton);
    expect(scanBtnWidget.onPressed, isNull);
    final watchButton = find.widgetWithText(OutlinedButton, 'Watch folder');
    final watchBtnWidget = tester.widget<OutlinedButton>(watchButton);
    expect(watchBtnWidget.onPressed, isNull);
    completer.complete(http.Response('{"imported":0,"skipped":0}', 200));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'tapping Watch folder triggers a network call to /v1/library/watch',
    (tester) async {
      final spying = _SpyingClient(
        Uri.parse('http://fake/v1/library/watch'),
        http.Response('{"imported":0,"skipped":0}', 200),
      );
      final repo = _FakeHttpRepositoryWithClient(spying);
      await tester.pumpWidget(_wrap(LibrarySourcesCard(), repository: repo));
      await tester.pumpAndSettle();
      final watchButton = find.widgetWithText(OutlinedButton, 'Watch folder');
      await tester.ensureVisible(watchButton);
      await tester.tap(watchButton);
      await tester.pumpAndSettle();
      expect(spying.requestedPaths, contains('/v1/library/watch'));
    },
  );

  testWidgets('tapping WebDAV import triggers /v1/library/webdav/import', (
    tester,
  ) async {
    final spying = _SpyingClient(
      Uri.parse('http://fake/v1/library/webdav/import'),
      http.Response('{"imported":2,"skipped":1}', 200),
    );
    final repo = _FakeHttpRepositoryWithClient(spying);
    await tester.pumpWidget(_wrap(LibrarySourcesCard(), repository: repo));
    await tester.pumpAndSettle();
    final importButton = find.widgetWithText(
      OutlinedButton,
      'Import from WebDAV',
    );
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pumpAndSettle();
    expect(spying.requestedPaths, contains('/v1/library/webdav/import'));
  });

  testWidgets('tapping WebDAV sync triggers /v1/library/webdav/sync', (
    tester,
  ) async {
    final spying = _SpyingClient(
      Uri.parse('http://fake/v1/library/webdav/sync'),
      http.Response('{"imported":1,"skipped":0,"pushed":2}', 200),
    );
    final repo = _FakeHttpRepositoryWithClient(spying);
    await tester.pumpWidget(_wrap(LibrarySourcesCard(), repository: repo));
    await tester.pumpAndSettle();
    final syncButton = find.widgetWithText(
      OutlinedButton,
      'Sync WebDAV both ways',
    );
    await tester.ensureVisible(syncButton);
    await tester.tap(syncButton);
    await tester.pumpAndSettle();
    expect(spying.requestedPaths, contains('/v1/library/webdav/sync'));
  });

  testWidgets('WebDAV import surfaces an error message when the server fails', (
    tester,
  ) async {
    final repo = _FakeHttpRepositoryWithClient(
      _SpyingClient(
        Uri.parse('http://fake/v1/library/webdav/import'),
        http.Response('boom', 500),
      ),
    );
    await tester.pumpWidget(_wrap(LibrarySourcesCard(), repository: repo));
    await tester.pumpAndSettle();
    final importButton = find.widgetWithText(
      OutlinedButton,
      'Import from WebDAV',
    );
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pumpAndSettle();
    // Error text contains "WebDAV" and the status code.
    expect(find.textContaining('500'), findsAtLeastNWidgets(1));
  });

  testWidgets('disposes controllers without throwing', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LibrarySourcesCard(),
        repository: const _FakeRemoteRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
  });
}

/// Mirrors the HttpLibraryRepository shape but accepts an arbitrary
/// http.Client. Used by the widget tests so we can plug in a scripted
/// client without subclassing the real one.
class _FakeHttpRepositoryWithClient implements HttpLibraryRepository {
  _FakeHttpRepositoryWithClient(this._client);

  final http.Client _client;

  @override
  http.Client get httpClient => _client;

  @override
  Uri uri(String path) => Uri.parse('http://fake$path');

  @override
  bool get usesRemoteStore => true;

  @override
  String get baseUrl => 'http://fake';

  @override
  Future<List<LibraryDocument>> load() async => const [];

  @override
  Future<void> save(List<LibraryDocument> documents) async {}

  @override
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes) async =>
      throw UnimplementedError();

  @override
  Future<List<int>?> readFile(String id) async => null;

  @override
  Future<List<int>?> readCover(String id) async => null;

  @override
  Future<void> writeReadingState({
    required String id,
    required double progress,
    required DateTime lastOpened,
  }) async {}

  @override
  Future<void> writeIdentity({
    required String id,
    required String title,
    required String author,
  }) async {}

  @override
  Future<void> delete(String id) async {}
}

class _SpyingClient extends http.BaseClient {
  _SpyingClient(this.matchPath, this.response);

  final Uri matchPath;
  final http.Response response;
  final List<String> requestedPaths = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class _CompleterClient extends http.BaseClient {
  _CompleterClient(this.responseFuture);
  final Future<http.Response> responseFuture;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await responseFuture;
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
