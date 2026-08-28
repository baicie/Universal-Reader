import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';

void main() {
  final document = LibraryDocument(
    metadata: const DocumentMetadata(
      id: 'book-1',
      title: 'Test Book',
      author: 'Author',
      format: DocumentFormat.epub,
      type: DocumentType.reflow,
    ),
    readingState: ReadingState(
      progress: .42,
      lastOpened: DateTime(2026, 8, 25, 7, 30),
    ),
  );

  test('round trips library documents through JSON', () {
    final decoded = LibraryDocumentCodec.fromJson(
      LibraryDocumentCodec.toJson(document),
    );

    expect(decoded.metadata.title, 'Test Book');
    expect(decoded.metadata.format, DocumentFormat.epub);
    expect(decoded.readingState.progress, .42);
    expect(decoded.readingState.lastOpened, document.readingState.lastOpened);
  });

  test('in-memory repository persists a replacement snapshot', () async {
    final repository = InMemoryLibraryRepository([document]);
    expect((await repository.load()).single.metadata.id, 'book-1');

    await repository.save([]);
    expect(await repository.load(), isEmpty);
  });

  test('in-memory repository imports supported bytes', () async {
    final repository = InMemoryLibraryRepository();
    final document = await repository.importBytes('notes.txt', [1, 2, 3]);
    expect(document.metadata.title, 'notes');
    expect(document.metadata.format, DocumentFormat.txt);
    expect((await repository.load()).single.metadata.id, 'notes.txt');
  });
}
