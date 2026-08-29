import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../features/library/shelf_store.dart' as shelf;
import 'library_repository.dart';
import 'models.dart';

class PersistedLibraryController extends ChangeNotifier {
  PersistedLibraryController({
    required this.repository,
    shelf.ShelfRepository? shelfRepository,
  }) : shelfRepository = shelfRepository ?? shelf.InMemoryShelfRepository();

  final LibraryRepository repository;
  final shelf.ShelfRepository shelfRepository;
  List<LibraryDocument> _documents = [];
  shelf.LibraryShelves _shelves = const shelf.LibraryShelves();
  String query = '';
  String section = 'all';
  String formatType = 'all';
  String sort = 'recent';
  bool listView = false;
  bool loading = true;

  List<shelf.LibraryCollection> get collections => _shelves.collections;

  bool isFavorite(String id) => _shelves.favoriteIds.contains(id);

  bool isInCollection(String collectionId, String documentId) {
    for (final collection in _shelves.collections) {
      if (collection.id == collectionId) return collection.contains(documentId);
    }
    return false;
  }

  String? collectionName(String value) {
    if (!value.startsWith(shelf.collectionSectionPrefix)) return null;
    final id = value.substring(shelf.collectionSectionPrefix.length);
    for (final collection in _shelves.collections) {
      if (collection.id == id) return collection.name;
    }
    return null;
  }

  Future<void> waitUntilReady() {
    if (!loading) return Future.value();
    final ready = Completer<void>();
    late final VoidCallback listener;
    listener = () {
      if (loading) return;
      removeListener(listener);
      if (!ready.isCompleted) ready.complete();
    };
    addListener(listener);
    if (!loading) {
      removeListener(listener);
      return Future.value();
    }
    return ready.future;
  }

  bool get usesRemoteStore => repository.usesRemoteStore;
  bool get hasStoredDocuments => _documents.isNotEmpty;

  List<LibraryDocument> get documents {
    final result = _documents.where((document) {
      final metadata = document.metadata;
      final text =
          '${metadata.title} ${metadata.author} ${metadata.format.label}'
              .toLowerCase();
      final queryMatches = query.isEmpty || text.contains(query.toLowerCase());
      final typeMatches =
          formatType == 'all' || metadata.type.name == formatType;
      final progress = document.readingState.progress;
      final sectionMatches = shelf.documentMatchesSection(
        section: section,
        documentId: metadata.id,
        progress: progress,
        shelves: _shelves,
      );
      return queryMatches && typeMatches && sectionMatches;
    }).toList();
    result.sort(
      (a, b) => switch (sort) {
        'title' => a.metadata.title.compareTo(b.metadata.title),
        'progress' => b.readingState.progress.compareTo(
          a.readingState.progress,
        ),
        _ => b.readingState.lastOpened.compareTo(a.readingState.lastOpened),
      },
    );
    return result;
  }

  LibraryDocument? documentById(String id) {
    for (final document in _documents) {
      if (document.metadata.id == id) return document;
    }
    return null;
  }

  LibraryDocument? get continueReading {
    final reading = _documents
        .where(
          (document) =>
              document.readingState.progress > 0 &&
              document.readingState.progress < 1,
        )
        .toList();
    reading.sort(
      (a, b) => b.readingState.lastOpened.compareTo(a.readingState.lastOpened),
    );
    return reading.isEmpty ? null : reading.first;
  }

  Future<void> load() async {
    try {
      _documents = await repository.load();
    } catch (_) {
      // 读失败时按空库处理，不灌种子书。
      _documents = [];
    }
    await _loadShelves();
    loading = false;
    notifyListeners();
  }

  Future<void> _loadShelves() async {
    try {
      final stored = await shelfRepository.load();
      final pruned = shelf.pruneShelves(stored, {
        for (final document in _documents) document.metadata.id,
      });
      _shelves = pruned;
      if (pruned != stored) await shelfRepository.save(pruned);
    } catch (_) {
      // 架子读失败时按空架子筛，不拿种子书冒充收藏。
      _shelves = const shelf.LibraryShelves();
    }
  }

  Future<void> _saveShelves() async {
    try {
      await shelfRepository.save(_shelves);
    } catch (_) {
      // 当前筛选仍可用；下次 load 会再尝试写入。
    }
  }

  Future<void> toggleFavorite(String id) async {
    if (documentById(id) == null) return;
    _shelves = shelf.toggleFavorite(_shelves, id);
    notifyListeners();
    await _saveShelves();
  }

  Future<shelf.LibraryCollection?> createCollection(String name) async {
    final next = shelf.addCollection(_shelves, name: name);
    if (next.collections.length == _shelves.collections.length) return null;
    _shelves = next;
    notifyListeners();
    await _saveShelves();
    return _shelves.collections.last;
  }

  Future<void> addToCollection(String collectionId, String documentId) async {
    if (documentById(documentId) == null) return;
    _shelves = shelf.addToCollection(_shelves, collectionId, documentId);
    notifyListeners();
    await _saveShelves();
  }

  Future<void> toggleInCollection(
    String collectionId,
    String documentId,
  ) async {
    if (documentById(documentId) == null) return;
    _shelves = shelf.toggleInCollection(_shelves, collectionId, documentId);
    notifyListeners();
    await _saveShelves();
  }

  Future<void> deleteCollection(String collectionId) async {
    _shelves = shelf.removeCollection(_shelves, collectionId);
    if (section == shelf.collectionSection(collectionId)) section = 'all';
    notifyListeners();
    await _saveShelves();
  }

  Future<void> deleteDocument(String id) async {
    if (documentById(id) == null) return;
    try {
      await repository.delete(id);
    } catch (_) {
      // 删除失败则保留原书，不拿另一本顶上。
      return;
    }
    _documents.removeWhere((item) => item.metadata.id == id);
    _shelves = shelf.pruneShelves(_shelves, {
      for (final document in _documents) document.metadata.id,
    });
    notifyListeners();
    await _saveShelves();
  }

  void search(String value) {
    query = value;
    notifyListeners();
  }

  void selectSection(String value) {
    section = value;
    notifyListeners();
  }

  void selectType(String value) {
    formatType = value;
    notifyListeners();
  }

  void selectSort(String value) {
    sort = value;
    notifyListeners();
  }

  void toggleView() {
    listView = !listView;
    notifyListeners();
  }

  Future<List<int>?> readFile(String id) async {
    try {
      return await repository.readFile(id);
    } catch (_) {
      return null;
    }
  }

  Future<List<int>?> readCover(String id) async {
    try {
      return await repository.readCover(id);
    } catch (_) {
      return null;
    }
  }

  Future<ImportOutcome> importFiles() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return const ImportOutcome.cancelled();
    return importNamedBytes([
      for (final file in files)
        (name: file.name, bytes: await file.readAsBytes()),
    ]);
  }

  Future<ImportOutcome> importFolder() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return const ImportOutcome.cancelled();
    return importNamedBytes([
      for (final file in files)
        (name: file.name, bytes: await file.readAsBytes()),
    ]);
  }

  Future<ImportOutcome> importNamedBytes(
    Iterable<({String name, List<int> bytes})> files,
  ) async {
    final items = files.toList();
    if (items.isEmpty) return const ImportOutcome.cancelled();
    var count = 0;
    var failed = false;
    for (final file in items) {
      try {
        final document = await repository.importBytes(file.name, file.bytes);
        _documents.removeWhere(
          (item) => item.metadata.id == document.metadata.id,
        );
        _documents.insert(0, document);
        count++;
      } on FormatException {
        continue;
      } catch (_) {
        failed = true;
      }
    }
    notifyListeners();
    if (count > 0) return ImportOutcome.imported(count);
    if (failed) return const ImportOutcome.failed();
    return const ImportOutcome.unsupported();
  }

  Future<void> opened(String id) async {
    final index = _documents.indexWhere((item) => item.metadata.id == id);
    if (index < 0) return;
    final item = _documents[index];
    final next = item.copyWith(
      readingState: ReadingState(
        progress: item.readingState.progress,
        lastOpened: DateTime.now(),
      ),
    );
    _documents[index] = next;
    try {
      await repository.writeReadingState(
        id: id,
        progress: next.readingState.progress,
        lastOpened: next.readingState.lastOpened,
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateProgress(String id, double progress) async {
    final index = _documents.indexWhere((item) => item.metadata.id == id);
    if (index < 0) return;
    final item = _documents[index];
    final next = item.copyWith(
      readingState: ReadingState(
        progress: progress.clamp(0, 1),
        lastOpened: DateTime.now(),
      ),
    );
    _documents[index] = next;
    try {
      await repository.writeReadingState(
        id: id,
        progress: next.readingState.progress,
        lastOpened: next.readingState.lastOpened,
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> writeIdentity({
    required String id,
    required String title,
    required String author,
  }) async {
    final index = _documents.indexWhere((item) => item.metadata.id == id);
    if (index < 0) return;
    try {
      await repository.writeIdentity(id: id, title: title, author: author);
    } catch (_) {
      // 写失败则保留原书名，不拿种子书顶上。
      return;
    }
    _documents[index] = documentWithWrittenIdentity(
      _documents[index],
      title: title,
      author: author,
    );
    notifyListeners();
  }
}

class ImportOutcome {
  const ImportOutcome.cancelled() : count = 0, failed = false, cancelled = true;
  const ImportOutcome.imported(this.count) : failed = false, cancelled = false;
  const ImportOutcome.failed() : count = 0, failed = true, cancelled = false;
  const ImportOutcome.unsupported()
    : count = 0,
      failed = false,
      cancelled = false;

  final int count;
  final bool failed;
  final bool cancelled;
}
