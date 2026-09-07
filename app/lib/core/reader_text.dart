import 'reader_runtime.dart';

/// Returns the current chapter body for a reader document, or an empty
/// string when the document does not expose chapter text. Centralises the
/// `ReaderDocument? → ChapteredDocument` branch so callers do not repeat
/// the type check.
String readerCurrentBody(ReaderDocument? reader) {
  final chaptered = reader is ChapteredDocument ? reader : null;
  return chaptered?.currentChapterText ?? '';
}

/// Splits raw text into display paragraphs. Lines separated by one or more
/// newlines become paragraph boundaries; blank lines are dropped and each
/// surviving paragraph is trimmed.
///
/// Used by the plain-text fallback renderer and the chapter-text reader
/// in the same way; keeping a single implementation ensures both paths
/// treat whitespace identically.
List<String> splitTextParagraphs(String text) {
  return text
      .split(RegExp(r'\n+'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .toList();
}
