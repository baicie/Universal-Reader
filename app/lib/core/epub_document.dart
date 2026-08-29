import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'models.dart';
import 'reader_runtime.dart';
import 'text_document.dart';

const epubTextByteLimit = 2 * 1024 * 1024;

class EpubChapter {
  const EpubChapter({
    required this.href,
    required this.title,
    required this.text,
    this.html = '',
    this.startOffset = 0,
  });

  final String href;
  final String title;
  final String text;
  final String html;
  final int startOffset;
}

class ParsedEpub {
  const ParsedEpub({
    required this.title,
    required this.author,
    required this.chapters,
    required this.fullText,
    required this.truncated,
  });

  final String title;
  final String author;
  final List<EpubChapter> chapters;
  final String fullText;
  final bool truncated;
}

ParsedEpub parseEpub(List<int> bytes) {
  late final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('corrupt epub');
  }
  final files = <String, ArchiveFile>{};
  for (final file in archive) {
    if (!file.isFile) continue;
    files[_normalizePath(file.name)] = file;
  }
  final container = _xml(_read(files, 'meta-inf/container.xml'));
  final rootPath = _firstAttribute(container, 'rootfile', 'full-path');
  if (rootPath == null || rootPath.trim().isEmpty) {
    throw const FormatException('corrupt epub');
  }
  final opfPath = _normalizePath(rootPath);
  final opf = _xml(_read(files, opfPath));
  final title = _firstLocalText(opf, 'title') ?? '';
  final author = _firstLocalText(opf, 'creator') ?? '';
  final manifest = <String, String>{};
  for (final item in _localElements(opf, 'item')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id == null || href == null) continue;
    manifest[id] = _resolveHref(opfPath, href);
  }
  final spineHrefs = [
    for (final item in _localElements(opf, 'itemref'))
      if (item.getAttribute('linear') != 'no')
        manifest[item.getAttribute('idref') ?? ''],
  ].whereType<String>().toList();
  if (spineHrefs.isEmpty) {
    throw const FormatException('corrupt epub');
  }
  final titles = _navTitles(files, manifest, opfPath);
  final chapters = <EpubChapter>[];
  final text = StringBuffer();
  var truncated = false;
  for (final href in spineHrefs) {
    if (text.length >= epubTextByteLimit) {
      truncated = true;
      break;
    }
    final raw = _tryRead(files, href);
    if (raw == null) continue;
    var body = stripHtml(raw).trim();
    if (body.isEmpty) continue;
    if (text.length + body.length > epubTextByteLimit) {
      body = body.substring(0, epubTextByteLimit - text.length);
      truncated = true;
    }
    final titleForChapter = titles[href] ?? _firstLine(body);
    final start = text.length;
    if (text.isNotEmpty) text.write('\n\n');
    text.write(body);
    chapters.add(
      EpubChapter(
        href: href,
        title: titleForChapter,
        text: body,
        html: raw,
        startOffset: start,
      ),
    );
    if (truncated) break;
  }
  if (chapters.isEmpty) {
    throw const FormatException('corrupt epub');
  }
  return ParsedEpub(
    title: title,
    author: author,
    chapters: _packChapters(chapters),
    fullText: text.toString(),
    truncated: truncated,
  );
}

List<EpubChapter> _packChapters(List<EpubChapter> chapters) {
  final packed = <EpubChapter>[];
  for (final chapter in chapters) {
    if (chapter.text.length <= textSectionCharLimit) {
      packed.add(chapter);
      continue;
    }
    var offset = chapter.startOffset;
    var index = 0;
    while (index < chapter.text.length) {
      final end = index + textSectionCharLimit > chapter.text.length
          ? chapter.text.length
          : index + textSectionCharLimit;
      packed.add(
        EpubChapter(
          href: chapter.href,
          title: chapter.title,
          text: chapter.text.substring(index, end),
          html: index == 0 ? chapter.html : '',
          startOffset: offset,
        ),
      );
      offset += end - index;
      index = end;
    }
  }
  return packed;
}

class EpubReaderDocument implements HtmlChapteredDocument {
  EpubReaderDocument._({required this.metadata, required this.parsed});

  factory EpubReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    return EpubReaderDocument._(metadata: metadata, parsed: parseEpub(bytes));
  }

  @override
  final DocumentMetadata metadata;
  final ParsedEpub parsed;
  int sectionIndex = 0;

  EpubChapter get currentChapter =>
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
  Future<Locator> currentLocator() async {
    return EpubLocator(
      href: currentChapter.href,
      progression: parsed.chapters.length <= 1
          ? 0
          : sectionIndex / (parsed.chapters.length - 1),
    );
  }

  @override
  Future<String?> extractText(DocumentRange range) async {
    if (range.start is EpubLocator || range.end is EpubLocator) {
      final startHref = range.start is EpubLocator
          ? (range.start as EpubLocator).href
          : parsed.chapters.first.href;
      final endHref = range.end is EpubLocator
          ? (range.end as EpubLocator).href
          : parsed.chapters.last.href;
      final start = parsed.chapters.indexWhere(
        (chapter) => _sameHref(chapter.href, startHref),
      );
      final end = parsed.chapters.lastIndexWhere(
        (chapter) => _sameHref(chapter.href, endHref),
      );
      if (start < 0 || end < 0 || end < start) return '';
      return parsed.chapters
          .sublist(start, end + 1)
          .map((chapter) => chapter.text)
          .join('\n\n');
    }
    final start = switch (range.start) {
      TextLocator(:final offset) => offset,
      _ => 0,
    };
    final end = switch (range.end) {
      TextLocator(:final offset) => offset,
      _ => parsed.fullText.length,
    };
    if (start >= parsed.fullText.length) return '';
    return parsed.fullText.substring(
      start.clamp(0, parsed.fullText.length),
      end.clamp(start, parsed.fullText.length),
    );
  }

  @override
  Future<void> goTo(Locator locator) async {
    switch (locator) {
      case EpubLocator(:final href):
        final index = parsed.chapters.indexWhere(
          (chapter) => _sameHref(chapter.href, href),
        );
        if (index >= 0) sectionIndex = index;
      case TextLocator(:final offset):
        final index = parsed.chapters.lastIndexWhere(
          (chapter) => chapter.startOffset <= offset,
        );
        sectionIndex = index < 0 ? 0 : index;
      default:
        break;
    }
  }

  @override
  Stream<double> get progress {
    final length = parsed.fullText.isEmpty ? 1 : parsed.fullText.length;
    return Stream<double>.value(currentChapter.startOffset / length);
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) return const [];
    final hits = <SearchResult>[];
    for (final chapter in parsed.chapters) {
      final at = chapter.text.indexOf(query);
      if (at < 0) continue;
      hits.add(
        SearchResult(
          title: chapter.title.isEmpty ? metadata.title : chapter.title,
          excerpt: _excerptAround(chapter.text, at, query.length),
          locator: EpubLocator(href: chapter.href),
        ),
      );
      if (hits.length >= 10) break;
    }
    return hits;
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

String _read(Map<String, ArchiveFile> files, String path) {
  final content = _tryRead(files, path);
  if (content == null) {
    throw const FormatException('corrupt epub');
  }
  return content;
}

String? _tryRead(Map<String, ArchiveFile> files, String path) {
  final file = files[_normalizePath(path)];
  if (file == null) return null;
  return decodeTextBytes(file.content as List<int>);
}

XmlDocument _xml(String source) {
  try {
    return XmlDocument.parse(source);
  } catch (_) {
    throw const FormatException('corrupt epub');
  }
}

Iterable<XmlElement> _localElements(XmlNode node, String name) {
  return node.descendants.whereType<XmlElement>().where(
    (element) => element.name.local == name,
  );
}

String? _firstAttribute(XmlNode node, String localName, String attribute) {
  for (final element in _localElements(node, localName)) {
    final value = element.getAttribute(attribute);
    if (value != null) return value;
  }
  return null;
}

String? _firstLocalText(XmlNode node, String localName) {
  for (final element in _localElements(node, localName)) {
    final text = element.innerText.trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

Map<String, String> _navTitles(
  Map<String, ArchiveFile> files,
  Map<String, String> manifest,
  String opfPath,
) {
  final titles = <String, String>{};
  for (final href in manifest.values) {
    if (!href.endsWith('.xhtml') && !href.endsWith('.html')) continue;
    final raw = _tryRead(files, href);
    if (raw == null || !raw.contains('epub:type="toc"')) continue;
    try {
      final nav = XmlDocument.parse(raw);
      for (final anchor in _localElements(nav, 'a')) {
        final target = anchor.getAttribute('href');
        final label = anchor.innerText.trim();
        if (target == null || label.isEmpty) continue;
        titles[_resolveHref(href, target)] = label;
      }
    } catch (_) {
      // nav 损坏时退回章节正文标题，不让整本书打不开。
    }
  }
  if (titles.isNotEmpty) return titles;
  final ncxHref = manifest.values
      .where((href) => href.endsWith('.ncx'))
      .firstOrNull;
  if (ncxHref == null) return titles;
  final ncxRaw = _tryRead(files, ncxHref);
  if (ncxRaw == null) return titles;
  try {
    final ncx = XmlDocument.parse(ncxRaw);
    final points = _localElements(ncx, 'navPoint');
    for (final point in points) {
      final label = _firstLocalText(point, 'text') ?? '';
      final src = _firstAttribute(point, 'content', 'src');
      if (src == null || label.isEmpty) continue;
      titles[_resolveHref(ncxHref, src)] = label;
    }
  } catch (_) {
    // NCX 损坏时同样退回正文标题。
  }
  return titles;
}

String _resolveHref(String basePath, String href) {
  final cleaned = href.split('#').first.replaceAll('\\', '/');
  final decoded = Uri.decodeFull(cleaned);
  final slash = basePath.replaceAll('\\', '/').lastIndexOf('/');
  final dir = slash < 0 ? '' : basePath.substring(0, slash + 1);
  return _normalizePath(decoded.startsWith('/') ? decoded : '$dir$decoded');
}

String _normalizePath(String path) {
  final parts = <String>[];
  for (final part in path.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(part);
  }
  return parts.join('/').toLowerCase();
}

bool _sameHref(String left, String right) {
  return _normalizePath(left) == _normalizePath(right) ||
      _normalizePath(left).endsWith(_normalizePath(right)) ||
      _normalizePath(right).endsWith(_normalizePath(left));
}

String _firstLine(String body) {
  final line = body.split('\n').first.trim();
  return line.runes.length <= 40 ? line : '';
}

String _excerptAround(String text, int start, int queryLength) {
  final from = start < 24 ? 0 : start - 24;
  final to = (start + queryLength + 24).clamp(0, text.length);
  return text.substring(from, to).trim();
}
