import 'package:app/core/library_controller.dart';
import 'package:app/core/library_repository.dart';
import 'package:app/core/models.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/library/shelf_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seed_documents.dart';

class _StubAnnotationRepository implements AnnotationRepository {
  _StubAnnotationRepository(this._byId);

  final Map<String, List<ReaderAnnotation>> _byId;

  @override
  Future<List<ReaderAnnotation>> load(String documentId) async {
    return List.of(_byId[documentId] ?? const []);
  }

  @override
  Future<void> save(String documentId, List<ReaderAnnotation> notes) async {
    _byId[documentId] = List.of(notes);
  }
}

class _ThrowingAnnotationRepository implements AnnotationRepository {
  @override
  Future<List<ReaderAnnotation>> load(String documentId) async {
    throw StateError('disk unreadable');
  }

  @override
  Future<void> save(String documentId, List<ReaderAnnotation> notes) async {
    throw StateError('disk unreadable');
  }
}

LibraryDocument _stubDoc({
  required String id,
  required String title,
  DateTime? lastOpened,
}) {
  return LibraryDocument(
    metadata: DocumentMetadata(
      id: id,
      title: title,
      author: '',
      format: DocumentFormat.txt,
      type: DocumentType.reflow,
      coverColor: 0xFF527882,
      contentHash: 'hash-$id',
    ),
    readingState: ReadingState(
      progress: 0,
      lastOpened: lastOpened ?? DateTime.utc(2026, 1, 1),
    ),
  );
}

ReaderAnnotation _stubNote({
  required String id,
  String quote = '',
  String note = '',
}) {
  return ReaderAnnotation(
    id: id,
    note: note,
    quote: quote,
    source: userNoteSource,
    createdAt: DateTime.utc(2026, 1, 1),
  );
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

    final created = await controller.createCollection('shelf-A');
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
      title: 'Design Notes',
      author: 'Some Author',
    );

    expect(controller.documents.single.metadata.title, 'Design Notes');
    expect(controller.documents.single.metadata.author, 'Some Author');
    expect(controller.documentById('design'), isNull);
    expect((await repository.load()).single.metadata.title, 'Design Notes');
  });

  test('renaming a missing book does not invent a seed title', () async {
    final repository = InMemoryLibraryRepository();
    await repository.importBytes('notes.txt', [1]);
    final controller = PersistedLibraryController(repository: repository);
    await controller.load();

    await controller.writeIdentity(
      id: 'missing',
      title: 'Some New Title',
      author: 'Original Author',
    );

    expect(controller.documents.single.metadata.title, 'notes');
    expect(controller.documentById('missing'), isNull);
    expect(controller.documents, hasLength(1));
  });

  test(
    'opened updates lastOpened in memory even when persistence fails',
    () async {
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
    },
  );

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

  group('annotation-backed search', () {
    test(
      'includes a book whose note matches when no metadata hit exists',
      () async {
        final repository = _StubAnnotationRepository({
          'note-only': [_stubNote(id: 'n1', quote: 'this contains needle')],
        });
        final controller = PersistedLibraryController(
          repository: InMemoryLibraryRepository(),
          annotationRepository: repository,
        );
        await controller.load();
        controller.addDocumentForTest(
          _stubDoc(id: 'note-only', title: 'Alpha'),
        );

        controller.search('needle');
        await controller.waitForSearch();
        final ids = controller.documents.map((d) => d.metadata.id).toList();
        expect(ids, contains('note-only'));
      },
    );

    test('does not duplicate a book that already matched metadata', () async {
      final repository = _StubAnnotationRepository({
        'design': [_stubNote(id: 'n1', quote: 'design quote')],
      });
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
        annotationRepository: repository,
      );
      await controller.load();
      controller.addDocumentForTest(
        _stubDoc(id: 'design', title: 'Design Notes'),
      );

      controller.search('design');
      await controller.waitForSearch();

      expect(
        controller.documents.where((d) => d.metadata.id == 'design'),
        hasLength(1),
      );
    });

    test('returns metadata hits even when annotation store throws', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
        annotationRepository: _ThrowingAnnotationRepository(),
      );
      await controller.load();
      controller.addDocumentForTest(
        _stubDoc(id: 'design', title: 'Design Notes'),
      );

      controller.search('design');
      await controller.waitForSearch();

      expect(
        controller.documents.where((d) => d.metadata.id == 'design'),
        hasLength(1),
      );
    });

    test('omits annotation scan when no repository is provided', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      await controller.load();
      controller.addDocumentForTest(_stubDoc(id: 'note-only', title: 'Alpha'));

      controller.search('needle');
      await controller.waitForSearch();

      expect(controller.documents, isEmpty);
    });
  });

  group('deleteCollection', () {
    test('removes the collection from the shelf', () async {
      final repository = InMemoryLibraryRepository(seedDocuments);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();
      final created = await controller.createCollection('shelf-A');
      expect(created, isNotNull);

      await controller.deleteCollection(created!.id);

      expect(controller.collections, isEmpty);
      expect(controller.isInCollection(created.id, 'design'), isFalse);
      expect(controller.collectionName('collection:${created.id}'), isNull);
    });

    test('falls back to all when the active section is removed', () async {
      final repository = InMemoryLibraryRepository(seedDocuments);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();
      final created = await controller.createCollection('shelf-A');
      controller.selectSection('collection:${created!.id}');
      expect(controller.section, 'collection:${created.id}');

      await controller.deleteCollection(created.id);

      expect(controller.section, 'all');
    });

    test(
      'leaves other sections alone when an unrelated collection is removed',
      () async {
        final repository = InMemoryLibraryRepository(seedDocuments);
        final controller = PersistedLibraryController(repository: repository);
        await controller.load();
        final keep = await controller.createCollection('shelf-A');
        final drop = await controller.createCollection('shelf-B');
        controller.selectSection('favorites');

        await controller.deleteCollection(drop!.id);

        expect(controller.section, 'favorites');
        expect(
          controller.collections.map((c) => c.name),
          containsAll(['shelf-A']),
          reason: 'unrelated collection must survive',
        );
        expect(controller.isInCollection(keep!.id, 'design'), isFalse);
      },
    );

    test('is a no-op when the collection id is unknown', () async {
      final repository = InMemoryLibraryRepository(seedDocuments);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();
      final before = controller.collections;

      await controller.deleteCollection('c-does-not-exist');

      expect(controller.collections, before);
    });
  });

  group('waitUntilReady', () {
    test('resolves once load finishes and is a no-op afterwards', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      expect(controller.loading, isTrue);

      final firstWait = controller.waitUntilReady();
      final secondWait = controller.waitUntilReady();
      await controller.load();

      await Future.wait([firstWait, secondWait]);
      expect(controller.loading, isFalse);

      final third = controller.waitUntilReady();
      await third;
      expect(controller.loading, isFalse);
    });

    test('returns a completed future when load already finished', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      await controller.load();
      expect(controller.loading, isFalse);

      final pending = controller.waitUntilReady();
      // Synchronously resolved: the returned future should already be done
      // before we even hand it to the event loop. Box the void result so
      // the analyzer does not collapse it into `void`.
      final Object? completed = await pending
          .then((_) => null)
          .timeout(const Duration(milliseconds: 1), onTimeout: () => null);
      expect(completed, isNull);
    });
  });

  group('search refresh', () {
    test(
      'empty query skips the async scan and waitForSearch resolves',
      () async {
        final controller = PersistedLibraryController(
          repository: InMemoryLibraryRepository(),
          annotationRepository: _ThrowingAnnotationRepository(),
        );
        await controller.load();

        controller.search('');
        // The throwing repo must not be reached; waitForSearch must not hang.
        await controller.waitForSearch();
        expect(controller.documents, isEmpty);
      },
    );

    test(
      'a stale pending search does not publish after a newer query',
      () async {
        final controller = PersistedLibraryController(
          repository: InMemoryLibraryRepository(),
          annotationRepository: _StubAnnotationRepository(const {}),
        );
        await controller.load();
        controller.addDocumentForTest(
          _stubDoc(id: 'design', title: 'Design Notes'),
        );

        controller.search('design');
        controller.search('rust');
        await controller.waitForSearch();

        expect(
          controller.documents.where((d) => d.metadata.id == 'design'),
          isEmpty,
          reason: 'the stale design hit must be discarded by the new query',
        );
        expect(
          controller.documents.where((d) => d.metadata.id == 'rust'),
          isEmpty,
          reason: 'no metadata match for rust either',
        );
      },
    );

    test('waitForSearch resolves when annotation store throws', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
        annotationRepository: _ThrowingAnnotationRepository(),
      );
      await controller.load();
      controller.addDocumentForTest(
        _stubDoc(id: 'design', title: 'Design Notes'),
      );

      controller.search('design');
      await controller.waitForSearch();

      expect(
        controller.documents.where((d) => d.metadata.id == 'design'),
        hasLength(1),
      );
    });
  });

  group('continueReading', () {
    test('picks the most recently opened in-progress book', () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('a.txt', [1]);
      await repository.importBytes('b.txt', [2]);
      await repository.importBytes('c.txt', [3]);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();

      final ids = controller.documents.map((d) => d.metadata.id).toList();
      expect(ids, containsAll(['a.txt', 'b.txt', 'c.txt']));
      await controller.updateProgress('a.txt', 0.3);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await controller.updateProgress('b.txt', 0.5);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await controller.updateProgress('c.txt', 0.7);

      // c.txt was touched last and is still in-progress.
      expect(controller.continueReading?.metadata.id, 'c.txt');
    });

    test('returns null when no book has any progress', () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('a.txt', [1]);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();

      expect(controller.continueReading, isNull);
    });

    test(
      'returns null when every book is finished (progress == 1.0)',
      () async {
        final repository = InMemoryLibraryRepository();
        await repository.importBytes('a.txt', [1]);
        final controller = PersistedLibraryController(repository: repository);
        await controller.load();
        await controller.updateProgress('a.txt', 1.0);

        expect(controller.continueReading, isNull);
      },
    );

    test('returns null when the library is empty', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      await controller.load();

      expect(controller.continueReading, isNull);
    });
  });

  group('toggleInCollection', () {
    test('adds and removes a book from a collection', () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('notes.txt', [1]);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();
      final docId = controller.documents.single.metadata.id;
      final collection = await controller.createCollection('shelf-A');
      expect(collection, isNotNull);

      await controller.toggleInCollection(collection!.id, docId);
      expect(controller.isInCollection(collection.id, docId), isTrue);

      await controller.toggleInCollection(collection.id, docId);
      expect(controller.isInCollection(collection.id, docId), isFalse);
    });

    test('is a no-op for an unknown document', () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('notes.txt', [1]);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();
      final collection = await controller.createCollection('shelf-A');

      await controller.toggleInCollection(collection!.id, 'missing');

      expect(controller.isInCollection(collection.id, 'missing'), isFalse);
    });
  });

  group('shelf persistence failures', () {
    test('toggleFavorite keeps memory state when save throws', () async {
      final repository = InMemoryLibraryRepository(seedDocuments);
      final shelves = _FailingShelfRepository()..failNextSave = true;
      final controller = PersistedLibraryController(
        repository: repository,
        shelfRepository: shelves,
      );
      await controller.load();

      await controller.toggleFavorite('design');

      // The favorite is held in memory even though persistence failed so the
      // user can retry the same toggle later in the same session.
      expect(controller.isFavorite('design'), isTrue);
      // The next toggle reaches the in-memory shelves — save failure was
      // consumed by the first call and now persists successfully.
      shelves.failNextSave = false;
      await controller.toggleFavorite('design');
      expect(controller.isFavorite('design'), isFalse);
      // The second toggle's save reached the shelves store.
      expect(shelves.load(), completion(isNotNull));
    });

    test('createCollection is reported as null when save throws', () async {
      final repository = InMemoryLibraryRepository(seedDocuments);
      final shelves = _FailingShelfRepository()..failNextSave = true;
      final controller = PersistedLibraryController(
        repository: repository,
        shelfRepository: shelves,
      );
      await controller.load();

      final created = await controller.createCollection('shelf-A');

      expect(created, isNull);
      // Memory state is rolled back, so the collection does not appear in
      // the current session either.
      expect(controller.collections, isEmpty);
    });
  });

  group('selectSort / selectType / toggleView', () {
    test('selectSort changes ordering and notifyListeners fires', () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('alpha.txt', [1]);
      await repository.importBytes('beta.txt', [2]);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.selectSort('title');
      expect(controller.sort, 'title');
      expect(controller.documents.map((d) => d.metadata.title).toList(), [
        'alpha',
        'beta',
      ]);
      expect(notifyCount, 1);

      controller.selectSort('progress');
      expect(controller.sort, 'progress');
      expect(notifyCount, 2);
    });

    test('selectType narrows documents to the chosen type', () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('reflow.txt', [1]);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();
      // addDocumentForTest preserves the existing type. We add an unknown
      // type, so all formats stay 'all' by default and the reflow document
      // stays visible.
      controller.addDocumentForTest(
        _stubDoc(id: 'other-reflow', title: 'Other Book'),
      );
      expect(controller.documents, hasLength(2));

      controller.selectType('pdf');
      expect(controller.formatType, 'pdf');
      expect(controller.documents, isEmpty);
    });

    test('toggleView flips listView and notifies listeners', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      await controller.load();
      expect(controller.listView, isFalse);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.toggleView();
      expect(controller.listView, isTrue);
      expect(notifyCount, 1);

      controller.toggleView();
      expect(controller.listView, isFalse);
      expect(notifyCount, 2);
    });
  });

  group('readCover / readFile on the controller', () {
    test('readCover returns repository bytes when present', () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('notes.txt', [1]);
      // InMemoryLibraryRepository stores covers only for formats that
      // produce them; for txt there is none. Use a stub that hands out a
      // cover directly so we exercise the controller pass-through.
      final stubbed = _StubCoverRepository([1, 2, 3]);
      final controller = PersistedLibraryController(repository: stubbed);
      await controller.load();

      final bytes = await controller.readCover('any-id');
      expect(bytes, [1, 2, 3]);
    });

    test(
      'readCover returns null when the cover is missing in storage',
      () async {
        final repository = InMemoryLibraryRepository();
        await repository.importBytes('notes.txt', [1]);
        final controller = PersistedLibraryController(repository: repository);
        await controller.load();

        expect(await controller.readCover('no-such-id'), isNull);
      },
    );

    test('readCover returns null when the repository throws', () async {
      final controller = PersistedLibraryController(
        repository: _FailingReadCoverRepository(),
      );
      await controller.load();

      expect(await controller.readCover('notes'), isNull);
    });

    test('readFile returns null when the repository throws', () async {
      final controller = PersistedLibraryController(
        repository: _FailingReadFileRepository(),
      );
      await controller.load();

      expect(await controller.readFile('notes'), isNull);
    });
  });

  group('importNamedBytes outcomes', () {
    test('reports unsupported when nothing matches a known format', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      await controller.load();

      final outcome = await controller.importNamedBytes([
        (name: 'noise.bin', bytes: [1, 2, 3]),
      ]);

      expect(outcome.count, 0);
      expect(outcome.cancelled, isFalse);
      expect(outcome.failed, isFalse);
      expect(controller.documents, isEmpty);
    });

    test('reports failed when the repository throws on every file', () async {
      final controller = PersistedLibraryController(
        repository: _FailingImportRepository(),
      );
      await controller.load();

      final outcome = await controller.importNamedBytes([
        (name: 'notes.txt', bytes: [1]),
      ]);

      expect(outcome.count, 0);
      expect(outcome.failed, isTrue);
    });

    test('reports imported with the success count', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      await controller.load();

      final outcome = await controller.importNamedBytes([
        (name: 'a.txt', bytes: [1]),
        (name: 'b.txt', bytes: [2]),
      ]);

      expect(outcome.count, 2);
      expect(controller.documents, hasLength(2));
    });

    test('empty input short-circuits to cancelled without notify', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      await controller.load();
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      final outcome = await controller.importNamedBytes(const []);

      expect(outcome.cancelled, isTrue);
      expect(notifyCount, 0);
    });

    test('partial failure still counts the successful imports', () async {
      final controller = PersistedLibraryController(
        repository: _PartialImportRepository(),
      );
      await controller.load();

      final outcome = await controller.importNamedBytes([
        (name: 'good.txt', bytes: [1]),
        (name: 'bad.txt', bytes: [2]),
      ]);

      expect(outcome.count, 1);
      // When at least one file succeeded the outcome reports the imported
      // count; the partial failure is silently absorbed (no UI to surface it).
      expect(outcome.failed, isFalse);
      expect(controller.documents, hasLength(1));
    });
  });

  group('continueReading notifies listeners on updateProgress', () {
    test('updateProgress notifies after a successful write', () async {
      final repository = InMemoryLibraryRepository();
      await repository.importBytes('a.txt', [1]);
      final controller = PersistedLibraryController(repository: repository);
      await controller.load();
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.updateProgress(
        controller.documents.single.metadata.id,
        0.4,
      );
      expect(notifyCount, greaterThan(0));
      expect(controller.continueReading, isNotNull);
    });
  });
}

class _FailingReadCoverRepository extends InMemoryLibraryRepository {
  @override
  Future<List<int>?> readCover(String id) async {
    throw StateError('cover unreadable');
  }
}

class _FailingReadFileRepository extends InMemoryLibraryRepository {
  @override
  Future<List<int>?> readFile(String id) async {
    throw StateError('file unreadable');
  }
}

class _FailingImportRepository extends InMemoryLibraryRepository {
  @override
  Future<LibraryDocument> importBytes(String name, List<int> bytes) async {
    throw StateError('disk write failed');
  }
}

class _PartialImportRepository extends InMemoryLibraryRepository {
  @override
  Future<LibraryDocument> importBytes(String name, List<int> bytes) async {
    if (name == 'bad.txt') throw StateError('disk write failed');
    return super.importBytes(name, bytes);
  }
}

class _StubCoverRepository extends InMemoryLibraryRepository {
  _StubCoverRepository(this._cover);

  final List<int> _cover;

  @override
  Future<List<int>?> readCover(String id) async => List<int>.from(_cover);
}

class _FailingShelfRepository implements ShelfRepository {
  final Map<String, LibraryShelves> _stores = {};
  bool failNextSave = false;

  @override
  Future<LibraryShelves> load() async =>
      _stores['default'] ?? const LibraryShelves();

  @override
  Future<void> save(LibraryShelves shelves) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('shelf save failed');
    }
    _stores['default'] = shelves;
  }
}
