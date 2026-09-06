import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/library/library_sources_card.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal stub that only exposes what's needed for widget rendering
/// plus the remote-store flag.
class _FakeRemoteRepository implements LibraryRepository {
  _FakeRemoteRepository({this.shouldThrow = false});
  final bool shouldThrow;

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
    overrides: [
      libraryRepositoryProvider.overrideWithValue(repository),
    ],
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

  testWidgets('shows scan + watch fields when the library is remote',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LibrarySourcesCard(),
        repository: _FakeRemoteRepository(),
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
}
