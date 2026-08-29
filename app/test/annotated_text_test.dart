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
}
