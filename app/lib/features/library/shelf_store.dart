import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/http_library_repository.dart';
import '../../core/library_repository.dart';
import '../../core/sqlite_library_repository.dart';

const favoritesSection = 'favorites';
const collectionSectionPrefix = 'collection:';
const maxCollections = 50;
const maxCollectionName = 40;
const collectionColors = <int>[0xFFC69355, 0xFF6C9EB4, 0xFFA25848, 0xFF314D49];

String collectionSection(String id) => '$collectionSectionPrefix$id';

class LibraryCollection {
  const LibraryCollection({
    required this.id,
    required this.name,
    required this.color,
    this.documentIds = const [],
  });

  final String id;
  final String name;
  final int color;
  final List<String> documentIds;

  bool contains(String documentId) => documentIds.contains(documentId);

  LibraryCollection copyWith({List<String>? documentIds}) {
    return LibraryCollection(
      id: id,
      name: name,
      color: color,
      documentIds: documentIds ?? this.documentIds,
    );
  }

  Map<String, dynamic> toServiceJson() => {
    'id': id,
    'name': name,
    'color': color,
    'document_ids': documentIds,
  };

  factory LibraryCollection.fromJson(Map<String, dynamic> json) {
    final ids = json['document_ids'] ?? json['documentIds'];
    return LibraryCollection(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: (json['color'] as num?)?.toInt() ?? collectionColors.first,
      documentIds: [
        if (ids is List)
          for (final id in ids)
            if (id is String && id.isNotEmpty) id,
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryCollection &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      _sameList(other.documentIds, documentIds);

  @override
  int get hashCode => Object.hash(id, name, color, Object.hashAll(documentIds));
}

class LibraryShelves {
  const LibraryShelves({
    this.favoriteIds = const {},
    this.collections = const [],
  });

  final Set<String> favoriteIds;
  final List<LibraryCollection> collections;

  Map<String, dynamic> toServiceJson() => {
    'favorites': favoriteIds.toList(),
    'collections': [
      for (final collection in collections) collection.toServiceJson(),
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is LibraryShelves &&
      _sameSet(other.favoriteIds, favoriteIds) &&
      _sameList(other.collections, collections);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(favoriteIds), Object.hashAll(collections));
}

bool documentMatchesSection({
  required String section,
  required String documentId,
  required double progress,
  required LibraryShelves shelves,
}) {
  if (section == 'reading') return progress > 0 && progress < 1;
  if (section == favoritesSection) {
    return shelves.favoriteIds.contains(documentId);
  }
  if (section.startsWith(collectionSectionPrefix)) {
    final id = section.substring(collectionSectionPrefix.length);
    for (final collection in shelves.collections) {
      if (collection.id == id) return collection.contains(documentId);
    }
    return false;
  }
  return true;
}

LibraryShelves toggleFavorite(LibraryShelves shelves, String documentId) {
  if (documentId.isEmpty) return shelves;
  final next = {...shelves.favoriteIds};
  if (!next.add(documentId)) next.remove(documentId);
  return LibraryShelves(favoriteIds: next, collections: shelves.collections);
}

LibraryShelves addCollection(
  LibraryShelves shelves, {
  required String name,
  DateTime? now,
  int? color,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || shelves.collections.length >= maxCollections) {
    return shelves;
  }
  final clipped = trimmed.length <= maxCollectionName
      ? trimmed
      : trimmed.substring(0, maxCollectionName);
  final stamp = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
  final id = 'c-$stamp-${shelves.collections.length}';
  final nextColor =
      color ??
      collectionColors[shelves.collections.length % collectionColors.length];
  return LibraryShelves(
    favoriteIds: shelves.favoriteIds,
    collections: [
      ...shelves.collections,
      LibraryCollection(id: id, name: clipped, color: nextColor),
    ],
  );
}

LibraryShelves addToCollection(
  LibraryShelves shelves,
  String collectionId,
  String documentId,
) {
  if (collectionId.isEmpty || documentId.isEmpty) return shelves;
  return LibraryShelves(
    favoriteIds: shelves.favoriteIds,
    collections: [
      for (final collection in shelves.collections)
        if (collection.id != collectionId)
          collection
        else if (collection.contains(documentId))
          collection
        else
          collection.copyWith(
            documentIds: [...collection.documentIds, documentId],
          ),
    ],
  );
}

LibraryShelves removeFromCollection(
  LibraryShelves shelves,
  String collectionId,
  String documentId,
) {
  return LibraryShelves(
    favoriteIds: shelves.favoriteIds,
    collections: [
      for (final collection in shelves.collections)
        if (collection.id != collectionId)
          collection
        else
          collection.copyWith(
            documentIds: [
              for (final id in collection.documentIds)
                if (id != documentId) id,
            ],
          ),
    ],
  );
}

LibraryShelves toggleInCollection(
  LibraryShelves shelves,
  String collectionId,
  String documentId,
) {
  final inCollection = shelves.collections.any(
    (collection) =>
        collection.id == collectionId && collection.contains(documentId),
  );
  return inCollection
      ? removeFromCollection(shelves, collectionId, documentId)
      : addToCollection(shelves, collectionId, documentId);
}

LibraryShelves removeCollection(LibraryShelves shelves, String collectionId) {
  return LibraryShelves(
    favoriteIds: shelves.favoriteIds,
    collections: [
      for (final collection in shelves.collections)
        if (collection.id != collectionId) collection,
    ],
  );
}

LibraryShelves pruneShelves(
  LibraryShelves shelves,
  Iterable<String> knownDocumentIds,
) {
  final known = knownDocumentIds.toSet();
  return LibraryShelves(
    favoriteIds: {
      for (final id in shelves.favoriteIds)
        if (known.contains(id)) id,
    },
    collections: [
      for (final collection in shelves.collections)
        if (collection.id.isNotEmpty && collection.name.trim().isNotEmpty)
          collection.copyWith(
            documentIds: [
              for (final id in collection.documentIds)
                if (known.contains(id)) id,
            ],
          ),
    ],
  );
}

LibraryShelves parseShelves(Object? raw) {
  final decoded = raw is String ? jsonDecode(raw) : raw;
  if (decoded is! Map) {
    throw const FormatException('corrupt shelves');
  }
  final json = Map<String, dynamic>.from(decoded);
  final favorites = json['favorites'];
  final collections = json['collections'];
  return LibraryShelves(
    favoriteIds: {
      if (favorites is List)
        for (final id in favorites)
          if (id is String && id.isNotEmpty) id,
    },
    collections: [
      if (collections is List)
        for (final item in collections)
          if (item is Map)
            LibraryCollection.fromJson(Map<String, dynamic>.from(item)),
    ],
  );
}

abstract interface class ShelfRepository {
  Future<LibraryShelves> load();
  Future<void> save(LibraryShelves shelves);
}

class InMemoryShelfRepository implements ShelfRepository {
  LibraryShelves _shelves = const LibraryShelves();

  @override
  Future<LibraryShelves> load() async => _shelves;

  @override
  Future<void> save(LibraryShelves shelves) async {
    _shelves = shelves;
  }
}

class SharedPreferencesShelfRepository implements ShelfRepository {
  SharedPreferencesShelfRepository(this.preferences);

  static const storageKey = 'universal_reader.shelves.v1';
  final SharedPreferences preferences;

  @override
  Future<LibraryShelves> load() async {
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return const LibraryShelves();
    return parseShelves(raw);
  }

  @override
  Future<void> save(LibraryShelves shelves) async {
    await preferences.setString(
      storageKey,
      jsonEncode(shelves.toServiceJson()),
    );
  }
}

class SqliteShelfRepository implements ShelfRepository {
  SqliteShelfRepository(this.library);

  static const settingsKey = 'shelves';
  final SqliteLibraryRepository library;

  @override
  Future<LibraryShelves> load() async {
    final raw = await library.readSetting(settingsKey);
    if (raw == null || raw.isEmpty) return const LibraryShelves();
    return parseShelves(raw);
  }

  @override
  Future<void> save(LibraryShelves shelves) {
    return library.writeSetting(
      settingsKey,
      jsonEncode(shelves.toServiceJson()),
    );
  }
}

class HttpShelfRepository implements ShelfRepository {
  HttpShelfRepository({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Uri get _uri {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root/v1/library/shelves');
  }

  @override
  Future<LibraryShelves> load() async {
    final response = await _http.get(_uri);
    if (response.statusCode == 404) return const LibraryShelves();
    if (response.statusCode != 200) {
      throw FormatException('无法读取收藏夹 (${response.statusCode})');
    }
    return parseShelves(response.body);
  }

  @override
  Future<void> save(LibraryShelves shelves) async {
    final response = await _http.put(
      _uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(shelves.toServiceJson()),
    );
    if (response.statusCode != 200) {
      throw FormatException('无法保存收藏夹 (${response.statusCode})');
    }
  }
}

ShelfRepository resolveShelfRepository(
  LibraryRepository library,
  SharedPreferences preferences,
) {
  if (library is HttpLibraryRepository) {
    return HttpShelfRepository(
      baseUrl: library.baseUrl,
      httpClient: library.httpClient,
    );
  }
  if (library is SqliteLibraryRepository) {
    return SqliteShelfRepository(library);
  }
  return SharedPreferencesShelfRepository(preferences);
}

bool _sameSet(Set<Object?> a, Set<Object?> b) =>
    a.length == b.length && a.containsAll(b);

bool _sameList(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
