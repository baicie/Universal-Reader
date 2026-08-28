import '../../../core/models.dart';
import '../../../core/reader_runtime.dart';

class GroundingContext {
  const GroundingContext({
    required this.documentId,
    required this.title,
    required this.author,
    required this.excerpt,
    required this.locatorLabel,
  });

  final String documentId;
  final String title;
  final String author;
  final String excerpt;
  final String locatorLabel;
}

class DocumentGrounding {
  const DocumentGrounding({this.maxExcerptLength = 4000});

  final int maxExcerptLength;

  static const defaultRange = DocumentRange(
    start: TextLocator(offset: 0),
    end: TextLocator(offset: 4000),
  );

  Future<GroundingContext> fromDocument(
    ReaderDocument document, {
    DocumentRange? range,
    Locator? locator,
  }) async {
    final extracted = await document.extractText(range ?? defaultRange) ?? '';
    final excerpt = extracted.length <= maxExcerptLength
        ? extracted
        : extracted.substring(0, maxExcerptLength);
    final current = locator ?? await document.currentLocator();
    return GroundingContext(
      documentId: document.metadata.id,
      title: document.metadata.title,
      author: document.metadata.author,
      excerpt: excerpt.trim(),
      locatorLabel: locatorLabel(current),
    );
  }

  static String locatorLabel(Locator locator) {
    return switch (locator) {
      EpubLocator(:final href, :final progression) =>
        progression == null ? href : '$href · ${(progression * 100).round()}%',
      PdfLocator(:final page) => '第 $page 页',
      TextLocator(:final offset) => '偏移 $offset',
      ComicLocator(:final page) => '第 $page 页',
    };
  }
}
