import 'package:app/core/models.dart';
import 'package:app/core/reader_text.dart';
import 'package:app/core/text_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DocumentMetadata metadata(DocumentFormat format) => DocumentMetadata(
    id: 'a',
    title: 'A',
    author: 'A',
    format: format,
    type: DocumentType.reflow,
  );

  group('readerCurrentBody', () {
    test('returns an empty string when the reader is null', () {
      expect(readerCurrentBody(null), '');
    });

    test('returns an empty string for documents that are not chaptered', () {
      final corrupt = CorruptReaderDocument(
        metadata: metadata(DocumentFormat.epub),
      );
      expect(readerCurrentBody(corrupt), '');
    });

    test('returns the current chapter text when the document is chaptered', () {
      final chaptered = TextReaderDocument.parse(
        metadata: metadata(DocumentFormat.txt),
        bytes: 'Line 1\nLine 2\n\nLine 3'.codeUnits,
      );
      // section 0 is the first block; section 1 is the second block.
      expect(chaptered.chapterCount, 2);
      expect(readerCurrentBody(chaptered), 'Line 1\nLine 2');
      chaptered.sectionIndex = 1;
      expect(readerCurrentBody(chaptered), 'Line 3');
    });

    test('returns empty string for an unavailable (non-chaptered) opener', () {
      final unavailable = UnavailableReaderDocument(
        metadata: metadata(DocumentFormat.epub),
      );
      expect(readerCurrentBody(unavailable), '');
    });
  });

  group('splitTextParagraphs', () {
    test('splits on single newlines', () {
      expect(splitTextParagraphs('a\nb\nc'), ['a', 'b', 'c']);
    });

    test('collapses runs of blank lines into a single boundary', () {
      expect(splitTextParagraphs('a\n\n\nb'), ['a', 'b']);
    });

    test('trims surrounding whitespace from each paragraph', () {
      expect(splitTextParagraphs('  a  \n\tb\t'), ['a', 'b']);
    });

    test('drops paragraphs that become empty after trimming', () {
      expect(splitTextParagraphs('a\n   \n  \nb'), ['a', 'b']);
    });

    test('returns an empty list when the input is empty', () {
      expect(splitTextParagraphs(''), isEmpty);
    });

    test('returns an empty list when the input is only whitespace', () {
      expect(splitTextParagraphs('  \n\t\n  \n'), isEmpty);
    });

    test('handles CRLF / mixed line endings', () {
      expect(splitTextParagraphs('a\r\nb\r\nc'), ['a', 'b', 'c']);
    });

    test('preserves in-paragraph spaces and punctuation', () {
      expect(splitTextParagraphs('Hello, world.\nGoodbye.'), [
        'Hello, world.',
        'Goodbye.',
      ]);
    });
  });
}
