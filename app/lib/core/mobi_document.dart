import 'epub_document.dart';
import 'models.dart';
import 'reader_runtime.dart';
import 'text_document.dart';

class MobiReaderDocument implements HtmlChapteredDocument {
  MobiReaderDocument._({
    required this.metadata,
    required this.chapters,
    required this.fullText,
  });

  factory MobiReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    final epub = _asEpub(bytes);
    if (epub != null) {
      return MobiReaderDocument._(
        metadata: metadata,
        chapters: [
          for (final chapter in epub.chapters)
            (
              href: chapter.href,
              title: chapter.title,
              text: chapter.text,
              html: chapter.html,
            ),
        ],
        fullText: epub.fullText,
      );
    }
    final text = _extractReadableRuns(bytes);
    if (text.trim().isEmpty) {
      throw const FormatException('corrupt mobi');
    }
    return MobiReaderDocument._(
      metadata: metadata,
      chapters: [
        (
          href: 'text',
          title: metadata.title,
          text: text,
          html: '<p>${_escape(text)}</p>',
        ),
      ],
      fullText: text,
    );
  }

  @override
  final DocumentMetadata metadata;
  final List<({String href, String title, String text, String html})> chapters;
  final String fullText;
  int sectionIndex = 0;

  ({String href, String title, String text, String html}) get currentChapter =>
      chapters[sectionIndex.clamp(0, chapters.length - 1)];

  @override
  int get chapterIndex => sectionIndex;

  @override
  int get chapterCount => chapters.length;

  @override
  String get currentChapterText => currentChapter.text;

  @override
  String get currentChapterHtml => currentChapter.html;

  @override
  String get currentChapterHref => currentChapter.href;

  @override
  String get currentChapterTitle => currentChapter.title;

  @override
  bool get truncated => false;

  @override
  Locator locatorForProgress(double progress) {
    final index = (progress.clamp(0, 0.999) * chapters.length).floor();
    return EpubLocator(href: chapters[index].href, progression: progress);
  }

  @override
  Future<Locator> currentLocator() async =>
      EpubLocator(href: currentChapter.href);

  @override
  Future<String?> extractText(DocumentRange range) async => fullText;

  @override
  Future<void> goTo(Locator locator) async {
    if (locator is EpubLocator) {
      final index = chapters.indexWhere(
        (chapter) => chapter.href == locator.href,
      );
      if (index >= 0) sectionIndex = index;
    }
  }

  @override
  Stream<double> get progress => Stream<double>.value(
    chapters.length <= 1 ? 0 : sectionIndex / (chapters.length - 1),
  );

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) return const [];
    return [
      for (final chapter in chapters)
        if (chapter.text.contains(query))
          SearchResult(
            title: chapter.title,
            excerpt: chapter.text,
            locator: EpubLocator(href: chapter.href),
          ),
    ];
  }

  @override
  Future<List<TocItem>> getToc() async {
    return [
      for (final chapter in chapters)
        TocItem(
          title: chapter.title,
          locator: EpubLocator(href: chapter.href),
        ),
    ];
  }
}

ParsedEpub? _asEpub(List<int> bytes) {
  try {
    return parseEpub(bytes);
  } on FormatException {
    final offset = _zipOffset(bytes);
    if (offset == null || offset == 0) return null;
    try {
      return parseEpub(bytes.sublist(offset));
    } on FormatException {
      return null;
    }
  }
}

int? _zipOffset(List<int> bytes) {
  for (var i = 0; i < bytes.length - 3; i++) {
    if (bytes[i] == 0x50 &&
        bytes[i + 1] == 0x4B &&
        bytes[i + 2] == 0x03 &&
        bytes[i + 3] == 0x04) {
      return i;
    }
  }
  return null;
}

String _extractReadableRuns(List<int> bytes) {
  final decoded = decodeTextBytes(bytes);
  final matches = RegExp(r'[\t\n\r\x20-\x7E\u00A0-\uFFFF]{24,}')
      .allMatches(decoded);
  final runs = [for (final match in matches) match.group(0)!.trim()]
      .where((run) => run.contains(RegExp(r'[A-Za-z\u4e00-\u9fff]')))
      .toList();
  return runs.join('\n\n');
}

String _escape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
