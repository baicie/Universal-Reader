import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'content_hash.dart';
import 'cover_extract.dart';
import 'format_detector.dart';
import 'models.dart';

abstract interface class LibraryRepository {
  bool get usesRemoteStore;
  Future<List<LibraryDocument>> load();
  Future<void> save(List<LibraryDocument> documents);
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes);
  Future<List<int>?> readFile(String id);
  Future<List<int>?> readCover(String id);
  Future<void> writeReadingState({
    required String id,
    required double progress,
    required DateTime lastOpened,
  });
}

LibraryDocument importedLibraryDocument(
  String fileName,
  List<int> bytes, {
  List<int>? cover,
}) {
  final format = const FormatDetector().detect(
    DocumentSource(name: fileName, bytes: bytes),
  );
  if (format == DocumentFormat.unknown) {
    throw const FormatException('unsupported document format');
  }
  return LibraryDocument(
    metadata: DocumentMetadata(
      id: fileName,
      title: fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      author: '本地文件',
      format: format,
      type: format.type,
      coverColor: 0xFF6F8179,
      contentHash: contentHash(bytes),
      hasCover: cover != null,
    ),
    readingState: ReadingState(progress: 0, lastOpened: DateTime.now()),
  );
}

LibraryDocument? documentWithHash(
  Iterable<LibraryDocument> documents,
  String hash,
) {
  if (hash.isEmpty) return null;
  for (final document in documents) {
    if (document.metadata.contentHash == hash) return document;
  }
  return null;
}

class SharedPreferencesLibraryRepository implements LibraryRepository {
  SharedPreferencesLibraryRepository(this.preferences);

  static const storageKey = 'universal_reader.library.v1';
  final SharedPreferences preferences;

  @override
  bool get usesRemoteStore => false;

  @override
  Future<List<LibraryDocument>> load() async {
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(LibraryDocumentCodec.fromJson)
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  @override
  Future<void> save(List<LibraryDocument> documents) async {
    final payload = documents.map(LibraryDocumentCodec.toJson).toList();
    await preferences.setString(storageKey, jsonEncode(payload));
  }

  @override
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes) async {
    final documents = await load();
    final existing = documentWithHash(documents, contentHash(bytes));
    if (existing != null) return existing;
    final document = importedLibraryDocument(fileName, bytes);
    documents.removeWhere((item) => item.metadata.id == document.metadata.id);
    documents.insert(0, document);
    await save(documents);
    return document;
  }

  @override
  Future<List<int>?> readFile(String id) async => null;

  @override
  Future<List<int>?> readCover(String id) async => null;

  @override
  Future<void> writeReadingState({
    required String id,
    required double progress,
    required DateTime lastOpened,
  }) async {
    final documents = await load();
    final index = documents.indexWhere((item) => item.metadata.id == id);
    if (index < 0) return;
    documents[index] = documents[index].copyWith(
      readingState: ReadingState(progress: progress, lastOpened: lastOpened),
    );
    await save(documents);
  }
}

class InMemoryLibraryRepository implements LibraryRepository {
  InMemoryLibraryRepository([Iterable<LibraryDocument> initial = const []])
    : _documents = List.of(initial);

  List<LibraryDocument> _documents;
  final Map<String, List<int>> _files = {};
  final Map<String, List<int>> _covers = {};

  @override
  bool get usesRemoteStore => false;

  @override
  Future<List<LibraryDocument>> load() async => List.of(_documents);

  @override
  Future<void> save(List<LibraryDocument> documents) async {
    _documents = List.of(documents);
  }

  @override
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes) async {
    final existing = documentWithHash(_documents, contentHash(bytes));
    if (existing != null) return existing;
    final cover = extractCover(fileName: fileName, bytes: bytes);
    final document = importedLibraryDocument(fileName, bytes, cover: cover);
    _documents.removeWhere((item) => item.metadata.id == document.metadata.id);
    _documents.insert(0, document);
    _files[document.metadata.id] = List<int>.from(bytes);
    if (cover != null) _covers[document.metadata.id] = cover;
    return document;
  }

  @override
  Future<List<int>?> readFile(String id) async {
    final bytes = _files[id];
    return bytes == null ? null : List<int>.from(bytes);
  }

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
  }) async {
    final index = _documents.indexWhere((item) => item.metadata.id == id);
    if (index < 0) return;
    _documents[index] = _documents[index].copyWith(
      readingState: ReadingState(progress: progress, lastOpened: lastOpened),
    );
  }
}

class LibraryDocumentCodec {
  const LibraryDocumentCodec._();

  static Map<String, dynamic> toJson(LibraryDocument document) {
    return {
      'metadata': {
        'id': document.metadata.id,
        'title': document.metadata.title,
        'author': document.metadata.author,
        'format': document.metadata.format.name,
        'type': document.metadata.type.name,
        'coverColor': document.metadata.coverColor,
        'contentHash': document.metadata.contentHash,
        'hasCover': document.metadata.hasCover,
      },
      'readingState': {
        'progress': document.readingState.progress,
        'lastOpened': document.readingState.lastOpened.toIso8601String(),
      },
    };
  }

  static LibraryDocument fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>;
    final readingState = json['readingState'] as Map<String, dynamic>;
    final format = DocumentFormat.values.firstWhere(
      (value) => value.name == metadata['format'],
      orElse: () => DocumentFormat.unknown,
    );
    final type = DocumentType.values.firstWhere(
      (value) => value.name == metadata['type'],
      orElse: () => format.type,
    );
    return LibraryDocument(
      metadata: DocumentMetadata(
        id: metadata['id'] as String,
        title: metadata['title'] as String,
        author: metadata['author'] as String,
        format: format,
        type: type,
        coverColor: (metadata['coverColor'] as num?)?.toInt() ?? 0xFF527882,
        contentHash: metadata['contentHash'] as String? ?? '',
        hasCover: metadata['hasCover'] == true,
      ),
      readingState: ReadingState(
        progress: (readingState['progress'] as num?)?.toDouble() ?? 0,
        lastOpened: DateTime.parse(readingState['lastOpened'] as String),
      ),
    );
  }

  static LibraryDocument fromServiceJson(Map<String, dynamic> json) {
    final formatName = json['format'] as String? ?? 'unknown';
    final format = DocumentFormat.values.firstWhere(
      (value) => value.name == formatName,
      orElse: () => DocumentFormat.unknown,
    );
    final typeName = switch (json['document_type'] as String?) {
      'fixed_page' => DocumentType.fixedPage.name,
      'comic' => DocumentType.comic.name,
      _ => DocumentType.reflow.name,
    };
    final type = DocumentType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => format.type,
    );
    final author = (json['author'] as String?)?.trim() ?? '';
    final lastOpenedMs = (json['last_opened_ms'] as num?)?.toInt() ?? 0;
    return LibraryDocument(
      metadata: DocumentMetadata(
        id: json['id'] as String,
        title: (json['title'] as String?)?.trim().isNotEmpty == true
            ? json['title'] as String
            : (json['file_name'] as String? ?? '未命名'),
        author: author.isEmpty ? '本地书库' : author,
        format: format,
        type: type,
        coverColor: (json['cover_color'] as num?)?.toInt() ?? 0xFF527882,
        contentHash: json['content_hash'] as String? ?? '',
        hasCover: json['has_cover'] == true,
      ),
      readingState: ReadingState(
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        lastOpened: DateTime.fromMillisecondsSinceEpoch(
          lastOpenedMs,
          isUtc: true,
        ).toLocal(),
      ),
    );
  }
}
