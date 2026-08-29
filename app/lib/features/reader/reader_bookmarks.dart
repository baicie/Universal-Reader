import '../../core/locator_codec.dart';
import '../../core/models.dart';
import '../library/annotation_store.dart';

bool isBookmark(ReaderAnnotation note) => note.source == bookmarkSource;

List<ReaderAnnotation> bookmarksOf(List<ReaderAnnotation> notes) {
  return [
    for (final note in notes)
      if (isBookmark(note)) note,
  ];
}

List<ReaderAnnotation> notesOf(List<ReaderAnnotation> notes) {
  return [
    for (final note in notes)
      if (!isBookmark(note)) note,
  ];
}

ReaderAnnotation bookmarkAt({required Locator locator, DateTime? now}) {
  final createdAt = now ?? DateTime.now().toUtc();
  return ReaderAnnotation(
    id: 'bm-${createdAt.microsecondsSinceEpoch}',
    note: '',
    quote: '',
    locatorLabel: encodeLocator(locator),
    source: bookmarkSource,
    createdAt: createdAt,
  );
}
