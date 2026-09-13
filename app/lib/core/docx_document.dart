import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'models.dart';
import 'reflow_reader.dart';

const docxTextCharLimit = 2 * 1024 * 1024;

class ParsedDocx {
  const ParsedDocx({
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

  final blocks = <ReflowBlock>[];
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
  final package = buildReflowPackage(
    blocks: blocks,
    fallbackTitle: title.isEmpty ? fallbackTitle : title,
    maxChars: docxTextCharLimit,
  );
  return ParsedDocx(title: title, author: author, package: package);
}

class DocxReaderDocument extends ReflowReaderDocument {
  DocxReaderDocument._({required super.metadata, required super.parsed});

  factory DocxReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    final parsed = parseDocx(bytes, fallbackTitle: metadata.title);
    return DocxReaderDocument._(metadata: metadata, parsed: parsed.package);
  }
}

ReflowBlock? _paragraphBlock(
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
    return ReflowBlock(
      text: text,
      html: '<$tag>$inline</$tag>',
      headingLevel: headingLevel,
    );
  }
  final isList =
      properties != null &&
      (_hasDescendant(properties, 'numPr') ||
          (_styleValue(properties) ?? '').toLowerCase().contains('list'));
  return ReflowBlock(
    text: isList ? '- $text' : text,
    html: '<p${isList ? ' class="list-item"' : ''}>$inline</p>',
  );
}

ReflowBlock? _tableBlock(XmlElement table, Map<String, String> relationships) {
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
  return ReflowBlock(text: text.toString().trim(), html: html.toString());
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
