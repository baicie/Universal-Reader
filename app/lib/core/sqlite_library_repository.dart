import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'content_hash.dart';
import 'cover_extract.dart';
import '../features/library/annotation_store.dart';
import 'library_repository.dart';
import 'models.dart';

class SqliteLibraryRepository implements LibraryRepository {
  SqliteLibraryRepository(this._db);

  final Database _db;

  static Future<SqliteLibraryRepository> memory() async {
    _ensureFfi();
    final db = await openDatabase(inMemoryDatabasePath);
    await migrate(db);
    return SqliteLibraryRepository(db);
  }

  static Future<SqliteLibraryRepository> open(String path) async {
    _ensureFfi();
    final db = await openDatabase(path);
    await migrate(db);
    return SqliteLibraryRepository(db);
  }

  static bool _ffiReady = false;

  static void _ensureFfi() {
    if (_ffiReady) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiReady = true;
  }

  static Future<void> migrate(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  format TEXT NOT NULL,
  type TEXT NOT NULL,
  cover_color INTEGER NOT NULL,
  progress REAL NOT NULL,
  last_opened TEXT NOT NULL,
  file_name TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  file BLOB,
  cover BLOB
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS annotations (
  document_id TEXT NOT NULL,
  id TEXT NOT NULL,
  note TEXT NOT NULL,
  quote TEXT NOT NULL,
  locator_label TEXT NOT NULL,
  source TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (document_id, id)
)
''');
  }

  @override
  bool get usesRemoteStore => false;

  @override
  Future<List<LibraryDocument>> load() async {
    final rows = await _db.query('documents', orderBy: 'last_opened DESC');
    return [for (final row in rows) _documentFromRow(row)];
  }

  @override
  Future<void> save(List<LibraryDocument> documents) async {
    final keep = documents.map((item) => item.metadata.id).toSet();
    final existing = await _db.query('documents', columns: ['id']);
    for (final row in existing) {
      final id = row['id'] as String;
      if (!keep.contains(id)) {
        await _db.delete('documents', where: 'id = ?', whereArgs: [id]);
        await _db.delete(
          'annotations',
          where: 'document_id = ?',
          whereArgs: [id],
        );
      }
    }
    for (final document in documents) {
      final current = await _db.query(
        'documents',
        where: 'id = ?',
        whereArgs: [document.metadata.id],
      );
      await _db.insert('documents', {
        ..._rowFromDocument(document),
        'file': current.isEmpty ? null : current.first['file'],
        'cover': current.isEmpty ? null : current.first['cover'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes) async {
    final hash = contentHash(bytes);
    final existing = await _db.query(
      'documents',
      where: 'content_hash = ?',
      whereArgs: [hash],
    );
    if (existing.isNotEmpty) {
      return _documentFromRow(existing.first);
    }
    final cover = extractCover(fileName: fileName, bytes: bytes);
    final document = importedLibraryDocument(fileName, bytes, cover: cover);
    await _db.insert('documents', {
      ..._rowFromDocument(document),
      'file': Uint8List.fromList(bytes),
      'cover': cover == null ? null : Uint8List.fromList(cover),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return document;
  }

  @override
  Future<List<int>?> readFile(String id) async {
    final rows = await _db.query(
      'documents',
      columns: ['file'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return _blob(rows);
  }

  @override
  Future<List<int>?> readCover(String id) async {
    final rows = await _db.query(
      'documents',
      columns: ['cover'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return _blob(rows);
  }

  @override
  Future<void> writeReadingState({
    required String id,
    required double progress,
    required DateTime lastOpened,
  }) async {
    await _db.update(
      'documents',
      {'progress': progress, 'last_opened': lastOpened.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> migrateFromPreferences(SharedPreferences preferences) async {
    final fallback = SharedPreferencesLibraryRepository(preferences);
    final stored = await fallback.load();
    final existing = await load();
    final ids = {for (final item in existing) item.metadata.id};
    for (final document in stored) {
      if (ids.contains(document.metadata.id)) continue;
      await _db.insert('documents', {
        ..._rowFromDocument(document),
        'file': null,
        'cover': null,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<ReaderAnnotation>> loadAnnotations(String documentId) async {
    final rows = await _db.query(
      'annotations',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'created_at_ms',
    );
    return [
      for (final row in rows)
        ReaderAnnotation(
          id: row['id'] as String,
          note: row['note'] as String,
          quote: row['quote'] as String,
          locatorLabel: row['locator_label'] as String,
          source: row['source'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at_ms'] as int,
            isUtc: true,
          ),
        ),
    ];
  }

  Future<void> saveAnnotations(
    String documentId,
    List<ReaderAnnotation> notes,
  ) async {
    await _db.delete(
      'annotations',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
    for (final note in trimAnnotations(notes)) {
      await _db.insert('annotations', {
        'document_id': documentId,
        'id': note.id,
        'note': note.note,
        'quote': note.quote,
        'locator_label': note.locatorLabel,
        'source': note.source,
        'created_at_ms': note.createdAt.toUtc().millisecondsSinceEpoch,
      });
    }
  }

  Map<String, Object?> _rowFromDocument(LibraryDocument document) {
    return {
      'id': document.metadata.id,
      'title': document.metadata.title,
      'author': document.metadata.author,
      'format': document.metadata.format.name,
      'type': document.metadata.type.name,
      'cover_color': document.metadata.coverColor,
      'progress': document.readingState.progress,
      'last_opened': document.readingState.lastOpened.toIso8601String(),
      'file_name': document.metadata.id,
      'content_hash': document.metadata.contentHash,
    };
  }

  LibraryDocument _documentFromRow(Map<String, Object?> row) {
    final format = DocumentFormat.values.firstWhere(
      (value) => value.name == row['format'],
      orElse: () => DocumentFormat.unknown,
    );
    final type = DocumentType.values.firstWhere(
      (value) => value.name == row['type'],
      orElse: () => format.type,
    );
    return LibraryDocument(
      metadata: DocumentMetadata(
        id: row['id'] as String,
        title: row['title'] as String,
        author: row['author'] as String,
        format: format,
        type: type,
        coverColor: (row['cover_color'] as num?)?.toInt() ?? 0xFF527882,
        contentHash: row['content_hash'] as String? ?? '',
        hasCover: row['cover'] != null,
      ),
      readingState: ReadingState(
        progress: (row['progress'] as num?)?.toDouble() ?? 0,
        lastOpened: DateTime.parse(row['last_opened'] as String),
      ),
    );
  }

  Future<void> close() => _db.close();

  List<int>? _blob(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return null;
    final value = rows.first.values.first;
    if (value is List<int>) return List<int>.from(value);
    return null;
  }
}

class SqliteAnnotationRepository implements AnnotationRepository {
  SqliteAnnotationRepository(this.library);

  final SqliteLibraryRepository library;

  @override
  Future<List<ReaderAnnotation>> load(String documentId) =>
      library.loadAnnotations(documentId);

  @override
  Future<void> save(String documentId, List<ReaderAnnotation> notes) =>
      library.saveAnnotations(documentId, notes);
}
