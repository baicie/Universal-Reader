import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../features/library/annotation_store.dart';

const annotatedQuoteKey = ValueKey('annotated-quote');

List<String> quoteHighlights(List<ReaderAnnotation> notes) {
  return [
    for (final note in notes)
      if (note.source != bookmarkSource && note.quote.trim().isNotEmpty)
        note.quote.trim(),
  ];
}

List<InlineSpan> annotatePlainText(
  String text,
  List<ReaderAnnotation> notes, {
  TextStyle? style,
  Color highlight = const Color(0x66C4A574),
}) {
  final quotes = [...quoteHighlights(notes)]
    ..sort((a, b) => b.length.compareTo(a.length));
  if (quotes.isEmpty || text.isEmpty) {
    return [TextSpan(text: text, style: style)];
  }
  final spans = <InlineSpan>[];
  var cursor = 0;
  while (cursor < text.length) {
    var hitAt = -1;
    var hit = '';
    for (final quote in quotes) {
      final at = text.indexOf(quote, cursor);
      if (at < 0) continue;
      if (hitAt < 0 || at < hitAt) {
        hitAt = at;
        hit = quote;
      }
    }
    if (hitAt < 0) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
      break;
    }
    if (hitAt > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, hitAt), style: style));
    }
    spans.add(
      TextSpan(
        text: hit,
        style: (style ?? const TextStyle()).copyWith(
          backgroundColor: highlight,
        ),
      ),
    );
    cursor = hitAt + hit.length;
  }
  return spans.isEmpty ? [TextSpan(text: text, style: style)] : spans;
}
