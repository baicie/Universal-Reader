import 'dart:convert';
import 'dart:math' as math;

import 'models.dart';
import 'reader_runtime.dart';

const textReaderByteLimit = 1024 * 1024;
const textSectionCharLimit = 4000;

extension PlainTextFormat on DocumentFormat {
  bool get isPlainText =>
      this == DocumentFormat.txt ||
      this == DocumentFormat.markdown ||
      this == DocumentFormat.html;
}

class TextSection {
  const TextSection({
    required this.title,
    required this.body,
    required this.startOffset,
  });

  final String title;
  final String body;
  final int startOffset;
}

class ParsedTextDocument {
  const ParsedTextDocument({
    required this.fullText,
    required this.sections,
    required this.truncated,
  });

  final String fullText;
  final List<TextSection> sections;
  final bool truncated;
}

ParsedTextDocument parseTextDocument({
  required List<int> bytes,
  required DocumentFormat format,
}) {
  final truncated = bytes.length > textReaderByteLimit;
  final slice = truncated ? bytes.sublist(0, textReaderByteLimit) : bytes;
  var text = decodeTextBytes(slice);
  if (format == DocumentFormat.html) {
    text = stripHtml(text);
  }
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  final sections = format == DocumentFormat.markdown
      ? splitMarkdown(text)
      : splitPlainText(text);
  return ParsedTextDocument(
    fullText: text,
    sections: sections.isEmpty
        ? [TextSection(title: '', body: text, startOffset: 0)]
        : sections,
    truncated: truncated,
  );
}

String decodeTextBytes(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _utf16(bytes, 2, bigEndian: false);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _utf16(bytes, 2, bigEndian: true);
  }
  var offset = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    offset = 3;
  }
  return utf8.decode(bytes.sublist(offset), allowMalformed: true);
}

String _utf16(List<int> bytes, int offset, {required bool bigEndian}) {
  final units = <int>[];
  for (var i = offset; i + 1 < bytes.length; i += 2) {
    units.add(
      bigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : bytes[i] | (bytes[i + 1] << 8),
    );
  }
  return String.fromCharCodes(units);
}

String stripHtml(String source) {
  var text = source.replaceAll(
    RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
    '',
  );
  text = text.replaceAll(
    RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
    '',
  );
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
  text = text.replaceAll(
    RegExp(r'<h[1-6][^>]*>', caseSensitive: false),
    '\n\n',
  );
  text = text.replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n');
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  return text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

List<TextSection> splitMarkdown(String text) {
  final heading = RegExp(r'^#{1,6}\s+(.+)$', multiLine: true);
  final matches = heading.allMatches(text).toList();
  if (matches.isEmpty) return splitPlainText(text);
  final sections = <TextSection>[];
  if (matches.first.start > 0) {
    final preface = text.substring(0, matches.first.start).trim();
    if (preface.isNotEmpty) {
      sections.add(TextSection(title: '', body: preface, startOffset: 0));
    }
  }
  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
    sections.add(
      TextSection(
        title: match.group(1)!.trim(),
        body: text.substring(match.end, end).trim(),
        startOffset: match.start,
      ),
    );
  }
  return sections;
}

List<TextSection> splitPlainText(String text) {
  if (text.isEmpty) {
    return [const TextSection(title: '', body: '', startOffset: 0)];
  }
  final blocks = text
      .split(RegExp(r'\n{2,}'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .toList();
  if (blocks.length == 1) {
    return [TextSection(title: '', body: blocks.first, startOffset: 0)];
  }

  final sections = <TextSection>[];
  var cursor = 0;
  var i = 0;
  while (i < blocks.length) {
    final block = blocks[i];
    final start = text.indexOf(block, cursor);
    final offset = start < 0 ? cursor : start;
    final isTitle =
        i + 1 < blocks.length &&
        !block.contains('\n') &&
        _runeCount(block) <= 40;
    if (isTitle) {
      sections.add(
        TextSection(title: block, body: blocks[i + 1], startOffset: offset),
      );
      cursor = offset + block.length;
      i += 2;
      continue;
    }
    sections.add(
      TextSection(title: _firstLine(block), body: block, startOffset: offset),
    );
    cursor = offset + block.length;
    i += 1;
  }
  return _packSections(sections);
}

List<TextSection> _packSections(List<TextSection> sections) {
  if (sections.length != 1) return sections;
  final only = sections.single;
  if (only.body.length <= textSectionCharLimit) return sections;
  return _chunkBody(only);
}

List<TextSection> _chunkBody(TextSection section) {
  final chunks = <TextSection>[];
  var offset = section.startOffset;
  var index = 0;
  while (index < section.body.length) {
    final end = math.min(index + textSectionCharLimit, section.body.length);
    chunks.add(
      TextSection(
        title: section.title,
        body: section.body.substring(index, end),
        startOffset: offset,
      ),
    );
    offset += end - index;
    index = end;
  }
  return chunks;
}

String _firstLine(String block) {
  final line = block.split('\n').first.trim();
  return _runeCount(line) <= 40 ? line : '';
}

int _runeCount(String value) => value.runes.length;

class TextReaderDocument implements ReaderDocument {
  TextReaderDocument._({required this.metadata, required this.parsed});

  factory TextReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    return TextReaderDocument._(
      metadata: metadata,
      parsed: parseTextDocument(bytes: bytes, format: metadata.format),
    );
  }

  @override
  final DocumentMetadata metadata;
  final ParsedTextDocument parsed;
  int sectionIndex = 0;

  TextSection get currentSection =>
      parsed.sections[sectionIndex.clamp(0, parsed.sections.length - 1)];

  @override
  Future<Locator> currentLocator() async {
    return TextLocator(offset: currentSection.startOffset);
  }

  @override
  Future<String?> extractText(DocumentRange range) async {
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
    if (locator is! TextLocator) return;
    final index = parsed.sections.lastIndexWhere(
      (section) => section.startOffset <= locator.offset,
    );
    sectionIndex = index < 0 ? 0 : index;
  }

  @override
  Stream<double> get progress {
    final length = parsed.fullText.isEmpty ? 1 : parsed.fullText.length;
    return Stream<double>.value(currentSection.startOffset / length);
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty || !parsed.fullText.contains(query)) return const [];
    final offset = parsed.fullText.indexOf(query);
    return [
      SearchResult(
        title: metadata.title,
        excerpt: query,
        locator: TextLocator(offset: offset),
      ),
    ];
  }

  @override
  Future<List<TocItem>> getToc() async {
    return [
      for (final section in parsed.sections)
        TocItem(
          title: section.title,
          locator: TextLocator(offset: section.startOffset),
        ),
    ];
  }
}

class UnavailableReaderDocument implements ReaderDocument {
  UnavailableReaderDocument({required this.metadata});

  @override
  final DocumentMetadata metadata;

  @override
  Future<Locator> currentLocator() async => const TextLocator(offset: 0);

  @override
  Future<String?> extractText(DocumentRange range) async => null;

  @override
  Future<void> goTo(Locator locator) async {}

  @override
  Stream<double> get progress => const Stream<double>.empty();

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  Future<List<TocItem>> getToc() async => const [];
}
