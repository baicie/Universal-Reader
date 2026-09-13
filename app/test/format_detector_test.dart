import 'dart:convert';

import 'package:app/core/format_detector.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/docx_fixture.dart';
import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';
import 'support/odt_fixture.dart';
import 'support/rar_fixture.dart';

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
    expect(
      detector.detect(const DocumentSource(name: 'kindle.mobi')),
      DocumentFormat.mobi,
    );
    expect(
      detector.detect(const DocumentSource(name: 'kindle.azw3')),
      DocumentFormat.azw3,
    );
  });

  test('detects fb2', () {
    expect(
      detector.detect(const DocumentSource(name: 'fiction.fb2')),
      DocumentFormat.fb2,
    );
  });

  test('detects txt', () {
    expect(
      detector.detect(const DocumentSource(name: 'notes.txt')),
      DocumentFormat.txt,
    );
  });

  test('detects markdown with both .md and .markdown extensions', () {
    expect(
      detector.detect(const DocumentSource(name: 'readme.md')),
      DocumentFormat.markdown,
    );
    expect(
      detector.detect(const DocumentSource(name: 'readme.markdown')),
      DocumentFormat.markdown,
    );
  });

  test('detects html with both .html and .htm extensions', () {
    expect(
      detector.detect(const DocumentSource(name: 'page.html')),
      DocumentFormat.html,
    );
    expect(
      detector.detect(const DocumentSource(name: 'page.htm')),
      DocumentFormat.html,
    );
  });

  test('detects cbr', () {
    expect(
      detector.detect(const DocumentSource(name: 'archive.cbr')),
      DocumentFormat.cbr,
    );
  });

  test('returns unknown for unsupported sources', () {
    expect(
      detector.detect(const DocumentSource(name: 'archive.zip')),
      DocumentFormat.unknown,
    );
  });

  test('detects epub content when the extension is unrelated', () {
    expect(
      detector.detect(
        DocumentSource(name: 'book.bin', bytes: minimalEpubBytes()),
      ),
      DocumentFormat.epub,
    );
  });

  test('detects cbz content when the extension is unrelated', () {
    final bytes = zipNamedFiles({'page-01.png': tinyPngBytes()});
    expect(
      detector.detect(DocumentSource(name: 'book.bin', bytes: bytes)),
      DocumentFormat.cbz,
    );
  });

  test('detects docx content when the extension is unrelated', () {
    expect(
      detector.detect(
        DocumentSource(name: 'book.bin', bytes: minimalDocxBytes()),
      ),
      DocumentFormat.docx,
    );
  });

  test('detects odt content when the extension is unrelated', () {
    expect(
      detector.detect(
        DocumentSource(name: 'book.bin', bytes: minimalOdtBytes()),
      ),
      DocumentFormat.odt,
    );
  });

  test('detects pdf content before trusting the extension', () {
    expect(
      detector.detect(
        DocumentSource(name: 'notes.txt', bytes: utf8.encode('%PDF-1.7\n')),
      ),
      DocumentFormat.pdf,
    );
  });

  test('detects real cbr content from the RAR signature', () {
    expect(
      detector.detect(
        DocumentSource(name: 'book.bin', bytes: syntheticCbrBytes()),
      ),
      DocumentFormat.cbr,
    );
  });

  test('detects fb2 and html XML content without an extension', () {
    expect(
      detector.detect(
        DocumentSource(
          name: 'book.bin',
          bytes: utf8.encode(
            '<?xml version="1.0"?><FictionBook '
            'xmlns="http://www.gribuser.ru/xml/fictionbook/2.0"></FictionBook>',
          ),
        ),
      ),
      DocumentFormat.fb2,
    );
    expect(
      detector.detect(
        DocumentSource(
          name: 'book.bin',
          bytes: utf8.encode('<!doctype html><html><body>x</body></html>'),
        ),
      ),
      DocumentFormat.html,
    );
  });

  test('detects markdown and plain text content without an extension', () {
    expect(
      detector.detect(
        DocumentSource(
          name: 'book.bin',
          bytes: utf8.encode('# Heading\n\nBody'),
        ),
      ),
      DocumentFormat.markdown,
    );
    expect(
      detector.detect(
        DocumentSource(name: 'book.bin', bytes: utf8.encode('plain body')),
      ),
      DocumentFormat.txt,
    );
  });

  test('detects Mobipocket content and keeps azw3 as the subtype', () {
    final mobi = List<int>.filled(96, 0);
    mobi.setRange(60, 64, ascii.encode('BOOK'));
    mobi.setRange(64, 68, ascii.encode('MOBI'));

    expect(
      detector.detect(DocumentSource(name: 'book.bin', bytes: mobi)),
      DocumentFormat.mobi,
    );
    expect(
      detector.detect(DocumentSource(name: 'book.azw3', bytes: mobi)),
      DocumentFormat.azw3,
    );
  });

  test('keeps extension fallback for malformed known files', () {
    expect(
      detector.detect(
        DocumentSource(name: 'book.epub', bytes: utf8.encode('not a zip')),
      ),
      DocumentFormat.epub,
    );
  });
}
