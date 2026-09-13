import 'models.dart';
import 'reader_runtime.dart';

class ReflowBlock {
  const ReflowBlock({
    required this.text,
    required this.html,
    this.headingLevel,
  });

  final String text;
  final String html;
  final int? headingLevel;
}

class ReflowChapter {
  const ReflowChapter({
    required this.href,
    required this.title,
    required this.text,
    required this.html,
    required this.startOffset,
  });

  final String href;
  final String title;
  final String text;
  final String html;
  final int startOffset;
}

class ParsedReflowPackage {
  const ParsedReflowPackage({
    required this.chapters,
    required this.fullText,
    required this.truncated,
  });

  final List<ReflowChapter> chapters;
  final String fullText;
  final bool truncated;
}

ParsedReflowPackage buildReflowPackage({
  required List<ReflowBlock> blocks,
  required String fallbackTitle,
  required int maxChars,
}) {
  final raw = <_RawReflowChapter>[];
  var current = <ReflowBlock>[];
  String? currentTitle;

  void flush() {
    if (current.isEmpty) return;
    final text = current
        .map((block) => block.text.trim())
        .where((value) => value.isNotEmpty)
        .join('\n\n')
        .trim();
    if (text.isEmpty) {
      current = [];
      currentTitle = null;
      return;
    }
    raw.add(
      _RawReflowChapter(
        title: currentTitle ?? fallbackTitle,
        text: text,
        html: '<section>${current.map((block) => block.html).join()}</section>',
      ),
    );
    current = [];
    currentTitle = null;
  }

  for (final block in blocks) {
    final startsChapter =
        block.headingLevel != null && block.headingLevel! <= 2;
    if (startsChapter && current.isNotEmpty) flush();
    if (startsChapter && block.text.trim().isNotEmpty) {
      currentTitle = block.text.trim();
    }
    current.add(block);
  }
  flush();
  if (raw.isEmpty) throw const FormatException('corrupt reflow document');

  final chapters = <ReflowChapter>[];
  final fullText = StringBuffer();
  var truncated = false;
  for (final chapter in raw) {
    if (fullText.length >= maxChars) {
      truncated = true;
      break;
    }
    final remaining = maxChars - fullText.length;
    var text = chapter.text;
    var html = chapter.html;
    if (text.length > remaining) {
      text = text.substring(0, remaining);
      html = '<section><p>${_escape(text)}</p></section>';
      truncated = true;
    }
    final startOffset = fullText.length;
    if (fullText.isNotEmpty) fullText.write('\n\n');
    fullText.write(text);
    chapters.add(
      ReflowChapter(
        href: 'section-${chapters.length}',
        title: chapter.title,
        text: text,
        html: html,
        startOffset: startOffset,
      ),
    );
    if (truncated) break;
  }
  return ParsedReflowPackage(
    chapters: chapters,
    fullText: fullText.toString(),
    truncated: truncated,
  );
}

class ReflowReaderDocument implements HtmlChapteredDocument {
  ReflowReaderDocument({required this.metadata, required this.parsed});

  @override
  final DocumentMetadata metadata;
  final ParsedReflowPackage parsed;
  int sectionIndex = 0;

  ReflowChapter get currentChapter =>
      parsed.chapters[sectionIndex.clamp(0, parsed.chapters.length - 1)];

  @override
  int get chapterIndex => sectionIndex;

  @override
  int get chapterCount => parsed.chapters.length;

  @override
  String get currentChapterText => currentChapter.text;

  @override
  String get currentChapterHtml => currentChapter.html;

  @override
  String get currentChapterHref => currentChapter.href;

  @override
  String get currentChapterTitle => currentChapter.title;

  @override
  bool get truncated => parsed.truncated;

  @override
  Locator locatorForProgress(double progress) {
    final index = (progress.clamp(0, 0.999) * parsed.chapters.length).floor();
    return EpubLocator(
      href: parsed.chapters[index].href,
      progression: progress,
    );
  }

  @override
  Future<Locator> currentLocator() async =>
      EpubLocator(href: currentChapter.href);

  @override
  Future<String?> extractText(DocumentRange range) async => currentChapter.text;

  @override
  Future<void> goTo(Locator locator) async {
    if (locator is! EpubLocator) return;
    final index = parsed.chapters.indexWhere(
      (chapter) => chapter.href == locator.href,
    );
    if (index >= 0) sectionIndex = index;
  }

  @override
  Stream<double> get progress => Stream<double>.value(
    parsed.chapters.length <= 1
        ? 0
        : sectionIndex / (parsed.chapters.length - 1),
  );

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) return const [];
    return [
      for (final chapter in parsed.chapters)
        if (chapter.text.toLowerCase().contains(query.toLowerCase()))
          SearchResult(
            title: chapter.title,
            excerpt: chapter.text,
            locator: EpubLocator(href: chapter.href),
          ),
    ];
  }

  @override
  Future<List<TocItem>> getToc() async => [
    for (final chapter in parsed.chapters)
      TocItem(
        title: chapter.title,
        locator: EpubLocator(href: chapter.href),
      ),
  ];
}

class _RawReflowChapter {
  const _RawReflowChapter({
    required this.title,
    required this.text,
    required this.html,
  });

  final String title;
  final String text;
  final String html;
}

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
