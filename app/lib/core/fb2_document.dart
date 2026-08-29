import 'package:xml/xml.dart';

import 'models.dart';
import 'reader_runtime.dart';
import 'text_document.dart';

class Fb2Chapter {
  const Fb2Chapter({
    required this.href,
    required this.title,
    required this.text,
    required this.html,
    this.startOffset = 0,
  });

  final String href;
  final String title;
  final String text;
  final String html;
  final int startOffset;
}

class ParsedFb2 {
  const ParsedFb2({
    required this.title,
    required this.author,
    required this.chapters,
    required this.fullText,
  });

  final String title;
  final String author;
  final List<Fb2Chapter> chapters;
  final String fullText;
}

ParsedFb2 parseFb2(List<int> bytes) {
  late final XmlDocument xml;
  try {
    xml = XmlDocument.parse(decodeTextBytes(bytes));
  } catch (_) {
    throw const FormatException('corrupt fb2');
  }
  final root = xml.rootElement;
  if (root.name.local.toLowerCase() != 'fictionbook') {
    throw const FormatException('corrupt fb2');
  }
  final title = _firstText(xml, 'book-title') ?? '';
  final first = _firstText(xml, 'first-name') ?? '';
  final last = _firstText(xml, 'last-name') ?? '';
  final author = [first, last].where((part) => part.isNotEmpty).join(' ');
  final chapters = <Fb2Chapter>[];
  final full = StringBuffer();
  var index = 0;
  for (final section in xml.descendants.whereType<XmlElement>()) {
    if (section.name.local != 'section') continue;
    if (section.childElements.every((child) => child.name.local == 'section')) {
      continue;
    }
    final heading = _sectionTitle(section);
    final paragraphs = [
      for (final node in section.childElements)
        if (node.name.local == 'p') node.innerText.trim(),
    ].where((text) => text.isNotEmpty).toList();
    if (paragraphs.isEmpty && heading.isEmpty) continue;
    final text = [if (heading.isNotEmpty) heading, ...paragraphs].join('\n\n');
    final html =
        '<section>${[if (heading.isNotEmpty) '<h1>$heading</h1>', for (final p in paragraphs) '<p>$p</p>'].join()}</section>';
    final start = full.length;
    if (full.isNotEmpty) full.write('\n\n');
    full.write(text);
    chapters.add(
      Fb2Chapter(
        href: 'section-$index',
        title: heading.isEmpty ? _firstLine(text) : heading,
        text: text,
        html: html,
        startOffset: start,
      ),
    );
    index += 1;
  }
  if (chapters.isEmpty) {
    throw const FormatException('corrupt fb2');
  }
  return ParsedFb2(
    title: title,
    author: author,
    chapters: chapters,
    fullText: full.toString(),
  );
}

class Fb2ReaderDocument implements HtmlChapteredDocument {
  Fb2ReaderDocument._({required this.metadata, required this.parsed});

  factory Fb2ReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    return Fb2ReaderDocument._(metadata: metadata, parsed: parseFb2(bytes));
  }

  @override
  final DocumentMetadata metadata;
  final ParsedFb2 parsed;
  int sectionIndex = 0;

  Fb2Chapter get currentChapter =>
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
  bool get truncated => false;

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
    if (locator is EpubLocator) {
      final index = parsed.chapters.indexWhere(
        (chapter) => chapter.href == locator.href,
      );
      if (index >= 0) sectionIndex = index;
    }
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
      for (final chapter in parsed.chapters)
        TocItem(
          title: chapter.title,
          locator: EpubLocator(href: chapter.href),
        ),
    ];
  }
}

String? _firstText(XmlNode node, String localName) {
  for (final element in node.descendants.whereType<XmlElement>()) {
    if (element.name.local == localName &&
        element.innerText.trim().isNotEmpty) {
      return element.innerText.trim();
    }
  }
  return null;
}

String _sectionTitle(XmlElement section) {
  for (final child in section.childElements) {
    if (child.name.local == 'title') return child.innerText.trim();
  }
  return '';
}

String _firstLine(String body) {
  final line = body.split('\n').first.trim();
  return line.runes.length <= 40 ? line : '';
}
