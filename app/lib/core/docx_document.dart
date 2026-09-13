import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'models.dart';
import 'reader_runtime.dart';

const docxTextCharLimit = 2 * 1024 * 1024;

class DocxChapter {
  const DocxChapter({
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

class ParsedDocx {
  const ParsedDocx({
    required this.title,
    required this.author,
    required this.chapters,
    required this.fullText,
    required this.truncated,
  });

  final String title;
  final String author;
  final List<DocxChapter> chapters;
  final String fullText;
  final bool truncated;
}

ParsedDocx parseDocx(List<int> bytes, {String fallbackTitle = 'Document'}) {
  late final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('corrupt docx');
  }

  final files = <String, ArchiveFile>{};
  for (final file in archive) {
    if (file.isFile) files[_normalizePath(file.name)] = file;
  }
  final documentFile = files['word/document.xml'];
  if (documentFile == null) {
    throw const FormatException('corrupt docx');
  }
  final documentXml = _parseXml(documentFile);
  final relationships = _relationships(files['word/_rels/document.xml.rels']);
  final body = documentXml.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 'body')
      .firstOrNull;
  if (body == null) throw const FormatException('corrupt docx');

  final blocks = <_DocxBlock>[];
  for (final child in body.childElements) {
    switch (child.name.local) {
      case 'p':
        final block = _paragraphBlock(child, relationships);
        if (block != null) blocks.add(block);
      case 'tbl':
        final block = _tableBlock(child, relationships);
        if (block != null) blocks.add(block);
    }
  }
  if (blocks.isEmpty) throw const FormatException('corrupt docx');

  final core = files['docprops/core.xml'];
  final title = core == null
      ? ''
      : (_firstLocalText(_parseXml(core), 'title') ?? '').trim();
  final author = core == null
      ? ''
      : (_firstLocalText(_parseXml(core), 'creator') ?? '').trim();
  final chaptersResult = _chapters(
    blocks,
    fallbackTitle: title.isEmpty ? fallbackTitle : title,
  );
  return ParsedDocx(
    title: title,
    author: author,
    chapters: chaptersResult.chapters,
    fullText: chaptersResult.fullText,
    truncated: chaptersResult.truncated,
  );
}

class DocxReaderDocument implements HtmlChapteredDocument {
  DocxReaderDocument._({required this.metadata, required this.parsed});

  factory DocxReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    return DocxReaderDocument._(
      metadata: metadata,
      parsed: parseDocx(bytes, fallbackTitle: metadata.title),
    );
  }

  @override
  final DocumentMetadata metadata;
  final ParsedDocx parsed;
  int sectionIndex = 0;

  DocxChapter get currentChapter =>
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

class _DocxBlock {
  const _DocxBlock({required this.text, required this.html, this.headingLevel});

  final String text;
  final String html;
  final int? headingLevel;
}

class _DocxChapters {
  const _DocxChapters({
    required this.chapters,
    required this.fullText,
    required this.truncated,
  });

  final List<DocxChapter> chapters;
  final String fullText;
  final bool truncated;
}

_DocxChapters _chapters(
  List<_DocxBlock> blocks, {
  required String fallbackTitle,
}) {
  final raw = <_RawChapter>[];
  var current = <_DocxBlock>[];
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
      _RawChapter(
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
  if (raw.isEmpty) throw const FormatException('corrupt docx');

  final chapters = <DocxChapter>[];
  final fullText = StringBuffer();
  var truncated = false;
  for (final chapter in raw) {
    if (fullText.length >= docxTextCharLimit) {
      truncated = true;
      break;
    }
    final remaining = docxTextCharLimit - fullText.length;
    var text = chapter.text;
    var html = chapter.html;
    if (text.length > remaining) {
      text = text.substring(0, remaining);
      html = _plainHtml(text);
      truncated = true;
    }
    final startOffset = fullText.length;
    if (fullText.isNotEmpty) fullText.write('\n\n');
    fullText.write(text);
    chapters.add(
      DocxChapter(
        href: 'section-${chapters.length}',
        title: chapter.title,
        text: text,
        html: html,
        startOffset: startOffset,
      ),
    );
    if (truncated) break;
  }
  return _DocxChapters(
    chapters: chapters,
    fullText: fullText.toString(),
    truncated: truncated,
  );
}

class _RawChapter {
  const _RawChapter({
    required this.title,
    required this.text,
    required this.html,
  });

  final String title;
  final String text;
  final String html;
}

_DocxBlock? _paragraphBlock(
  XmlElement paragraph,
  Map<String, String> relationships,
) {
  final text = _textContent(paragraph).trim();
  if (text.isEmpty) return null;
  final properties = _directChild(paragraph, 'pPr');
  final headingLevel = _headingLevel(properties);
  final inline = paragraph.childElements
      .map((child) => _inlineHtml(child, relationships))
      .join();
  if (headingLevel != null) {
    final tag = 'h${headingLevel.clamp(1, 6)}';
    return _DocxBlock(
      text: text,
      html: '<$tag>$inline</$tag>',
      headingLevel: headingLevel,
    );
  }
  final isList =
      properties != null &&
      (_hasDescendant(properties, 'numPr') ||
          (_styleValue(properties) ?? '').toLowerCase().contains('list'));
  return _DocxBlock(
    text: isList ? '- $text' : text,
    html: '<p${isList ? ' class="list-item"' : ''}>$inline</p>',
  );
}

_DocxBlock? _tableBlock(XmlElement table, Map<String, String> relationships) {
  final rows = table.childElements.where((child) => child.name.local == 'tr');
  final html = StringBuffer('<table>');
  final text = StringBuffer();
  var hasContent = false;
  for (final row in rows) {
    html.write('<tr>');
    final cells = row.childElements.where((child) => child.name.local == 'tc');
    final rowText = <String>[];
    for (final cell in cells) {
      final cellHtml = StringBuffer();
      final cellText = <String>[];
      for (final child in cell.childElements) {
        if (child.name.local == 'p') {
          final block = _paragraphBlock(child, relationships);
          if (block == null) continue;
          cellHtml.write(block.html);
          cellText.add(block.text);
        } else if (child.name.local == 'tbl') {
          final block = _tableBlock(child, relationships);
          if (block == null) continue;
          cellHtml.write(block.html);
          cellText.add(block.text);
        }
      }
      final content = cellText.join('\n');
      if (content.isNotEmpty) hasContent = true;
      html
        ..write('<td>')
        ..write(cellHtml)
        ..write('</td>');
      rowText.add(content);
    }
    html.write('</tr>');
    if (rowText.any((value) => value.isNotEmpty)) {
      text.writeln(rowText.join('\t'));
    }
  }
  html.write('</table>');
  if (!hasContent) return null;
  return _DocxBlock(text: text.toString().trim(), html: html.toString());
}

String _inlineHtml(XmlElement node, Map<String, String> relationships) {
  switch (node.name.local) {
    case 't':
      return _escape(node.innerText);
    case 'tab':
      return '\t';
    case 'br':
    case 'cr':
      return '<br/>';
    case 'hyperlink':
      final inner = node.childElements
          .map((child) => _inlineHtml(child, relationships))
          .join();
      final anchor = _attribute(node, 'anchor');
      if (anchor != null && anchor.isNotEmpty) {
        return '<a href="#${_escapeAttribute(anchor)}">$inner</a>';
      }
      final id = node.attributes
          .where((attribute) => attribute.name.local == 'id')
          .map((attribute) => attribute.value)
          .firstOrNull;
      final target = id == null ? null : relationships[id];
      return target == null
          ? inner
          : '<a href="${_escapeAttribute(target)}">$inner</a>';
    case 'r':
      final run = node.childElements
          .map((child) => _inlineHtml(child, relationships))
          .join();
      if (run.isEmpty) return '';
      final properties = _directChild(node, 'rPr');
      var html = run;
      if (_toggleOn(properties, 'b')) html = '<strong>$html</strong>';
      if (_toggleOn(properties, 'i')) html = '<em>$html</em>';
      if (_toggleOn(properties, 'u')) html = '<u>$html</u>';
      if (_toggleOn(properties, 'strike') || _toggleOn(properties, 'dstrike')) {
        html = '<s>$html</s>';
      }
      final align = properties == null
          ? null
          : _childAttribute(properties, 'vertAlign', 'val');
      if (align == 'superscript') html = '<sup>$html</sup>';
      if (align == 'subscript') html = '<sub>$html</sub>';
      return html;
    default:
      return '';
  }
}

String _textContent(XmlNode node) {
  final output = StringBuffer();
  for (final child in node.children) {
    if (child is XmlText) {
      output.write(child.value);
      continue;
    }
    if (child is! XmlElement) continue;
    switch (child.name.local) {
      case 't':
        output.write(child.innerText);
      case 'tab':
        output.write('\t');
      case 'br':
      case 'cr':
        output.write('\n');
      default:
        output.write(_textContent(child));
    }
  }
  return output.toString();
}

int? _headingLevel(XmlElement? properties) {
  if (properties == null) return null;
  final style = _styleValue(properties)?.toLowerCase() ?? '';
  if (style == 'title') return 1;
  final match = RegExp(r'(?:heading|标题)\s*([1-6])')
      .firstMatch(style.replaceAll('-', ' '));
  if (match != null) return int.parse(match.group(1)!);
  final outline = _childAttribute(properties, 'outlineLvl', 'val');
  final value = int.tryParse(outline ?? '');
  if (value != null && value >= 0) return (value + 1).clamp(1, 6);
  return null;
}

String? _styleValue(XmlElement properties) {
  return _childAttribute(properties, 'pStyle', 'val');
}

bool _toggleOn(XmlElement? properties, String name) {
  final element = properties == null ? null : _directChild(properties, name);
  if (element == null) return false;
  final value = _attribute(element, 'val')?.toLowerCase();
  return value != '0' && value != 'false' && value != 'none';
}

bool _hasDescendant(XmlElement element, String localName) {
  return element.descendants.whereType<XmlElement>().any(
    (child) => child.name.local == localName,
  );
}

XmlElement? _directChild(XmlElement element, String localName) {
  for (final child in element.childElements) {
    if (child.name.local == localName) return child;
  }
  return null;
}

String? _attribute(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) return attribute.value;
  }
  return null;
}

String? _childAttribute(
  XmlElement element,
  String childName,
  String attributeName,
) {
  final child = _directChild(element, childName);
  return child == null ? null : _attribute(child, attributeName);
}

Map<String, String> _relationships(ArchiveFile? file) {
  if (file == null) return const {};
  final xml = _parseXml(file);
  final relationships = <String, String>{};
  for (final relationship in xml.descendants.whereType<XmlElement>()) {
    if (relationship.name.local != 'Relationship') continue;
    final id = _attribute(relationship, 'Id');
    final target = _attribute(relationship, 'Target');
    if (id != null && target != null) relationships[id] = target;
  }
  return relationships;
}

XmlDocument _parseXml(ArchiveFile file) {
  try {
    return XmlDocument.parse(utf8.decode(file.content as List<int>));
  } on FormatException {
    throw const FormatException('corrupt docx');
  }
}

String? _firstLocalText(XmlDocument xml, String localName) {
  for (final element in xml.descendants.whereType<XmlElement>()) {
    if (element.name.local == localName &&
        element.innerText.trim().isNotEmpty) {
      return element.innerText.trim();
    }
  }
  return null;
}

String _plainHtml(String text) {
  return '<section><p>${_escape(text)}</p></section>';
}

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _escapeAttribute(String value) {
  return _escape(value).replaceAll('"', '&quot;').replaceAll("'", '&#39;');
}

String _normalizePath(String path) {
  return path
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/+'), '')
      .toLowerCase();
}
