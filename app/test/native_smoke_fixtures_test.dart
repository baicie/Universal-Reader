import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final corpus = Directory(
    Directory('../test-books').existsSync() ? '../test-books' : 'test-books',
  );

  for (final path in const ['chm/minimal.chm', 'djvu/minimal.djvu']) {
    test('bundled native smoke fixture matches $path', () {
      final canonical = File('${corpus.path}/$path').readAsBytesSync();
      final bundled = File('assets/test-books/$path').readAsBytesSync();
      expect(bundled, canonical);
    });
  }
}
