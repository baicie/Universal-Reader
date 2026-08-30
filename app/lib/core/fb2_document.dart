import 'dart:convert';

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
    this.parentHref,
    this.tocGroup,
    this.tocGroupTitle = '',
  });

  final String href;
  final String title;
  final String text;
  final String html;
  final int startOffset;
  final String? parentHref;
  final String? tocGroup;
  final String tocGroupTitle;
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
  final binaries = _fb2BinaryUris(xml);
  final chapters = <Fb2Chapter>[];
  final idToHref = <String, String>{};
  final full = StringBuffer();
  final blurb = _fb2TitleInfoAnnotation(xml);
  if (blurb != null) {
    final blurbHtml = _fb2AnnotationHtml(blurb, binaries);
    if (blurbHtml != null) {
      final text = blurb.innerText.trim();
      full.write(text);
      chapters.add(
        Fb2Chapter(
          href: 'annotation',
          title: _fb2BlurbTitle(text),
          text: text,
          html: '<section>$blurbHtml</section>',
          startOffset: 0,
        ),
      );
    }
  }
  var index = 0;
  final emitted = <XmlElement, String>{};
  void emitChapter(XmlElement node) {
    if (node.name.local == 'section' &&
        node.childElements.every((child) => child.name.local == 'section')) {
      return;
    }
    final heading = _sectionTitle(node);
    final blocks = [
      for (final child in node.childElements)
        if (child.name.local == 'p' ||
            child.name.local == 'subtitle' ||
            child.name.local == 'poem' ||
            child.name.local == 'epigraph' ||
            child.name.local == 'cite' ||
            child.name.local == 'table' ||
            child.name.local == 'annotation')
          child.innerText.trim(),
    ].where((text) => text.isNotEmpty).toList();
    final html = _sectionHtml(node, heading, binaries);
    if (html == '<section></section>') return;
    final text = [if (heading.isNotEmpty) heading, ...blocks].join('\n\n');
    final start = full.length;
    if (full.isNotEmpty) full.write('\n\n');
    full.write(text);
    final href = 'section-$index';
    _collectFb2Ids(node, href, idToHref);
    final group = _fb2BodyGroup(node);
    chapters.add(
      Fb2Chapter(
        href: href,
        title: heading.isEmpty ? _firstLine(text) : heading,
        text: text,
        html: html,
        startOffset: start,
        parentHref: _fb2ParentHref(node, emitted),
        tocGroup: group.name,
        tocGroupTitle: group.title,
      ),
    );
    emitted[node] = href;
    index += 1;
  }

  for (final body in xml.rootElement.childElements) {
    if (body.name.local != 'body') continue;
    if (_fb2ContainsSection(body)) {
      for (final section in body.descendants.whereType<XmlElement>()) {
        if (section.name.local != 'section') continue;
        emitChapter(section);
      }
      continue;
    }
    final name = (body.getAttribute('name') ?? '').trim().toLowerCase();
    if (name == 'notes' || name == 'comments') continue;
    emitChapter(body);
  }
  if (index == 0) {
    throw const FormatException('corrupt fb2');
  }
  return ParsedFb2(
    title: title,
    author: author,
    chapters: [
      for (final chapter in chapters)
        Fb2Chapter(
          href: chapter.href,
          title: chapter.title,
          text: chapter.text,
          html: _rewriteFb2HashHrefs(chapter.html, idToHref),
          startOffset: chapter.startOffset,
          parentHref: chapter.parentHref,
          tocGroup: chapter.tocGroup,
          tocGroupTitle: chapter.tocGroupTitle,
        ),
    ],
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
  Future<List<TocItem>> getToc() async => _fb2TocItems(parsed.chapters);
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

XmlElement? _fb2TitleInfoAnnotation(XmlDocument xml) {
  for (final description in xml.descendants.whereType<XmlElement>()) {
    if (description.name.local != 'description') continue;
    for (final info in description.childElements) {
      if (info.name.local != 'title-info') continue;
      for (final child in info.childElements) {
        if (child.name.local == 'annotation') return child;
      }
    }
  }
  return null;
}

String _fb2BlurbTitle(String text) {
  final line = text.split('\n').first.trim();
  return line.isEmpty ? _firstLine(text) : line;
}

String? _fb2ParentHref(XmlElement section, Map<XmlElement, String> emitted) {
  XmlNode? ancestor = section.parent;
  while (ancestor is XmlElement) {
    if (ancestor.name.local == 'section') {
      final href = emitted[ancestor];
      if (href != null) return href;
    }
    ancestor = ancestor.parent;
  }
  return null;
}

bool _fb2ContainsSection(XmlElement node) {
  return node.descendants.whereType<XmlElement>().any(
    (element) => element.name.local == 'section',
  );
}

({String? name, String title}) _fb2BodyGroup(XmlElement section) {
  XmlNode? ancestor = section.parent;
  while (ancestor is XmlElement) {
    if (ancestor.name.local == 'body') {
      final name = (ancestor.getAttribute('name') ?? '').trim().toLowerCase();
      if (name != 'notes' && name != 'comments') {
        return (name: null, title: '');
      }
      var title = '';
      for (final child in ancestor.childElements) {
        if (child.name.local == 'title') {
          title = child.innerText.trim();
          break;
        }
      }
      return (name: name, title: title);
    }
    ancestor = ancestor.parent;
  }
  return (name: null, title: '');
}

List<TocItem> _fb2TocTree(List<Fb2Chapter> chapters) {
  final childrenOf = <String?, List<Fb2Chapter>>{};
  for (final chapter in chapters) {
    childrenOf.putIfAbsent(chapter.parentHref, () => []).add(chapter);
  }
  List<TocItem> items(String? parent) {
    return [
      for (final chapter in childrenOf[parent] ?? const <Fb2Chapter>[])
        TocItem(
          title: chapter.title,
          locator: EpubLocator(href: chapter.href),
          children: items(chapter.href),
        ),
    ];
  }

  return items(null);
}

TocItem _fb2TocGroup(List<Fb2Chapter> chapters) {
  final children = _fb2TocTree(chapters);
  final title = chapters.first.tocGroupTitle.trim();
  return TocItem(
    title: title.isEmpty ? chapters.first.tocGroup! : title,
    locator: children.first.locator,
    children: children,
  );
}

List<TocItem> _fb2TocItems(List<Fb2Chapter> chapters) {
  final main = <Fb2Chapter>[];
  final groups = <String, List<Fb2Chapter>>{};
  final groupOrder = <String>[];
  for (final chapter in chapters) {
    final group = chapter.tocGroup;
    if (group == null) {
      main.add(chapter);
      continue;
    }
    groups
        .putIfAbsent(group, () {
          groupOrder.add(group);
          return <Fb2Chapter>[];
        })
        .add(chapter);
  }
  return [
    ..._fb2TocTree(main),
    for (final name in groupOrder) _fb2TocGroup(groups[name]!),
  ];
}

String _sectionTitle(XmlElement section) {
  for (final child in section.childElements) {
    if (child.name.local == 'title') return child.innerText.trim();
  }
  return '';
}

String _sectionHtml(
  XmlElement section,
  String heading,
  Map<String, String> binaries,
) {
  final id = (section.getAttribute('id') ?? '').trim();
  final idAttr = id.isEmpty ? '' : ' id="${_escapeAttr(id)}"';
  final parts = <String>[
    if (heading.isNotEmpty) '<h1>${_escapeHtml(heading)}</h1>',
  ];
  for (final child in section.childElements) {
    final name = child.name.local;
    if (name == 'title' || name == 'section') continue;
    if (name == 'image') {
      final img = _fb2Img(child, binaries);
      if (img != null) parts.add(img);
      continue;
    }
    if (name == 'empty-line') {
      parts.add('<p><br/></p>');
      continue;
    }
    if (name == 'subtitle') {
      final inner = _fb2Inlines(child, binaries);
      if (inner.trim().isNotEmpty) parts.add('<h2>$inner</h2>');
      continue;
    }
    if (name == 'poem') {
      final poem = _fb2PoemHtml(child, binaries);
      if (poem != null) parts.add(poem);
      continue;
    }
    if (name == 'epigraph' || name == 'cite') {
      final quote = _fb2QuoteHtml(child, binaries);
      if (quote != null) parts.add(quote);
      continue;
    }
    if (name == 'annotation') {
      final note = _fb2AnnotationHtml(child, binaries);
      if (note != null) parts.add(note);
      continue;
    }
    if (name == 'table') {
      final table = _fb2TableHtml(child, binaries);
      if (table != null) parts.add(table);
      continue;
    }
    if (name != 'p') continue;
    final paragraph = _fb2ParagraphHtml(child, binaries);
    if (paragraph != null) parts.add(paragraph);
  }
  if (parts.isEmpty) return '<section></section>';
  return '<section$idAttr>${parts.join()}</section>';
}

String? _fb2ParagraphHtml(XmlElement paragraph, Map<String, String> binaries) {
  final inner = _fb2Inlines(paragraph, binaries);
  final idAttr = _fb2IdAttr(paragraph);
  if (inner.trim().isEmpty && !inner.contains('<img') && idAttr.isEmpty) {
    return null;
  }
  return '<p$idAttr>$inner</p>';
}

String? _fb2PoemHtml(XmlElement poem, Map<String, String> binaries) {
  final parts = <String>[];
  for (final child in poem.childElements) {
    final name = child.name.local;
    if (name == 'title') {
      final inner = _fb2Inlines(child, binaries).trim();
      if (inner.isNotEmpty) parts.add('<h3>$inner</h3>');
      continue;
    }
    if (name == 'subtitle') {
      final inner = _fb2Inlines(child, binaries).trim();
      if (inner.isNotEmpty) parts.add('<h4>$inner</h4>');
      continue;
    }
    if (name == 'epigraph' || name == 'cite') {
      final quote = _fb2QuoteHtml(child, binaries);
      if (quote != null) parts.add(quote);
      continue;
    }
    if (name == 'text-author') {
      final inner = _fb2Inlines(child, binaries).trim();
      if (inner.isNotEmpty) parts.add('<p>$inner</p>');
      continue;
    }
    if (name == 'date') {
      final html = _fb2DateHtml(child, binaries);
      if (html != null) parts.add(html);
      continue;
    }
    if (name != 'stanza') continue;
    final stanza = _fb2StanzaHtml(child, binaries);
    if (stanza != null) parts.add(stanza);
  }
  if (parts.isEmpty) return null;
  return '<blockquote>${parts.join()}</blockquote>';
}

String? _fb2DateHtml(XmlElement date, Map<String, String> binaries) {
  final inner = _fb2Inlines(date, binaries).trim();
  if (inner.isNotEmpty) return '<p>$inner</p>';
  final value = _escapeHtml((date.getAttribute('value') ?? '').trim());
  if (value.isEmpty) return null;
  return '<p>$value</p>';
}

String? _fb2StanzaHtml(XmlElement stanza, Map<String, String> binaries) {
  final parts = <String>[];
  final lines = <String>[];
  for (final child in stanza.childElements) {
    final name = child.name.local;
    if (name == 'title') {
      final inner = _fb2Inlines(child, binaries).trim();
      if (inner.isNotEmpty) parts.add('<h4>$inner</h4>');
      continue;
    }
    if (name == 'subtitle') {
      final inner = _fb2Inlines(child, binaries).trim();
      if (inner.isNotEmpty) parts.add('<h5>$inner</h5>');
      continue;
    }
    if (name != 'v') continue;
    final inner = _fb2Inlines(child, binaries);
    if (inner.trim().isNotEmpty) lines.add(inner);
  }
  if (lines.isNotEmpty) parts.add('<p>${lines.join('<br/>')}</p>');
  if (parts.isEmpty) return null;
  return parts.join();
}

String? _fb2QuoteHtml(XmlElement quote, Map<String, String> binaries) {
  final parts = <String>[];
  for (final child in quote.childElements) {
    final name = child.name.local;
    if (name == 'p') {
      final paragraph = _fb2ParagraphHtml(child, binaries);
      if (paragraph != null) parts.add(paragraph);
      continue;
    }
    if (name == 'empty-line') {
      parts.add('<p><br/></p>');
      continue;
    }
    if (name == 'subtitle') {
      final inner = _fb2Inlines(child, binaries);
      if (inner.trim().isNotEmpty) parts.add('<h2>$inner</h2>');
      continue;
    }
    if (name == 'poem') {
      final poem = _fb2PoemHtml(child, binaries);
      if (poem != null) parts.add(poem);
      continue;
    }
    if (name == 'table') {
      final table = _fb2TableHtml(child, binaries);
      if (table != null) parts.add(table);
      continue;
    }
    if (name == 'cite') {
      final nested = _fb2QuoteHtml(child, binaries);
      if (nested != null) parts.add(nested);
      continue;
    }
    if (name != 'text-author') continue;
    final inner = _fb2Inlines(child, binaries).trim();
    if (inner.isNotEmpty) parts.add('<p>$inner</p>');
  }
  if (parts.isEmpty) return null;
  return '<blockquote>${parts.join()}</blockquote>';
}

String? _fb2AnnotationHtml(
  XmlElement annotation,
  Map<String, String> binaries,
) {
  final parts = <String>[];
  for (final child in annotation.childElements) {
    final name = child.name.local;
    if (name == 'empty-line') {
      parts.add('<p><br/></p>');
      continue;
    }
    if (name == 'subtitle') {
      final inner = _fb2Inlines(child, binaries);
      if (inner.trim().isNotEmpty) parts.add('<h2>$inner</h2>');
      continue;
    }
    if (name == 'cite') {
      final quote = _fb2QuoteHtml(child, binaries);
      if (quote != null) parts.add(quote);
      continue;
    }
    if (name == 'poem') {
      final poem = _fb2PoemHtml(child, binaries);
      if (poem != null) parts.add(poem);
      continue;
    }
    if (name == 'table') {
      final table = _fb2TableHtml(child, binaries);
      if (table != null) parts.add(table);
      continue;
    }
    if (name != 'p') continue;
    final paragraph = _fb2ParagraphHtml(child, binaries);
    if (paragraph != null) parts.add(paragraph);
  }
  if (parts.isEmpty) return null;
  return '<aside>${parts.join()}</aside>';
}

String? _fb2TableHtml(XmlElement table, Map<String, String> binaries) {
  String? caption;
  final rows = <String>[];
  for (final child in table.childElements) {
    final name = child.name.local;
    if (name == 'title') {
      final inner = _fb2Inlines(child, binaries).trim();
      if (inner.isNotEmpty) caption = '<caption>$inner</caption>';
      continue;
    }
    if (name != 'tr') continue;
    final cells = <String>[];
    for (final cell in child.childElements) {
      final cellName = cell.name.local;
      if (cellName != 'th' && cellName != 'td') continue;
      cells.add(
        '<$cellName${_fb2TableCellAttrs(cell)}>${_fb2TableCellInner(cell, binaries)}</$cellName>',
      );
    }
    if (cells.isNotEmpty) rows.add('<tr>${cells.join()}</tr>');
  }
  if (rows.isEmpty) return null;
  return '<table>${caption ?? ''}${rows.join()}</table>';
}

String _fb2TableCellInner(XmlElement cell, Map<String, String> binaries) {
  final paragraphs = [
    for (final child in cell.childElements)
      if (child.name.local == 'p') _fb2Inlines(child, binaries),
  ].where((part) => part.trim().isNotEmpty).toList();
  if (paragraphs.isNotEmpty) return paragraphs.join('<br/>');
  return _fb2Inlines(cell, binaries);
}

String _fb2TableCellAttrs(XmlElement cell) {
  final parts = <String>[];
  for (final name in const ['colspan', 'rowspan']) {
    final n = int.tryParse((cell.getAttribute(name) ?? '').trim());
    if (n == null || n < 1) continue;
    parts.add(' $name="$n"');
  }
  final align = (cell.getAttribute('align') ?? '').trim().toLowerCase();
  if (const {'left', 'right', 'center'}.contains(align)) {
    parts.add(' align="$align"');
  }
  final valign = (cell.getAttribute('valign') ?? '').trim().toLowerCase();
  if (const {'top', 'middle', 'bottom'}.contains(valign)) {
    parts.add(' valign="$valign"');
  }
  return parts.join();
}

String _fb2Inlines(XmlElement parent, Map<String, String> binaries) {
  return [for (final node in parent.children) _fb2InlineHtml(node, binaries)]
      .join();
}

String _fb2InlineHtml(XmlNode node, Map<String, String> binaries) {
  if (node is XmlText) return _escapeHtml(node.value);
  if (node is! XmlElement) return '';
  switch (node.name.local) {
    case 'image':
      return _fb2Img(node, binaries) ?? '';
    case 'emphasis':
      final inner = _fb2Inlines(node, binaries);
      return inner.isEmpty ? '' : '<em>$inner</em>';
    case 'strong':
      final inner = _fb2Inlines(node, binaries);
      return inner.isEmpty ? '' : '<strong>$inner</strong>';
    case 'strikethrough':
      final inner = _fb2Inlines(node, binaries);
      return inner.isEmpty ? '' : '<s>$inner</s>';
    case 'sub':
      final inner = _fb2Inlines(node, binaries);
      return inner.isEmpty ? '' : '<sub>$inner</sub>';
    case 'sup':
      final inner = _fb2Inlines(node, binaries);
      return inner.isEmpty ? '' : '<sup>$inner</sup>';
    case 'code':
      final inner = _fb2Inlines(node, binaries);
      return inner.isEmpty ? '' : '<code>$inner</code>';
    case 'a':
      final inner = _fb2Inlines(node, binaries);
      final href = (_hrefOf(node) ?? '').trim();
      final idAttr = _fb2IdAttr(node);
      if (inner.isNotEmpty && href.startsWith('#') && href.length > 1) {
        return '<a href="${_escapeAttr(href)}"$idAttr>$inner</a>';
      }
      if (idAttr.isNotEmpty) return '<span$idAttr>$inner</span>';
      return inner;
    default:
      return _fb2Inlines(node, binaries);
  }
}

final _fb2HashHref = RegExp(r'<a href="#([^"]+)">');

void _collectFb2Ids(
  XmlElement section,
  String href,
  Map<String, String> idToHref,
) {
  void add(String? raw) {
    final id = (raw ?? '').trim();
    if (id.isEmpty) return;
    idToHref.putIfAbsent(_escapeAttr(id), () => href);
  }

  add(section.getAttribute('id'));
  for (final child in section.childElements) {
    if (child.name.local == 'section') continue;
    if (child.name.local == 'p') add(child.getAttribute('id'));
    for (final node in child.descendants.whereType<XmlElement>()) {
      if (node.name.local == 'section') continue;
      if (node.name.local == 'a' || node.name.local == 'p') {
        add(node.getAttribute('id'));
      }
    }
  }
}

String _rewriteFb2HashHrefs(String html, Map<String, String> idToHref) {
  if (idToHref.isEmpty) return html;
  return html.replaceAllMapped(_fb2HashHref, (match) {
    final id = match[1]!;
    final target = idToHref[id];
    if (target == null) return match[0]!;
    return '<a href="$target#$id">';
  });
}

String? _fb2Img(XmlElement image, Map<String, String> binaries) {
  final href = _hrefOf(image);
  if (href == null || href.isEmpty) return null;
  final lower = href.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('//')) {
    return null;
  }
  final id = href.startsWith('#') ? href.substring(1) : href;
  final uri = binaries[id] ?? binaries[id.toLowerCase()];
  if (uri == null) return null;
  return '<img src="$uri"/>';
}

Map<String, String> _fb2BinaryUris(XmlDocument xml) {
  final uris = <String, String>{};
  for (final binary in xml.descendants.whereType<XmlElement>()) {
    if (binary.name.local != 'binary') continue;
    final id = (binary.getAttribute('id') ?? '').trim();
    if (id.isEmpty) continue;
    final raw = binary.innerText.replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) continue;
    final mime = _fb2ImageMime(id, binary.getAttribute('content-type'));
    if (mime == null) continue;
    try {
      if (base64Decode(raw).isEmpty) continue;
    } on FormatException {
      continue;
    }
    final uri = 'data:$mime;base64,$raw';
    uris[id] = uri;
    uris[id.toLowerCase()] = uri;
  }
  return uris;
}

String? _fb2ImageMime(String id, String? contentType) {
  if (contentType != null && contentType.toLowerCase().startsWith('image/')) {
    return contentType;
  }
  final lower = id.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  return null;
}

String? _hrefOf(XmlElement element) {
  for (final attr in element.attributes) {
    if (attr.name.local == 'href') return attr.value;
  }
  return null;
}

String _escapeHtml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _escapeAttr(String text) {
  return _escapeHtml(text).replaceAll('"', '&quot;');
}

String _fb2IdAttr(XmlElement node) {
  final id = (node.getAttribute('id') ?? '').trim();
  return id.isEmpty ? '' : ' id="${_escapeAttr(id)}"';
}

String _firstLine(String body) {
  final line = body.split('\n').first.trim();
  return line.runes.length <= 40 ? line : '';
}
