import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../test/support/docx_fixture.dart';
import '../test/support/epub_fixture.dart';
import '../test/support/fb2_fixture.dart';
import '../test/support/image_fixture.dart';
import '../test/support/odt_fixture.dart';
import '../test/support/pdf_fixture.dart';
import '../test/support/rar_fixture.dart';

Future<void> main() async {
  final root = Directory('../test-books');
  await root.create(recursive: true);

  final books = <String, List<int>>{
    'epub/minimal.epub': minimalEpubBytes(),
    'pdf/minimal.pdf': minimalPdfBytes(),
    'mobi/minimal.mobi': _mobipocketBytes(azw3: false),
    'azw3/minimal.azw3': _mobipocketBytes(azw3: true),
    'fb2/minimal.fb2': minimalFb2Bytes(),
    'txt/minimal.txt': utf8.encode(
      'Universal Reader compatibility sample.\n'
      'This text exists to verify TXT import and decoding.\n',
    ),
    'markdown/minimal.md': utf8.encode(
      '# Universal Reader\n\n'
      'This sample verifies Markdown import.\n',
    ),
    'html/minimal.html': utf8.encode(
      '<!doctype html><html><head><title>Universal Reader</title></head>'
      '<body><h1>Compatibility sample</h1><p>HTML import works.</p>'
      '</body></html>',
    ),
    'docx/minimal.docx': minimalDocxBytes(),
    'odt/minimal.odt': minimalOdtBytes(),
    'cbz/minimal.cbz': zipNamedFiles({
      'page-01.png': tinyPngBytes(),
      'page-02.png': tinyPngBytes(),
    }),
    'cbr/minimal.cbr': syntheticCbrBytes(),
  };

  final manifest = <Map<String, Object>>[];
  for (final entry in books.entries) {
    final file = File('${root.path}/${entry.key}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(entry.value);
    manifest.add({
      'path': entry.key,
      'format': entry.key.split('/').first,
      'bytes': entry.value.length,
      'sha256': sha256.convert(entry.value).toString(),
    });
  }

  await File('${root.path}/manifest.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
}

List<int> _mobipocketBytes({required bool azw3}) {
  final text = utf8.encode(
    'Universal Reader sample text for ${azw3 ? 'AZW3' : 'MOBI'} decoding.',
  );
  final bytes = List<int>.filled(96 + text.length, 0);
  bytes.setRange(60, 64, ascii.encode('BOOK'));
  bytes.setRange(64, 68, ascii.encode('MOBI'));
  bytes.setRange(80, 84, ascii.encode(azw3 ? 'AZW3' : 'MOBI'));
  bytes.setRange(96, 96 + text.length, text);
  return bytes;
}
