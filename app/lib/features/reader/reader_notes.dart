import '../library/annotation_store.dart';

String noteListLabel(ReaderAnnotation note) {
  final quote = note.quote.trim();
  if (quote.isNotEmpty) return quote;
  final body = note.note.trim();
  if (body.isNotEmpty) return body;
  return note.locatorLabel;
}
