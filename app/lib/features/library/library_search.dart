import '../../core/models.dart';
import 'annotation_store.dart';

/// One hit emitted by [librarySearchAll]. Either a metadata match or a
/// note (annotation) match.
enum LibrarySearchHitKind { metadata, note }

class LibrarySearchHit {
  const LibrarySearchHit({
    required this.document,
    required this.kind,
    this.annotation,
  });

  final LibraryDocument document;
  final LibrarySearchHitKind kind;

  /// Populated only when [kind] == [LibrarySearchHitKind.note].
  final ReaderAnnotation? annotation;
}

/// Compares haystack against [needle] case-insensitively.
bool _looseContains(String haystack, String needle) {
  if (needle.isEmpty) return true;
  return haystack.toLowerCase().contains(needle.toLowerCase());
}

/// Documents whose metadata fields contain [query] (deduplicated by id).
List<LibraryDocument> _metadataMatches(
  Iterable<LibraryDocument> documents,
  String query,
) {
  if (query.isEmpty) return const [];
  final hits = <LibraryDocument>[];
  final seen = <String>{};
  for (final document in documents) {
    if (seen.add(document.metadata.id) &&
        (_looseContains(document.metadata.title, query) ||
            _looseContains(document.metadata.author, query))) {
      hits.add(document);
    }
  }
  return hits;
}

/// Async variant for the same scan plus annotation hits, both groups
/// ordered by most-recently-opened first.
Future<List<LibrarySearchHit>> librarySearchAllAsync({
  required Iterable<LibraryDocument> documents,
  required String query,
  required Future<List<ReaderAnnotation>> Function(String documentId)
  annotationsFor,
}) async {
  if (query.isEmpty) {
    return [
      for (final document in _byLastOpened(documents))
        LibrarySearchHit(
          document: document,
          kind: LibrarySearchHitKind.metadata,
        ),
    ];
  }

  final seenNote = <String>{};
  final metadataHits = <LibraryDocument>[];
  final noteHits = <LibrarySearchHit>[];
  for (final document in documents) {
    final matchesMetadata =
        _looseContains(document.metadata.title, query) ||
        _looseContains(document.metadata.author, query);
    if (matchesMetadata) {
      metadataHits.add(document);
    }
    // Even when metadata matches, still scan annotations for a note hit.
    if (seenNote.add(document.metadata.id)) {
      try {
        final annotations = await annotationsFor(document.metadata.id);
        for (final annotation in annotations) {
          if (_looseContains(annotation.quote, query) ||
              _looseContains(annotation.note, query) ||
              _looseContains(annotation.locatorLabel, query)) {
            // A metadata match demotes the same document's note hit.
            if (matchesMetadata) {
              seenNote.remove(document.metadata.id);
            } else {
              noteHits.add(
                LibrarySearchHit(
                  document: document,
                  kind: LibrarySearchHitKind.note,
                  annotation: annotation,
                ),
              );
            }
            break;
          }
        }
      } on Object {
        // Treat unreadable annotation stores as no contribution.
        continue;
      }
    }
  }

  return [
    ..._byLastOpened(metadataHits).map(
      (document) => LibrarySearchHit(
        document: document,
        kind: LibrarySearchHitKind.metadata,
      ),
    ),
    ..._byLastOpened(noteHits.map((hit) => hit.document)).map(
      (latest) => noteHits.firstWhere(
        (hit) => hit.document.metadata.id == latest.metadata.id,
      ),
    ),
  ];
}

/// Synchronous variant: metadata-only when [annotationsFor] is omitted.
List<LibrarySearchHit> librarySearchAll({
  required Iterable<LibraryDocument> documents,
  required String query,
  Future<List<ReaderAnnotation>> Function(String documentId)? annotationsFor,
}) {
  if (annotationsFor == null) {
    if (query.isEmpty) {
      return [
        for (final document in _byLastOpened(documents))
          LibrarySearchHit(
            document: document,
            kind: LibrarySearchHitKind.metadata,
          ),
      ];
    }
    return [
      for (final document in _byLastOpened(_metadataMatches(documents, query)))
        LibrarySearchHit(
          document: document,
          kind: LibrarySearchHitKind.metadata,
        ),
    ];
  }
  // Fall through to the async path for callers that can't await.
  return const [];
}

Iterable<LibraryDocument> _byLastOpened(Iterable<LibraryDocument> documents) {
  final list = List<LibraryDocument>.of(documents);
  list.sort(
    (a, b) => b.readingState.lastOpened.compareTo(a.readingState.lastOpened),
  );
  return list;
}
