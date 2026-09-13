import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'models.dart';
import 'reflow_reader.dart';

const odtTextCharLimit = 2 * 1024 * 1024;
const _odtMimeType = 'application/vnd.oasis.opendocument.text';

class ParsedOdt {
  const ParsedOdt({
    required this.title,
    required this.author,
    required this.package,
  });

  final String title;
  final String author;
  final ParsedReflowPackage package;

  List<ReflowChapter> get chapters => package.chapters;
  String get fullText => package.fullText;
  bool get truncated => package.truncated;
}

ParsedOdt parseOdt(List<int> bytes, {String fallbackTitle = 'Document'}) {
  late final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('corrupt odt');
  }
  final files = <String, ArchiveFile>{};
  for (final file in archive) {
    if (file.isFile) files[_normalizePath(file.name)] = file;
  }
  final mimeFile = files['mimetype'];
  if (mimeFile == null ||
      utf8.decode(mimeFile.content as List<int>).trim() != _odtMimeType) {
    throw const FormatException('corrupt odt');
  }
  final contentFile = files['content.xml'];
  if (contentFile == null) throw const FormatException('corrupt odt');

  final content = _parseXml(contentFile);
  final styleFile = files['styles.xml'];
  final styles = _styleMap([
    if (styleFile != null) _parseXml(styleFile),
    content,
  ]);
  final body = _documentBody(content);
  final blocks = _blocksFromContainer(body, styles);
  if (blocks.isEmpty) throw const FormatException('corrupt odt');

  final metaFile = files['meta.xml'];
  final meta = metaFile == null ? null : _parseXml(metaFile);
  final title = meta == null ? '' : (_firstLocalText(meta, 'title') ?? '');
  final author = meta == null
      ? ''
      : (_firstLocalText(meta, 'creator') ??
                _firstLocalText(meta, 'initial-creator') ??
                '')
            .trim();
  return ParsedOdt(
    title: title.trim(),
    author: author,
    package: buildReflowPackage(
      blocks: blocks,
      fallbackTitle: title.trim().isEmpty ? fallbackTitle : title.trim(),
      maxChars: odtTextCharLimit,
    ),
  );
}

class OdtReaderDocument extends ReflowReaderDocument {
  OdtReaderDocument._({required super.metadata, required super.parsed});

  factory OdtReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    final parsed = parseOdt(bytes, fallbackTitle: metadata.title);
    return OdtReaderDocument._(metadata: metadata, parsed: parsed.package);
  }
}

class _OdtStyle {
  const _OdtStyle({
    this.parent,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.superScript = false,
    this.subScript = false,
  });

  final String? parent;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool superScript;
  final bool subScript;

  _OdtStyle merge(_OdtStyle? inherited) {
    if (inherited == null) return this;
    return _OdtStyle(
      parent: parent,
      bold: bold || inherited.bold,
      italic: italic || inherited.italic,
      underline: underline || inherited.underline,
      strike: strike || inherited.strike,
      superScript: superScript || inherited.superScript,
      subScript: subScript || inherited.subScript,
    );
  }
}

class _OdtStyleMap {
  const _OdtStyleMap(this._styles);

  final Map<String, _OdtStyle> _styles;

  _OdtStyle? operator [](String? name) {
    if (name == null || name.isEmpty) return null;
    return _resolve(name, {});
  }

  _OdtStyle? _resolve(String name, Set<String> seen) {
    final style = _styles[name];
    if (style == null || !seen.add(name)) return null;
    return style.merge(_resolve(style.parent ?? '', seen));
  }
}

List<ReflowBlock> _blocksFromContainer(
  XmlElement container,
  _OdtStyleMap styles,
) {
  final blocks = <ReflowBlock>[];
  for (final child in container.childElements) {
    switch (child.name.local) {
      case 'h':
        final block = _headingBlock(child, styles);
        if (block != null) blocks.add(block);
      case 'p':
        final block = _paragraphBlock(child, styles);
        if (block != null) blocks.add(block);
      case 'list':
        final block = _listBlock(child, styles);
        if (block != null) blocks.add(block);
      case 'table':
        final block = _tableBlock(child, styles);
        if (block != null) blocks.add(block);
      case 'section':
        blocks.addAll(_blocksFromContainer(child, styles));
    }
  }
  return blocks;
}

ReflowBlock? _headingBlock(XmlElement heading, _OdtStyleMap styles) {
  final text = _textContent(heading).trim();
  if (text.isEmpty) return null;
  final styleName = _attribute(heading, 'style-name');
  final level =
      int.tryParse(_attribute(heading, 'outline-level') ?? '') ??
      _headingLevelFromStyle(styleName) ??
      1;
  final inline = heading.children
      .map((child) => _inlineHtml(child, styles))
      .join();
  final tag = 'h${level.clamp(1, 6)}';
  return ReflowBlock(
    text: text,
    html: '<$tag>$inline</$tag>',
    headingLevel: level.clamp(1, 6),
  );
}

ReflowBlock? _paragraphBlock(XmlElement paragraph, _OdtStyleMap styles) {
  final text = _textContent(paragraph).trim();
  if (text.isEmpty) return null;
  final inline = paragraph.children
      .map((child) => _inlineHtml(child, styles))
      .join();
  return ReflowBlock(text: text, html: '<p>$inline</p>');
}

ReflowBlock? _listBlock(XmlElement list, _OdtStyleMap styles) {
  final html = StringBuffer('<ul>');
  final text = StringBuffer();
  var hasContent = false;
  for (final item in list.childElements.where(
    (child) => child.name.local == 'list-item',
  )) {
    final blocks = _blocksFromContainer(item, styles);
    final itemText = blocks
        .map((block) => block.text.trim())
        .where((value) => value.isNotEmpty)
        .join('\n');
    if (itemText.isEmpty) continue;
    hasContent = true;
    html
      ..write('<li>')
      ..write(blocks.map((block) => block.html).join())
      ..write('</li>');
    text.writeln('- $itemText');
  }
  html.write('</ul>');
  return hasContent
      ? ReflowBlock(text: text.toString().trim(), html: html.toString())
      : null;
}

ReflowBlock? _tableBlock(XmlElement table, _OdtStyleMap styles) {
  final html = StringBuffer('<table>');
  final text = StringBuffer();
  var hasContent = false;
  for (final row in table.childElements.where(
    (child) => child.name.local == 'table-row',
  )) {
    html.write('<tr>');
    final rowText = <String>[];
    for (final cell in row.childElements.where(
      (child) => child.name.local == 'table-cell',
    )) {
      final blocks = _blocksFromContainer(cell, styles);
      final cellText = blocks
          .map((block) => block.text.trim())
          .where((value) => value.isNotEmpty)
          .join('\n');
      if (cellText.isNotEmpty) hasContent = true;
      html
        ..write('<td>')
        ..write(blocks.map((block) => block.html).join())
        ..write('</td>');
      rowText.add(cellText);
    }
    html.write('</tr>');
    if (rowText.any((value) => value.isNotEmpty)) {
      text.writeln(rowText.join('\t'));
    }
  }
  html.write('</table>');
  return hasContent
      ? ReflowBlock(text: text.toString().trim(), html: html.toString())
      : null;
}

String _inlineHtml(XmlNode node, _OdtStyleMap styles) {
  if (node is XmlText) return _escape(node.value);
  if (node is! XmlElement) return '';
  switch (node.name.local) {
    case 'span':
      final inner = node.children
          .map((child) => _inlineHtml(child, styles))
          .join();
      return _wrapStyle(inner, styles[_attribute(node, 'style-name')]);
    case 'a':
      final href = _attribute(node, 'href')?.trim() ?? '';
      final inner = node.children
          .map((child) => _inlineHtml(child, styles))
          .join();
      return href.isEmpty
          ? inner
          : '<a href="${_escapeAttribute(href)}">$inner</a>';
    case 's':
      final count = int.tryParse(_attribute(node, 'c') ?? '') ?? 1;
      return List.filled(count.clamp(1, 100), ' ').join();
    case 'tab':
      return '\t';
    case 'line-break':
      return '<br/>';
    case 'bookmark-ref':
    case 'note-ref':
      return node.children.map((child) => _inlineHtml(child, styles)).join();
    default:
      return '';
  }
}

String _wrapStyle(String html, _OdtStyle? style) {
  if (style == null || html.isEmpty) return html;
  var output = html;
  if (style.bold) output = '<strong>$output</strong>';
  if (style.italic) output = '<em>$output</em>';
  if (style.underline) output = '<u>$output</u>';
  if (style.strike) output = '<s>$output</s>';
  if (style.superScript) output = '<sup>$output</sup>';
  if (style.subScript) output = '<sub>$output</sub>';
  return output;
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
      case 's':
        final count = int.tryParse(_attribute(child, 'c') ?? '') ?? 1;
        output.write(List.filled(count.clamp(1, 100), ' ').join());
      case 'tab':
        output.write('\t');
      case 'line-break':
        output.write('\n');
      case 'note':
        break;
      default:
        output.write(_textContent(child));
    }
  }
  return output.toString();
}

_OdtStyleMap _styleMap(List<XmlDocument> documents) {
  final raw = <String, _OdtStyle>{};
  for (final document in documents) {
    for (final style in document.descendants.whereType<XmlElement>()) {
      if (style.name.local != 'style') continue;
      final family = _attribute(style, 'family');
      if (family != 'text' && family != 'paragraph') continue;
      final name = _attribute(style, 'name');
      if (name == null || name.isEmpty) continue;
      final properties = _directChild(style, 'text-properties');
      final position = _attribute(properties, 'text-position') ?? '';
      raw[name] = _OdtStyle(
        parent: _attribute(style, 'parent-style-name'),
        bold: _isBold(_attribute(properties, 'font-weight')),
        italic: _isItalic(_attribute(properties, 'font-style')),
        underline: _isVisibleLine(
          _attribute(properties, 'text-underline-style'),
        ),
        strike: _isVisibleLine(
          _attribute(properties, 'text-line-through-style'),
        ),
        superScript: position.startsWith('super'),
        subScript: position.startsWith('sub'),
      );
    }
  }
  return _OdtStyleMap(raw);
}

bool _isBold(String? value) {
  final normalized = value?.toLowerCase();
  if (normalized == null || normalized == 'normal') return false;
  if (normalized == 'bold') return true;
  final weight = int.tryParse(normalized);
  return weight != null && weight >= 600;
}

bool _isItalic(String? value) {
  final normalized = value?.toLowerCase();
  return normalized == 'italic' || normalized == 'oblique';
}

bool _isVisibleLine(String? value) {
  final normalized = value?.toLowerCase();
  return normalized != null && normalized != 'none';
}

int? _headingLevelFromStyle(String? styleName) {
  final normalized = styleName
      ?.replaceAll('_20_', ' ')
      .replaceAll('_', ' ')
      .toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  final match = RegExp(r'(?:heading|标题)\s*([1-6])').firstMatch(normalized);
  return match == null ? null : int.parse(match.group(1)!);
}

XmlElement _documentBody(XmlDocument xml) {
  for (final element in xml.descendants.whereType<XmlElement>()) {
    if (element.name.local != 'body') continue;
    for (final child in element.childElements) {
      if (child.name.local == 'text') return child;
    }
  }
  throw const FormatException('corrupt odt');
}

XmlElement? _directChild(XmlElement element, String localName) {
  for (final child in element.childElements) {
    if (child.name.local == localName) return child;
  }
  return null;
}

String? _attribute(XmlElement? element, String localName) {
  if (element == null) return null;
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) return attribute.value;
  }
  return null;
}

XmlDocument _parseXml(ArchiveFile file) {
  try {
    return XmlDocument.parse(utf8.decode(file.content as List<int>));
  } on FormatException {
    throw const FormatException('corrupt odt');
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
