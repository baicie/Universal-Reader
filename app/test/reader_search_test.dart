import 'dart:convert';

import 'package:app/core/models.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/reader_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TextReaderDocument document() {
    return TextReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'notes.txt',
        title: 'notes',
        author: '',
        format: DocumentFormat.txt,
        type: DocumentType.reflow,
      ),
      bytes: utf8.encode('hello from notes'),
    );
  }

  test('empty search stays missing', () async {
    expect(await hitsForQuery(document(), '   '), isEmpty);
    expect(await hitsForQuery(document(), ''), isEmpty);
  });

  test('a miss stays missing instead of inventing another book', () async {
    expect(await hitsForQuery(document(), 'not-in-this-book'), isEmpty);
  });

  test('a hit stays on the current book', () async {
    final hits = await hitsForQuery(document(), 'hello from notes');
    expect(hits, hasLength(1));
    expect(hits.single.locator, isA<TextLocator>());
    expect(hits.single.excerpt, contains('hello from notes'));
  });
}
