import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'content_hash.dart';
import 'cover_extract.dart';
import 'library_repository.dart';
import 'models.dart';

class WebPersistentLibraryRepository implements LibraryRepository {
  WebPersistentLibraryRepository(this.preferences);

  static const filePrefix = 'universal_reader.files.v1.';
  static const coverPrefix = 'universal_reader.covers.v1.';

  final SharedPreferences preferences;

  @override
  bool get usesRemoteStore => false;

  @override
  Future<List<LibraryDocument>> load() {
    return SharedPreferencesLibraryRepository(preferences).load();
  }

  @override
  Future<void> save(List<LibraryDocument> documents) {
    return SharedPreferencesLibraryRepository(preferences).save(documents);
  }

  @override
  Future<LibraryDocument> importBytes(String fileName, List<int> bytes) async {
    final documents = await load();
    final existing = documentWithHash(documents, contentHash(bytes));
    if (existing != null) return existing;
    final cover = extractCover(fileName: fileName, bytes: bytes);
    final document = importedLibraryDocument(fileName, bytes, cover: cover);
    documents.removeWhere((item) => item.metadata.id == document.metadata.id);
    documents.insert(0, document);
    await save(documents);
    await preferences.setString(
      '$filePrefix${document.metadata.id}',
      base64Encode(bytes),
    );
    if (cover != null) {
      await preferences.setString(
        '$coverPrefix${document.metadata.id}',
        base64Encode(cover),
      );
    }
    return document;
  }

  @override
  Future<List<int>?> readFile(String id) async {
    final raw = preferences.getString('$filePrefix$id');
    if (raw == null || raw.isEmpty) return null;
    return base64Decode(raw);
  }

  @override
  Future<List<int>?> readCover(String id) async {
    final raw = preferences.getString('$coverPrefix$id');
    if (raw == null || raw.isEmpty) return null;
    return base64Decode(raw);
  }

  @override
  Future<void> writeReadingState({
    required String id,
    required double progress,
    required DateTime lastOpened,
  }) {
    return SharedPreferencesLibraryRepository(preferences)
        .writeReadingState(id: id, progress: progress, lastOpened: lastOpened);
  }

  @override
  Future<void> writeIdentity({
    required String id,
    required String title,
    required String author,
  }) {
    return SharedPreferencesLibraryRepository(preferences)
        .writeIdentity(id: id, title: title, author: author);
  }

  @override
  Future<void> delete(String id) async {
    await SharedPreferencesLibraryRepository(preferences).delete(id);
    await preferences.remove('$filePrefix$id');
    await preferences.remove('$coverPrefix$id');
  }

  Future<void> migrateFromPreferences(SharedPreferences preferences) async {
    // Web 与 SharedPreferences 共用书目键，迁目录只是确保仓库已打开。
  }
}
