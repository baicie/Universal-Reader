import 'package:app/core/document_identity.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/docx_fixture.dart';
import 'support/odt_fixture.dart';
import 'support/epub_fixture.dart';
import 'support/fb2_fixture.dart';
import 'support/rtf_fixture.dart';

void main() {
  group('titleFromFileName', () {
    test('strips a plain .txt extension', () {
      expect(titleFromFileName('notes.txt'), 'notes');
    });

    test('strips a nested-extension case', () {
      expect(titleFromFileName('paper.tar.gz'), 'paper.tar');
    });

    test('returns the file name unchanged when no extension exists', () {
      expect(titleFromFileName('README'), 'README');
    });

    test('trims only the final extension segment', () {
      expect(titleFromFileName('ch.01.epub'), 'ch.01');
    });
  });

  group('documentIdentity', () {
    test('reads title and author out of an EPUB', () {
      final bytes = minimalEpubBytes(title: '设计中的设计', author: '原研哉');
      final identity = documentIdentity(
        fileName: 'design.epub',
        bytes: bytes,
        format: DocumentFormat.epub,
      );
      expect(identity.title, '设计中的设计');
      expect(identity.author, '原研哉');
    });

    test('reads title and author out of an FB2', () {
      final bytes = minimalFb2Bytes(
        title: 'Война и мир',
        authorFirst: 'Лев',
        authorLast: 'Толстой',
      );
      final identity = documentIdentity(
        fileName: 'war.fb2',
        bytes: bytes,
        format: DocumentFormat.fb2,
      );
      expect(identity.title, 'Война и мир');
      expect(identity.author, 'Лев Толстой');
    });

    test('also handles AZW3/MOBI by reusing the EPUB parser', () {
      final bytes = minimalEpubBytes(
        title: 'Kindle Book',
        author: 'Kindle Author',
      );
      final azw3 = documentIdentity(
        fileName: 'kindle.azw3',
        bytes: bytes,
        format: DocumentFormat.azw3,
      );
      final mobi = documentIdentity(
        fileName: 'kindle.mobi',
        bytes: bytes,
        format: DocumentFormat.mobi,
      );
      expect(azw3.title, 'Kindle Book');
      expect(azw3.author, 'Kindle Author');
      expect(mobi.title, 'Kindle Book');
      expect(mobi.author, 'Kindle Author');
    });

    test(
      'falls back to the file name when EPUB metadata has an empty title',
      () {
        final bytes = minimalEpubBytes(title: '   ', author: '');
        final identity = documentIdentity(
          fileName: 'design.epub',
          bytes: bytes,
          format: DocumentFormat.epub,
        );
        expect(identity.title, 'design');
        expect(identity.author, isEmpty);
      },
    );

    test(
      'falls back to the file name when FB2 metadata has an empty title',
      () {
        final bytes = minimalFb2Bytes(
          title: '   ',
          authorFirst: '',
          authorLast: '',
        );
        final identity = documentIdentity(
          fileName: 'war.fb2',
          bytes: bytes,
          format: DocumentFormat.fb2,
        );
        expect(identity.title, 'war');
        expect(identity.author, isEmpty);
      },
    );

    test('falls back to the file name when the EPUB bytes are corrupt', () {
      final identity = documentIdentity(
        fileName: 'broken.epub',
        bytes: const [1, 2, 3, 4],
        format: DocumentFormat.epub,
      );
      expect(identity.title, 'broken');
      expect(identity.author, isEmpty);
    });

    test('falls back to the file name when the FB2 bytes are corrupt', () {
      final identity = documentIdentity(
        fileName: 'broken.fb2',
        bytes: const [1, 2, 3, 4],
        format: DocumentFormat.fb2,
      );
      expect(identity.title, 'broken');
      expect(identity.author, isEmpty);
    });

    test('returns the file name as title for formats that do not parse', () {
      final identity = documentIdentity(
        fileName: 'paper.pdf',
        bytes: const [1, 2, 3],
        format: DocumentFormat.pdf,
      );
      expect(identity.title, 'paper');
      expect(identity.author, isEmpty);
    });

    test('returns the file name as title for unknown formats', () {
      final identity = documentIdentity(
        fileName: 'blob',
        bytes: const [],
        format: DocumentFormat.unknown,
      );
      expect(identity.title, 'blob');
      expect(identity.author, isEmpty);
    });

    test('does not crash on an empty file name', () {
      final identity = documentIdentity(
        fileName: '',
        bytes: const [],
        format: DocumentFormat.unknown,
      );
      expect(identity.title, isEmpty);
      expect(identity.author, isEmpty);
    });

    test('trims surrounding whitespace from a parsed title', () {
      final bytes = minimalEpubBytes(title: '  Padded Title  ', author: '');
      final identity = documentIdentity(
        fileName: 'padded.epub',
        bytes: bytes,
        format: DocumentFormat.epub,
      );
      expect(identity.title, 'Padded Title');
    });
  });

  test('reads DOCX core properties', () {
    final identity = documentIdentity(
      fileName: 'fallback.docx',
      bytes: minimalDocxBytes(title: 'Office Title', author: 'Office Author'),
      format: DocumentFormat.docx,
    );

    expect(identity.title, 'Office Title');
    expect(identity.author, 'Office Author');
  });

  test('reads ODT metadata properties', () {
    final identity = documentIdentity(
      fileName: 'fallback.odt',
      bytes: minimalOdtBytes(title: 'ODT Title', author: 'ODT Author'),
      format: DocumentFormat.odt,
    );

    expect(identity.title, 'ODT Title');
    expect(identity.author, 'ODT Author');
  });

  test('reads RTF info properties', () {
    final identity = documentIdentity(
      fileName: 'fallback.rtf',
      bytes: minimalRtfBytes(title: 'RTF Title', author: 'RTF Author'),
      format: DocumentFormat.rtf,
    );

    expect(identity.title, 'RTF Title');
    expect(identity.author, 'RTF Author');
  });
}
