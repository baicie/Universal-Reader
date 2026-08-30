import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'models.dart';
import 'reader_runtime.dart';
import 'reflow_nav.dart';
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
    this.navItems = const [],
  });

  final String title;
  final String author;
  final List<EpubChapter> chapters;
  final String fullText;
  final bool truncated;
  final List<TocItem> navItems;
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
  final navItems = _navTocItems(files, manifest);
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
        html: _inlineChapterHtml(raw, href, files),
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
    navItems: navItems,
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
    return _tocFromSpine(parsed.chapters, parsed.navItems);
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
        titles.putIfAbsent(_resolveHref(href, target), () => label);
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

List<TocItem> _tocFromSpine(
  List<EpubChapter> chapters,
  List<TocItem> navItems,
) {
  if (navItems.isEmpty) {
    return [
      for (final chapter in chapters)
        TocItem(
          title: chapter.title,
          locator: EpubLocator(href: chapter.href),
        ),
    ];
  }
  final used = List<bool>.filled(navItems.length, false);
  return [
    for (final chapter in chapters) _tocItemForChapter(chapter, navItems, used),
  ];
}

TocItem _tocItemForChapter(
  EpubChapter chapter,
  List<TocItem> navItems,
  List<bool> used,
) {
  for (var i = 0; i < navItems.length; i++) {
    if (used[i]) continue;
    final locator = navItems[i].locator;
    if (locator is! EpubLocator) continue;
    if (!_sameHref(locator.href, chapter.href)) continue;
    used[i] = true;
    final title = navItems[i].title.isEmpty ? chapter.title : navItems[i].title;
    return TocItem(
      title: title,
      locator: EpubLocator(href: chapter.href),
      children: navItems[i].children,
    );
  }
  return TocItem(
    title: chapter.title,
    locator: EpubLocator(href: chapter.href),
  );
}

List<TocItem> _navTocItems(
  Map<String, ArchiveFile> files,
  Map<String, String> manifest,
) {
  for (final href in manifest.values) {
    if (!href.endsWith('.xhtml') && !href.endsWith('.html')) continue;
    final raw = _tryRead(files, href);
    if (raw == null || !raw.contains('epub:type="toc"')) continue;
    try {
      final nav = XmlDocument.parse(raw);
      final tocNav = _localElements(nav, 'nav').where(_isTocNav).firstOrNull;
      final root = tocNav ?? nav.rootElement;
      final ol = _directOl(root) ?? _localElements(root, 'ol').firstOrNull;
      if (ol == null) continue;
      final items = _navListItems(ol, href);
      if (items.isNotEmpty) return items;
    } catch (_) {
      // nav 损坏时退回 spine 平铺，不让整本书打不开。
    }
  }
  final ncxHref = manifest.values
      .where((href) => href.endsWith('.ncx'))
      .firstOrNull;
  if (ncxHref != null) {
    final ncxRaw = _tryRead(files, ncxHref);
    if (ncxRaw != null) {
      try {
        final ncx = XmlDocument.parse(ncxRaw);
        final navMap = _localElements(ncx, 'navMap').firstOrNull;
        if (navMap != null) {
          final points = navMap.childElements
              .where((e) => e.name.local == 'navPoint')
              .toList();
          final items = _ncxNavPoints(points, ncxHref);
          if (items.isNotEmpty) return items;
        }
      } catch (_) {
        // NCX 损坏时同样退回 spine 平铺。
      }
    }
  }
  return const [];
}

bool _isTocNav(XmlElement element) {
  const epubNs = 'http://www.idpf.org/2007/ops';
  final type =
      element.getAttribute('type') ??
      element.getAttribute('epub:type') ??
      element.getAttribute('type', namespace: epubNs);
  return type == 'toc';
}

XmlElement? _directOl(XmlElement parent) {
  for (final child in parent.childElements) {
    if (child.name.local == 'ol') return child;
  }
  return null;
}

List<TocItem> _navListItems(XmlElement ol, String navHref) {
  final items = <TocItem>[];
  for (final li in ol.childElements) {
    if (li.name.local != 'li') continue;
    XmlElement? anchor;
    XmlElement? nested;
    for (final child in li.childElements) {
      if (child.name.local == 'a' && anchor == null) {
        anchor = child;
      } else if (child.name.local == 'ol' && nested == null) {
        nested = child;
      }
    }
    nested ??= li.childElements
        .expand((child) => child.childElements)
        .where((child) => child.name.local == 'ol')
        .firstOrNull;
    if (anchor == null) {
      if (nested != null) {
        items.addAll(_navListItems(nested, navHref));
      }
      continue;
    }
    final href = anchor.getAttribute('href');
    final title = anchor.innerText.trim();
    if (href == null || href.isEmpty || title.isEmpty) continue;
    items.add(
      TocItem(
        title: title,
        locator: EpubLocator(
          href: _resolveHref(navHref, href),
          fragment: reflowHrefFragment(href),
        ),
        children: nested == null ? const [] : _navListItems(nested, navHref),
      ),
    );
  }
  return items;
}

List<TocItem> _ncxNavPoints(List<XmlElement> points, String ncxHref) {
  final items = <TocItem>[];
  for (final point in points) {
    final label = _firstLocalText(point, 'text') ?? '';
    final src = _firstAttribute(point, 'content', 'src');
    if (src == null || label.isEmpty) continue;
    final nested = point.childElements
        .where((e) => e.name.local == 'navPoint')
        .toList();
    items.add(
      TocItem(
        title: label,
        locator: EpubLocator(
          href: _resolveHref(ncxHref, src),
          fragment: reflowHrefFragment(src),
        ),
        children: nested.isEmpty ? const [] : _ncxNavPoints(nested, ncxHref),
      ),
    );
  }
  return items;
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

final _imgSrc = RegExp(
  r'''<img\b([^>]*?)\bsrc\s*=\s*(["'])([^"']+)\2([^>]*)>''',
  caseSensitive: false,
);

final _linkHref = RegExp(
  r'''<link\b([^>]*?)\bhref\s*=\s*(["'])([^"']+)\2([^>]*)>''',
  caseSensitive: false,
);

final _cssUrl = RegExp(
  r'''url\(\s*(['"]?)([^)'"]+)\1\s*\)''',
  caseSensitive: false,
);

final _cssImport = RegExp(
  r'''@import\s+(?:url\(\s*(['"]?)([^)'"]+)\1\s*\)|(['"])([^'"]+)\3)\s*;''',
  caseSensitive: false,
);

final _srcsetAttr = RegExp(
  r'''\bsrcset\s*=\s*(["'])([^"']+)\1''',
  caseSensitive: false,
);

final _svgImageHref = RegExp(
  r'''<image\b([^>]*?)\b((?:xlink:)?href)\s*=\s*(["'])([^"']+)\3([^>]*)>''',
  caseSensitive: false,
);

final _objectDataAttr = RegExp(
  r'''<object\b([^>]*?)\bdata\s*=\s*(["'])([^"']+)\2([^>]*)>''',
  caseSensitive: false,
);

final _embedSrc = RegExp(
  r'''<embed\b([^>]*?)\bsrc\s*=\s*(["'])([^"']+)\2([^>]*)>''',
  caseSensitive: false,
);

final _videoPoster = RegExp(
  r'''<video\b([^>]*?)\bposter\s*=\s*(["'])([^"']+)\2([^>]*)>''',
  caseSensitive: false,
);

final _scriptBlock = RegExp(
  r'<script\b[^>]*>[\s\S]*?</script>',
  caseSensitive: false,
);

final _scriptEmpty = RegExp(r'<script\b[^>]*/>', caseSensitive: false);

final _eventHandlerAttr = RegExp(
  r'''\s+on[a-z]{3,}\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)''',
  caseSensitive: false,
);

String _inlineChapterHtml(
  String html,
  String chapterHref,
  Map<String, ArchiveFile> files,
) {
  var result = _stripChapterEventHandlers(_stripChapterScripts(html));
  result = result.replaceAllMapped(_imgSrc, (match) {
    final src = match.group(3) ?? '';
    if (src.startsWith('data:') || _isExternalHref(src)) {
      return match.group(0)!;
    }
    final dataUri = _dataUriFor(files, _resolveHref(chapterHref, src));
    if (dataUri == null) {
      return match.group(0)!;
    }
    return '<img${match.group(1)}src=${match.group(2)}$dataUri${match.group(2)}${match.group(4)}>';
  });
  result = result.replaceAllMapped(_linkHref, (match) {
    final tag = match.group(0)!;
    if (!tag.toLowerCase().contains('stylesheet')) {
      return tag;
    }
    final href = match.group(3) ?? '';
    if (href.startsWith('data:') || _isExternalHref(href)) {
      return tag;
    }
    final cssPath = _resolveHref(chapterHref, href);
    final css = _tryRead(files, cssPath);
    if (css == null) {
      return tag;
    }
    final seen = <String>{cssPath};
    return '<style>${_inlineCssUrls(_inlineCssImports(css, cssPath, files, seen), cssPath, files)}</style>';
  });
  result = _inlineSrcset(result, chapterHref, files);
  result = _inlineSvgImages(result, chapterHref, files);
  result = _inlineObjectData(result, chapterHref, files);
  result = _inlineEmbedSrc(result, chapterHref, files);
  result = _inlineVideoPoster(result, chapterHref, files);
  return _inlineCssUrls(
    _inlineCssImports(result, chapterHref, files),
    chapterHref,
    files,
  );
}

String _stripChapterScripts(String html) {
  return html.replaceAll(_scriptBlock, '').replaceAll(_scriptEmpty, '');
}

String _stripChapterEventHandlers(String html) {
  return html.replaceAll(_eventHandlerAttr, '');
}

String _inlineSrcset(
  String html,
  String chapterHref,
  Map<String, ArchiveFile> files,
) {
  return html.replaceAllMapped(_srcsetAttr, (match) {
    final quote = match.group(1)!;
    final next = _inlineSrcsetValue(match.group(2) ?? '', chapterHref, files);
    return 'srcset=$quote$next$quote';
  });
}

String _inlineSvgImages(
  String html,
  String chapterHref,
  Map<String, ArchiveFile> files,
) {
  return html.replaceAllMapped(_svgImageHref, (match) {
    final src = match.group(4) ?? '';
    if (src.startsWith('data:') || _isExternalHref(src)) {
      return match.group(0)!;
    }
    final dataUri = _dataUriFor(files, _resolveHref(chapterHref, src));
    if (dataUri == null) {
      return match.group(0)!;
    }
    return '<image${match.group(1)}${match.group(2)}=${match.group(3)}$dataUri${match.group(3)}${match.group(5)}>';
  });
}

String _inlineObjectData(
  String html,
  String chapterHref,
  Map<String, ArchiveFile> files,
) {
  return html.replaceAllMapped(_objectDataAttr, (match) {
    final src = match.group(3) ?? '';
    if (src.startsWith('data:') || _isExternalHref(src)) {
      return match.group(0)!;
    }
    final dataUri = _dataUriFor(files, _resolveHref(chapterHref, src));
    if (dataUri == null || !dataUri.startsWith('data:image/')) {
      return match.group(0)!;
    }
    return '<object${match.group(1)}data=${match.group(2)}$dataUri${match.group(2)}${match.group(4)}>';
  });
}

String _inlineEmbedSrc(
  String html,
  String chapterHref,
  Map<String, ArchiveFile> files,
) {
  return html.replaceAllMapped(_embedSrc, (match) {
    final src = match.group(3) ?? '';
    if (src.startsWith('data:') || _isExternalHref(src)) {
      return match.group(0)!;
    }
    final dataUri = _dataUriFor(files, _resolveHref(chapterHref, src));
    if (dataUri == null || !dataUri.startsWith('data:image/')) {
      return match.group(0)!;
    }
    return '<embed${match.group(1)}src=${match.group(2)}$dataUri${match.group(2)}${match.group(4)}>';
  });
}

String _inlineVideoPoster(
  String html,
  String chapterHref,
  Map<String, ArchiveFile> files,
) {
  return html.replaceAllMapped(_videoPoster, (match) {
    final src = match.group(3) ?? '';
    if (src.startsWith('data:') || _isExternalHref(src)) {
      return match.group(0)!;
    }
    final dataUri = _dataUriFor(files, _resolveHref(chapterHref, src));
    if (dataUri == null || !dataUri.startsWith('data:image/')) {
      return match.group(0)!;
    }
    return '<video${match.group(1)}poster=${match.group(2)}$dataUri${match.group(2)}${match.group(4)}>';
  });
}

String _inlineSrcsetValue(
  String value,
  String chapterHref,
  Map<String, ArchiveFile> files,
) {
  return value
      .split(',')
      .map((part) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) return part;
        final bits = trimmed.split(RegExp(r'\s+'));
        final url = bits.first;
        final rest = bits.skip(1).join(' ');
        if (url.startsWith('data:') || _isExternalHref(url)) {
          return trimmed;
        }
        final dataUri = _dataUriFor(files, _resolveHref(chapterHref, url));
        if (dataUri == null) {
          return trimmed;
        }
        return rest.isEmpty ? dataUri : '$dataUri $rest';
      })
      .join(', ');
}

String _inlineCssImports(
  String css,
  String baseHref,
  Map<String, ArchiveFile> files, [
  Set<String>? seen,
]) {
  final visited = seen ?? <String>{};
  return css.replaceAllMapped(_cssImport, (match) {
    final href = (match.group(2) ?? match.group(4) ?? '').trim();
    if (href.isEmpty || href.startsWith('data:') || _isExternalHref(href)) {
      return match.group(0)!;
    }
    final path = _resolveHref(baseHref, href);
    if (!visited.add(path)) {
      return '';
    }
    final imported = _tryRead(files, path);
    if (imported == null) {
      visited.remove(path);
      return match.group(0)!;
    }
    return _inlineCssUrls(
      _inlineCssImports(imported, path, files, visited),
      path,
      files,
    );
  });
}

String _inlineCssUrls(
  String css,
  String baseHref,
  Map<String, ArchiveFile> files,
) {
  return css.replaceAllMapped(_cssUrl, (match) {
    final href = (match.group(2) ?? '').trim();
    if (href.isEmpty || href.startsWith('data:') || _isExternalHref(href)) {
      return match.group(0)!;
    }
    final dataUri = _dataUriFor(files, _resolveHref(baseHref, href));
    if (dataUri == null) {
      return match.group(0)!;
    }
    return 'url($dataUri)';
  });
}

bool _isExternalHref(String href) {
  final lower = href.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('//');
}

String? _dataUriFor(Map<String, ArchiveFile> files, String path) {
  final mime = _mimeFor(path);
  if (mime == null) {
    return null;
  }
  final bytes = _tryBytes(files, path);
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

List<int>? _tryBytes(Map<String, ArchiveFile> files, String path) {
  final file = files[_normalizePath(path)];
  if (file == null) {
    return null;
  }
  return file.content;
}

String? _mimeFor(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.svg')) {
    return 'image/svg+xml';
  }
  if (lower.endsWith('.ttf')) {
    return 'font/ttf';
  }
  if (lower.endsWith('.otf')) {
    return 'font/otf';
  }
  if (lower.endsWith('.woff2')) {
    return 'font/woff2';
  }
  if (lower.endsWith('.woff')) {
    return 'font/woff';
  }
  return null;
}
