import '../library/annotation_store.dart';

ReaderAnnotation? noteFromSelection(
  String quote, {
  String locatorLabel = '',
  DateTime? now,
  String note = '',
}) {
  final trimmed = quote.trim();
  if (trimmed.isEmpty) return null;
  final createdAt = now ?? DateTime.now().toUtc();
  return ReaderAnnotation(
    id: 'sel-${createdAt.microsecondsSinceEpoch}',
    note: note,
    quote: trimmed,
    locatorLabel: locatorLabel,
    source: userNoteSource,
    createdAt: createdAt,
  );
}
