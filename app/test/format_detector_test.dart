import 'package:app/core/format_detector.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('detects mobi and azw3', () {
    expect(detector.detect(const DocumentSource(name: 'kindle.mobi')), DocumentFormat.mobi);
    expect(detector.detect(const DocumentSource(name: 'kindle.azw3')), DocumentFormat.azw3);
  });

  test('detects fb2', () {
    expect(detector.detect(const DocumentSource(name: 'fiction.fb2')), DocumentFormat.fb2);
  });

  test('detects txt', () {
    expect(detector.detect(const DocumentSource(name: 'notes.txt')), DocumentFormat.txt);
  });

  test('detects markdown with both .md and .markdown extensions', () {
    expect(detector.detect(const DocumentSource(name: 'readme.md')), DocumentFormat.markdown);
    expect(detector.detect(const DocumentSource(name: 'readme.markdown')), DocumentFormat.markdown);
  });

  test('detects html with both .html and .htm extensions', () {
    expect(detector.detect(const DocumentSource(name: 'page.html')), DocumentFormat.html);
    expect(detector.detect(const DocumentSource(name: 'page.htm')), DocumentFormat.html);
  });

  test('detects cbr', () {
    expect(detector.detect(const DocumentSource(name: 'archive.cbr')), DocumentFormat.cbr);
  });

  test('returns unknown for unsupported sources', () {
    expect(
      detector.detect(const DocumentSource(name: 'archive.zip')),
      DocumentFormat.unknown,
    );
  });
}
