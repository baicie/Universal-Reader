import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

abstract interface class LibraryRepository {
  Future<List<LibraryDocument>> load();
  Future<void> save(List<LibraryDocument> documents);
}

class SharedPreferencesLibraryRepository implements LibraryRepository {
  SharedPreferencesLibraryRepository(this.preferences);

  static const storageKey = 'universal_reader.library.v1';
  final SharedPreferences preferences;

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
}

class InMemoryLibraryRepository implements LibraryRepository {
  InMemoryLibraryRepository([Iterable<LibraryDocument> initial = const []])
    : _documents = List.of(initial);

  List<LibraryDocument> _documents;

  @override
  Future<List<LibraryDocument>> load() async => List.of(_documents);

  @override
  Future<void> save(List<LibraryDocument> documents) async {
    _documents = List.of(documents);
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
      ),
      readingState: ReadingState(
        progress: (readingState['progress'] as num?)?.toDouble() ?? 0,
        lastOpened: DateTime.parse(readingState['lastOpened'] as String),
      ),
    );
  }
}
