import 'package:app/core/library_controller.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:app/core/seed_documents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waitUntilReady completes after load and is later a no-op', () async {
    final controller = PersistedLibraryController(
      repository: InMemoryLibraryRepository(),
    );

    final pending = controller.waitUntilReady();
    await controller.load();
    await pending;
    expect(controller.loading, isFalse);

    await controller.waitUntilReady();
    expect(controller.loading, isFalse);
  });

  test('empty local library does not invent seed books', () async {
    final controller = PersistedLibraryController(
      repository: InMemoryLibraryRepository(),
    );
    await controller.load();

    expect(controller.documents, isEmpty);
    expect(controller.documentById('design'), isNull);
  });

  test('a failed load stays empty instead of inventing seed books', () async {
    final controller = PersistedLibraryController(
      repository: _FailingLoadRepository(),
    );
    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.documents, isEmpty);
    expect(controller.documentById('design'), isNull);
  });

  test('favorites stay empty until a real book is starred', () async {
    final controller = PersistedLibraryController(
      repository: InMemoryLibraryRepository(seedDocuments),
    );
    await controller.load();
    controller.selectSection('favorites');

    expect(controller.documents, isEmpty);

    await controller.toggleFavorite('notes');
    expect(controller.documents, isEmpty);

    await controller.toggleFavorite('design');
    expect(controller.documents.single.metadata.id, 'design');
    expect(
      controller.documents.any((item) => item.metadata.id == 'prince'),
      isFalse,
    );
  });

  test('a collection only contains books added to it', () async {
    final controller = PersistedLibraryController(
      repository: InMemoryLibraryRepository(seedDocuments),
    );
    await controller.load();

    final created = await controller.createCollection('今晚读');
    expect(created, isNotNull);
    await controller.addToCollection(created!.id, 'design');
    controller.selectSection('collection:${created.id}');

    expect(controller.documents.single.metadata.id, 'design');
    expect(
      controller.documents.any((item) => item.metadata.id == 'rust'),
      isFalse,
    );

    expect(await controller.createCollection('   '), isNull);
  });

  test('deleting a book does not invent another book', () async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', [1]);
    await repository.importBytes('other.txt', [2]);
    final controller = PersistedLibraryController(repository: repository);
    await controller.load();
    final notes = controller.documents.firstWhere(
      (item) => item.metadata.title == 'notes',
    );
    await controller.toggleFavorite(notes.metadata.id);

    await controller.deleteDocument(notes.metadata.id);

    expect(controller.documents.map((item) => item.metadata.title), ['other']);
    expect(controller.documentById(notes.metadata.id), isNull);
    expect(controller.isFavorite(notes.metadata.id), isFalse);
    expect(await repository.readFile(notes.metadata.id), isNull);
    expect(await repository.readFile(controller.documents.single.metadata.id), [
      2,
    ]);
  });

  test('renaming a book updates the shelf without inventing another', () async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', [1]);
    final controller = PersistedLibraryController(repository: repository);
    await controller.load();

    await controller.writeIdentity(
      id: 'notes.txt',
      title: '设计笔记',
      author: '某作者',
    );

    expect(controller.documents.single.metadata.title, '设计笔记');
    expect(controller.documents.single.metadata.author, '某作者');
    expect(controller.documentById('design'), isNull);
    expect((await repository.load()).single.metadata.title, '设计笔记');
  });

  test('renaming a missing book does not invent a seed title', () async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', [1]);
    final controller = PersistedLibraryController(repository: repository);
    await controller.load();

    await controller.writeIdentity(
      id: 'missing',
      title: '设计中的设计',
      author: '原研哉',
    );

    expect(controller.documents.single.metadata.title, 'notes');
    expect(controller.documentById('missing'), isNull);
    expect(controller.documents, hasLength(1));
  });

  test('opened updates lastOpened in memory even when persistence fails', () async {
    final repository = _FailingWriteRepository();
    await repository.importBytes('notes.txt', [1]);
    final controller = PersistedLibraryController(repository: repository);
    await controller.load();
    final id = controller.documents.single.metadata.id;
    final before = controller.documents.single.readingState.lastOpened;

    await Future<void>.delayed(const Duration(milliseconds: 10));
    await controller.opened(id);

    final after = controller.documents.single.readingState.lastOpened;
    expect(after.isAfter(before), isTrue);
    expect(controller.documents.single.readingState.progress, 0.0);
  });

  test('opened on missing book does not invent a document', () async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', [1]);
    final controller = PersistedLibraryController(repository: repository);
    await controller.load();

    await controller.opened('missing');

    expect(controller.documents, hasLength(1));
    expect(controller.documentById('missing'), isNull);
  });

  test('updateProgress updates memory even when persistence fails', () async {
    final repository = _FailingWriteRepository();
    await repository.importBytes('notes.txt', [1]);
    final controller = PersistedLibraryController(repository: repository);
    await controller.load();
    final id = controller.documents.single.metadata.id;
    final before = controller.documents.single.readingState.lastOpened;

    await Future<void>.delayed(const Duration(milliseconds: 10));
    await controller.updateProgress(id, 0.75);

    expect(controller.documents.single.readingState.progress, 0.75);
    final after = controller.documents.single.readingState.lastOpened;
    expect(after.isAfter(before), isTrue);
  });

  test('updateProgress clamps out-of-range values', () async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', [1]);
    final controller = PersistedLibraryController(repository: repository);
    await controller.load();
    final id = controller.documents.single.metadata.id;

    await controller.updateProgress(id, 1.5);
    expect(controller.documents.single.readingState.progress, 1.0);

    await controller.updateProgress(id, -0.3);
    expect(controller.documents.single.readingState.progress, 0.0);
  });

  test('updateProgress on missing book does not invent a document', () async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', [1]);
    final controller = PersistedLibraryController(repository: repository);
    await controller.load();

    await controller.updateProgress('missing', 0.5);

    expect(controller.documents, hasLength(1));
    expect(controller.documentById('missing'), isNull);
    expect(controller.documents.single.readingState.progress, 0.0);
  });
}

class _FailingLoadRepository extends InMemoryLibraryRepository {
  @override
  Future<List<LibraryDocument>> load() async {
    throw StateError('disk unreadable');
  }
}

class _FailingWriteRepository extends InMemoryLibraryRepository {
  @override
  Future<void> writeReadingState({
    required String id,
    required double progress,
    required DateTime lastOpened,
  }) async {
    throw StateError('disk write failed');
  }
}
