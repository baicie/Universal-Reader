import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'library_repository.dart';
import 'models.dart';

class PersistedLibraryController extends ChangeNotifier {
  PersistedLibraryController({
    required this.repository,
    required this._initialDocuments,
  });

  final LibraryRepository repository;
  final List<LibraryDocument> _initialDocuments;
  List<LibraryDocument> _documents = [];
  String query = '';
  String section = 'all';
  String formatType = 'all';
  String sort = 'recent';
  bool listView = false;
  bool loading = true;

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
      final sectionMatches = switch (section) {
        'reading' => progress > 0 && progress < 1,
        'favorites' => {'design', 'prince', 'rust'}.contains(metadata.id),
        _ => true,
      };
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
      final stored = await repository.load();
      final seedLocalEmpty = stored.isEmpty && !repository.usesRemoteStore;
      _documents = seedLocalEmpty ? List.of(_initialDocuments) : stored;
      if (seedLocalEmpty) await repository.save(_documents);
    } catch (_) {
      _documents = repository.usesRemoteStore ? [] : List.of(_initialDocuments);
    }
    loading = false;
    notifyListeners();
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
