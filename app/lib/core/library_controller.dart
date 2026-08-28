import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'format_detector.dart';
import 'library_repository.dart';
import 'models.dart';

class PersistedLibraryController extends ChangeNotifier {
  PersistedLibraryController({
    required this.repository,
    required this._initialDocuments,
  });

  final LibraryRepository repository;
  final List<LibraryDocument> _initialDocuments;
  final FormatDetector detector = const FormatDetector();
  List<LibraryDocument> _documents = [];
  String query = '';
  String section = 'all';
  String formatType = 'all';
  String sort = 'recent';
  bool listView = false;
  bool loading = true;

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
    final stored = await repository.load();
    _documents = stored.isEmpty ? List.of(_initialDocuments) : stored;
    if (stored.isEmpty) await repository.save(_documents);
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

  Future<String?> importFiles() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    var count = 0;
    for (final file in files) {
      final source = DocumentSource(name: file.name, path: file.path);
      final format = detector.detect(source);
      if (format == DocumentFormat.unknown) continue;
      _documents.removeWhere((document) => document.metadata.id == file.name);
      _documents.insert(
        0,
        LibraryDocument(
          metadata: DocumentMetadata(
            id: file.name,
            title: file.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            author: '本地文件',
            format: format,
            type: format.type,
            coverColor: 0xFF6F8179,
          ),
          readingState: ReadingState(progress: 0, lastOpened: DateTime.now()),
        ),
      );
      count++;
    }
    await repository.save(_documents);
    notifyListeners();
    return count == 0 ? '没有识别到支持的格式' : '已导入 $count 本书籍';
  }

  Future<void> opened(String id) async {
    final index = _documents.indexWhere((item) => item.metadata.id == id);
    if (index < 0) return;
    final item = _documents[index];
    _documents[index] = item.copyWith(
      readingState: ReadingState(
        progress: item.readingState.progress,
        lastOpened: DateTime.now(),
      ),
    );
    await repository.save(_documents);
    notifyListeners();
  }

  Future<void> updateProgress(String id, double progress) async {
    final index = _documents.indexWhere((item) => item.metadata.id == id);
    if (index < 0) return;
    final item = _documents[index];
    _documents[index] = item.copyWith(
      readingState: ReadingState(
        progress: progress.clamp(0, 1),
        lastOpened: DateTime.now(),
      ),
    );
    await repository.save(_documents);
    notifyListeners();
  }
}
