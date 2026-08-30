import 'package:app/core/annotated_text.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks a quote that appears in the chapter', () {
    final spans = annotatePlainText('before hello from notes after', [
      ReaderAnnotation(
        id: 'n1',
        note: 'keep',
        quote: 'hello from notes',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    expect(spans, hasLength(3));
    expect((spans[1] as TextSpan).text, 'hello from notes');
    expect((spans[1] as TextSpan).style?.backgroundColor, isNotNull);
  });

  test('does not paint bookmark records as highlights', () {
    final spans = annotatePlainText('hello from notes', [
      ReaderAnnotation(
        id: 'bm1',
        note: '',
        quote: 'hello from notes',
        source: bookmarkSource,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    expect(spans, hasLength(1));
    expect((spans.single as TextSpan).style?.backgroundColor, isNull);
  });

  test('leaves the chapter alone when the quote is missing', () {
    final spans = annotatePlainText('no match here', [
      ReaderAnnotation(
        id: 'n1',
        note: 'keep',
        quote: 'hello from notes',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    expect(spans, hasLength(1));
    expect((spans.single as TextSpan).text, 'no match here');
  });

  test('quote highlights skip bookmarks and empty quotes', () {
    expect(
      quoteHighlights([
        ReaderAnnotation(
          id: 'n1',
          note: 'keep',
          quote: 'hello from notes',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        ReaderAnnotation(
          id: 'bm1',
          note: '',
          quote: 'hello from notes',
          source: bookmarkSource,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        ReaderAnnotation(
          id: 'n2',
          note: 'empty',
          quote: '   ',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]),
      ['hello from notes'],
    );
  });
}
