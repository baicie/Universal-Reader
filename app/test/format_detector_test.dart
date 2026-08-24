import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/format_detector.dart';
import 'package:app/core/models.dart';

void main() {
  const detector = FormatDetector();

  test('detects container formats from extension as first-pass signal', () {
    expect(
      detector.detect(const DocumentSource(name: 'book.epub')),
      DocumentFormat.epub,
    );
    expect(
      detector.detect(const DocumentSource(name: 'manual.PDF')),
      DocumentFormat.pdf,
    );
    expect(
      detector.detect(const DocumentSource(name: 'chapter.cbz')),
      DocumentFormat.cbz,
    );
  });

  test('returns unknown for unsupported sources', () {
    expect(
      detector.detect(const DocumentSource(name: 'archive.zip')),
      DocumentFormat.unknown,
    );
  });
}
