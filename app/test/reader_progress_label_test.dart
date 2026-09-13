import 'package:app/core/models.dart';
import 'package:app/core/reader_progress_label.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/reader_state.dart';
import 'package:app/features/tools/sample_reader_document.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubLocalizations extends AppLocalizations {
  _StubLocalizations() : super('en');

  @override
  String readerSection(int current, int total) => '§$current/$total';

  @override
  dynamic noSuchMethod(Invocation invocation) => '';
}

SampleReaderDocument _doc() => SampleReaderDocument(
  metadata: const DocumentMetadata(
    id: 'book-1',
    title: 'A',
    author: 'B',
    format: DocumentFormat.epub,
    type: DocumentType.reflow,
  ),
);

void main() {
  group('readerProgressLabel', () {
    final l10n = _StubLocalizations();

    test('falls back to formatLabel when no toc and no foliate pages', () {
      const rt = ReaderRuntime();
      expect(
        readerProgressLabel(
          runtime: rt,
          l10n: l10n,
          formatLabel: 'EPUB',
          currentIndex: 0,
        ),
        'EPUB',
      );
    });

    test('uses currentIndex when toc count is the only signal', () {
      final rt = ReaderRuntime(
        tocItems: const [
          TocItem(
            title: '1',
            locator: EpubLocator(href: 'c1', progression: 0),
          ),
          TocItem(
            title: '2',
            locator: EpubLocator(href: 'c2', progression: 0),
          ),
        ],
      );
      expect(
        readerProgressLabel(
          runtime: rt,
          l10n: l10n,
          formatLabel: 'EPUB',
          currentIndex: 1,
        ),
        '§2/2',
      );
    });

    test('falls back to formatLabel when no toc and no foliate pages', () {
      const rt = ReaderRuntime();
      expect(
        readerProgressLabel(
          runtime: rt,
          l10n: l10n,
          formatLabel: 'EPUB',
          currentIndex: 0,
        ),
        'EPUB',
      );
    });

    test('clamps currentIndex when chapterCount disagrees with toc', () {
      final rt = ReaderRuntime(
        opened: _doc(),
        tocItems: const [
          TocItem(
            title: '1',
            locator: EpubLocator(href: 'c1', progression: 0),
          ),
          TocItem(
            title: '2',
            locator: EpubLocator(href: 'c2', progression: 0),
          ),
        ],
      );
      expect(
        readerProgressLabel(
          runtime: rt,
          l10n: l10n,
          formatLabel: 'EPUB',
          currentIndex: 99,
        ),
        '§1/1',
      );
    });
  });
}
