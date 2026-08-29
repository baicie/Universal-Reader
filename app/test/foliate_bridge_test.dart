import 'dart:io';

import 'package:app/core/epub_document.dart';
import 'package:app/core/foliate_bridge.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';

void main() {
  test('opens a chapter through the foliate command protocol', () {
    final document = EpubReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'epub-1',
        title: 'Fixture',
        author: 'A',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
      bytes: minimalEpubBytes(),
    );
    final command = FoliateBridge.openCurrent(document);
    expect(command['type'], 'open');
    expect(command['href'], isNotEmpty);
    expect(command['html'], contains('hello from epub'));
    expect(command.containsKey('FoliateView'), isFalse);
  });

  test('host executes open commands and posts selection without a CDN', () {
    final html = File('assets/reader/foliate/host.html').readAsStringSync();
    expect(html, contains("data.type === 'open'"));
    expect(html, contains('selectionchange'));
    expect(html, contains('fontSize'));
    expect(html, contains('command.lineHeight'));
    expect(html, contains('command.fontFamily'));
    expect(html, contains('command.background'));
    expect(html, contains('command.color'));
    expect(html.toLowerCase(), isNot(contains('cdn.jsdelivr')));
    expect(html, isNot(contains('unpkg.com')));
  });
}
