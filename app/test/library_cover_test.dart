import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/library/library_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/image_fixture.dart';

class _StubLibraryRepository implements LibraryRepository {
  _StubLibraryRepository({
    required this.documents,
    Map<String, List<int>>? covers,
  }) : _covers = covers ?? const {};

  final List<LibraryDocument> documents;
  final Map<String, List<int>> _covers;

  @override
  bool get usesRemoteStore => false;

  @override
  Future<List<LibraryDocument>> load() async => List.of(documents);

  @override
  Future<void> save(List<LibraryDocument> documents) async {}

  @override
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes) async {
    throw UnimplementedError();
  }

  @override
  Future<List<int>?> readFile(String id) async => null;

  @override
  Future<List<int>?> readCover(String id) async {
    final bytes = _covers[id];
    return bytes == null ? null : List<int>.from(bytes);
  }

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

const _docId = 'library-cover-book';

DocumentMetadata _metadata({String id = _docId, bool hasCover = true}) {
  return DocumentMetadata(
    id: id,
    title: 'Cover Book',
    author: 'Anonymous',
    format: DocumentFormat.epub,
    type: DocumentType.reflow,
    hasCover: hasCover,
  );
}

const _defaultMetadata = DocumentMetadata(
  id: _docId,
  title: 'Cover Book',
  author: 'Anonymous',
  format: DocumentFormat.epub,
  type: DocumentType.reflow,
);

Future<void> _pump(
  WidgetTester tester, {
  required LibraryRepository repository,
  required Widget child,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets(
    'LibraryCover renders Image.memory when readCover returns bytes',
    (tester) async {
      final repository = _StubLibraryRepository(
        documents: [
          LibraryDocument(
            metadata: _metadata(),
            readingState: ReadingState(progress: 0, lastOpened: DateTime(2026)),
          ),
        ],
        covers: {_docId: tinyPngBytes()},
      );

      await _pump(
        tester,
        repository: repository,
        child: const LibraryCover(
          metadata: _defaultMetadata,
          fallback: Text('fallback'),
        ),
      );

      // First frame: FutureBuilder still pending -> fallback shown.
      expect(find.text('fallback'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      // Let the async readCover future resolve and the FutureBuilder rebuild.
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('fallback'), findsNothing);
    },
  );

  testWidgets(
    'LibraryCover falls back to the supplied widget when readCover returns null',
    (tester) async {
      final repository = _StubLibraryRepository(
        documents: [
          LibraryDocument(
            metadata: _metadata(hasCover: false),
            readingState: ReadingState(progress: 0, lastOpened: DateTime(2026)),
          ),
        ],
      );

      await _pump(
        tester,
        repository: repository,
        child: const LibraryCover(
          metadata: DocumentMetadata(
            id: _docId,
            title: 'Cover Book',
            author: 'Anonymous',
            format: DocumentFormat.epub,
            type: DocumentType.reflow,
            hasCover: false,
          ),
          fallback: Text('no-cover-here'),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('no-cover-here'), findsOneWidget);
    },
  );

  testWidgets(
    'LibraryCover falls back when the repository returns an empty byte list',
    (tester) async {
      final repository = _StubLibraryRepository(
        documents: [
          LibraryDocument(
            metadata: _metadata(),
            readingState: ReadingState(progress: 0, lastOpened: DateTime(2026)),
          ),
        ],
        // Cover is recorded as present but the bytes are empty — this should
        // still trigger the fallback path rather than rendering a broken
        // Image.memory.
        covers: {_docId: <int>[]},
      );

      await _pump(
        tester,
        repository: repository,
        child: const LibraryCover(
          metadata: _defaultMetadata,
          fallback: Text('empty-bytes'),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('empty-bytes'), findsOneWidget);
    },
  );

  testWidgets(
    'LibraryCover propagates width and height into the Image.memory',
    (tester) async {
      final repository = _StubLibraryRepository(
        documents: [
          LibraryDocument(
            metadata: _defaultMetadata,
            readingState: ReadingState(progress: 0, lastOpened: DateTime(2026)),
          ),
        ],
        covers: {_docId: tinyPngBytes()},
      );

      await _pump(
        tester,
        repository: repository,
        child: const LibraryCover(
          metadata: _defaultMetadata,
          fallback: Text('fallback'),
          width: 84,
          height: 120,
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 84);
      expect(image.height, 120);
      expect(image.fit, BoxFit.cover);
    },
  );
}
