import 'dart:convert';
import 'dart:io';

import 'package:app/core/format_detector.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/open_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final corpus = Directory(
    Directory('../test-books').existsSync() ? '../test-books' : 'test-books',
  );
  final manifest = jsonDecode(
    File('${corpus.path}/manifest.json').readAsStringSync(),
  ) as List<dynamic>;

  for (final raw in manifest.cast<Map<String, dynamic>>()) {
    test('${raw['format']} corpus sample detects and opens', () async {
      final path = raw['path'] as String;
      final bytes = await File('${corpus.path}/$path').readAsBytes();
      final expected = DocumentFormat.values.byName(raw['format'] as String);

      expect(bytes.length, raw['bytes']);
      expect(sha256.convert(bytes).toString(), raw['sha256']);
      expect(
        const FormatDetector().detect(
          DocumentSource(name: path.split('/').last, bytes: bytes),
        ),
        expected,
      );

      final document = await openReaderDocumentAsync(
        metadata: DocumentMetadata(
          id: path,
          title: path,
          author: '',
          format: expected,
          type: expected.type,
        ),
        bytes: bytes,
      );
      expect(document, isNot(isA<CorruptReaderDocument>()));
      expect(document, isNot(isA<UnavailableReaderDocument>()));
      expect((document as ChapteredDocument).chapterCount, greaterThan(0));
    });
  }
}
