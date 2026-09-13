import 'dart:convert';

import 'package:charset/charset.dart';

import 'models.dart';
import 'reflow_reader.dart';

const rtfTextCharLimit = 2 * 1024 * 1024;

class ParsedRtf {
  const ParsedRtf({
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

ParsedRtf parseRtf(List<int> bytes, {String fallbackTitle = 'Document'}) {
  if (!_looksLikeRtf(bytes)) throw const FormatException('corrupt rtf');
  final parser = _RtfParser(bytes)..parse();
  final blocks = parser.blocks;
  if (blocks.isEmpty) throw const FormatException('corrupt rtf');
  final title = _infoValue(bytes, 'title') ?? '';
  final author =
      _infoValue(bytes, 'author') ?? _infoValue(bytes, 'operator') ?? '';
  return ParsedRtf(
    title: title,
    author: author,
    package: buildReflowPackage(
      blocks: blocks,
      fallbackTitle: title.isEmpty ? fallbackTitle : title,
      maxChars: rtfTextCharLimit,
    ),
  );
}

class RtfReaderDocument extends ReflowReaderDocument {
  RtfReaderDocument._({required super.metadata, required super.parsed});

  factory RtfReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    final parsed = parseRtf(bytes, fallbackTitle: metadata.title);
    return RtfReaderDocument._(metadata: metadata, parsed: parsed.package);
  }
}

class _RtfParser {
  _RtfParser(this.bytes);

  final List<int> bytes;
  final List<ReflowBlock> blocks = [];
  final List<_RtfFrame> _frames = [_RtfFrame()];
  final List<List<_RtfCell>> _tableRows = [];
  final StringBuffer _paragraphText = StringBuffer();
  final StringBuffer _paragraphHtml = StringBuffer();
  final List<int> _pendingBytes = [];
  var _index = 0;
  var _codePage = 1252;
  int? _headingLevel;
  var _tableRowOpen = false;
  List<_RtfCell> _tableRow = [];
  var _closedRoot = false;

  bool get _ignored => _frames.any((frame) => frame.ignored);
  _RtfFrame get _frame => _frames.last;

  void parse() {
    while (_index < bytes.length) {
      final byte = bytes[_index++];
      switch (byte) {
        case 0x7B: // {
          _flushPending();
          _frames.add(_RtfFrame(style: _frame.style));
        case 0x7D: // }
          _flushPending();
          if (_frames.length > 1) {
            _frames.removeLast();
          }
          if (_frames.length == 1) _closedRoot = true;
        case 0x5C: // backslash
          _control();
        case 0x0A:
        case 0x0D:
          break;
        default:
          if (byte == 0x09) {
            _appendLiteral('\t');
          } else {
            _pendingBytes.add(byte);
          }
      }
    }
    _flushPending();
    _flushTable();
    _flushParagraph();
    if (_frames.length != 1 || !_closedRoot) {
      throw const FormatException('corrupt rtf');
    }
  }

  void _control() {
    if (_index >= bytes.length) return;
    final current = bytes[_index];
    if (_isAsciiLetter(current)) {
      _controlWord();
      return;
    }
    _index++;
    switch (current) {
      case 0x27: // apostrophe hex escape
        if (_index + 1 >= bytes.length) {
          throw const FormatException('corrupt rtf');
        }
        final value = _parseHex(bytes[_index], bytes[_index + 1]);
        _index += 2;
        if (value == null) throw const FormatException('corrupt rtf');
        if (!_ignored) _pendingBytes.add(value);
      case 0x7B:
        _appendLiteral('{');
      case 0x7D:
        _appendLiteral('}');
      case 0x5C:
        _appendLiteral('\\');
      case 0x7E:
        _appendLiteral('\u00A0');
      case 0x5F:
        _appendLiteral('-');
      case 0x2D:
        break;
      case 0x0A:
      case 0x0D:
        break;
      case 0x2A:
        _frame.ignored = true;
    }
  }

  void _controlWord() {
    final start = _index;
    while (_index < bytes.length && _isAsciiLetter(bytes[_index])) {
      _index++;
    }
    final name = String.fromCharCodes(bytes.sublist(start, _index));
    var sign = 1;
    if (_index < bytes.length && bytes[_index] == 0x2D) {
      sign = -1;
      _index++;
    }
    final numberStart = _index;
    while (_index < bytes.length && _isDigit(bytes[_index])) {
      _index++;
    }
    final parameter = numberStart == _index
        ? null
        : sign *
              int.parse(
                String.fromCharCodes(bytes.sublist(numberStart, _index)),
              );
    if (_index < bytes.length && bytes[_index] == 0x20) _index++;
    if (_ignored) return;

    switch (name) {
      case 'ansicpg':
        _codePage = parameter ?? _codePage;
      case 'fonttbl':
      case 'colortbl':
      case 'stylesheet':
      case 'info':
      case 'pict':
      case 'object':
      case 'header':
      case 'footer':
      case 'footnote':
      case 'field':
        _frame.ignored = true;
      case 'par':
        _flushPending();
        if (_tableRowOpen) {
          _appendLineBreak();
        } else {
          _flushParagraph();
        }
      case 'line':
        _appendLineBreak();
      case 'tab':
        _appendLiteral('\t');
      case 'pard':
        _flushPending();
        if (!_tableRowOpen) _flushTable();
        _headingLevel = null;
      case 'plain':
        _flushPending();
        _frame.style = const _RtfStyle();
      case 'b':
        _setStyle(bold: parameter != 0);
      case 'i':
        _setStyle(italic: parameter != 0);
      case 'ul':
        _setStyle(underline: parameter != 0);
      case 'ulnone':
        _setStyle(underline: false);
      case 'strike':
        _setStyle(strike: parameter != 0);
      case 'super':
        _setStyle(superScript: true, subScript: false);
      case 'sub':
        _setStyle(superScript: false, subScript: true);
      case 'nosupersub':
        _setStyle(superScript: false, subScript: false);
      case 'outlinelevel':
        _flushPending();
        _headingLevel = parameter == null ? null : (parameter + 1).clamp(1, 6);
      case 's':
        _flushPending();
        if (parameter != null && parameter > 0 && parameter <= 6) {
          _headingLevel = parameter;
        }
      case 'u':
        _flushPending();
        if (parameter != null) {
          final code = parameter < 0 ? parameter + 65536 : parameter;
          _appendLiteral(String.fromCharCode(code));
          if (_index < bytes.length && bytes[_index] == 0x3F) _index++;
        }
      case 'bin':
        _flushPending();
        if (parameter != null && parameter > 0) {
          _index = (_index + parameter).clamp(0, bytes.length);
        }
      case 'trowd':
        _flushParagraph();
        _tableRowOpen = true;
        _tableRow = [];
      case 'cell':
        _flushPending();
        _finishCell();
      case 'row':
        _flushPending();
        _finishCell();
        if (_tableRow.isNotEmpty) _tableRows.add(_tableRow);
        _tableRow = [];
        _tableRowOpen = false;
      case 'emdash':
        _appendLiteral('\u2014');
      case 'endash':
        _appendLiteral('\u2013');
      case 'bullet':
        _appendLiteral('\u2022');
      case 'lquote':
        _appendLiteral('\u2018');
      case 'rquote':
        _appendLiteral('\u2019');
      case 'ldblquote':
        _appendLiteral('\u201C');
      case 'rdblquote':
        _appendLiteral('\u201D');
    }
  }

  void _setStyle({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    bool? superScript,
    bool? subScript,
  }) {
    _flushPending();
    _frame.style = _frame.style.copyWith(
      bold: bold,
      italic: italic,
      underline: underline,
      strike: strike,
      superScript: superScript,
      subScript: subScript,
    );
  }

  void _appendLiteral(String value) {
    if (_ignored || value.isEmpty) return;
    _flushPending();
    _appendDecoded(value);
  }

  void _appendLineBreak() {
    if (_ignored || _tableRowOpen) return;
    _flushPending();
    _paragraphText.write('\n');
    _paragraphHtml.write('<br/>');
  }

  void _appendDecoded(String value) {
    if (value.isEmpty) return;
    _paragraphText.write(value);
    _paragraphHtml.write(_wrapStyle(_escape(value), _frame.style));
  }

  void _flushPending() {
    if (_pendingBytes.isEmpty) return;
    final decoded = _decodeBytes(_pendingBytes, _codePage);
    _pendingBytes.clear();
    if (!_ignored) _appendDecoded(decoded);
  }

  void _flushParagraph() {
    _flushPending();
    final text = _paragraphText.toString().trim();
    if (text.isNotEmpty) {
      final level = _headingLevel;
      final html = _paragraphHtml.toString();
      blocks.add(
        ReflowBlock(
          text: text,
          html: level == null
              ? '<p>$html</p>'
              : '<h${level.clamp(1, 6)}>$html</h${level.clamp(1, 6)}>',
          headingLevel: level,
        ),
      );
    }
    _paragraphText.clear();
    _paragraphHtml.clear();
  }

  void _finishCell() {
    final text = _paragraphText.toString().trim();
    if (text.isNotEmpty) {
      _tableRow.add(_RtfCell(text: text, html: _paragraphHtml.toString()));
    }
    _paragraphText.clear();
    _paragraphHtml.clear();
  }

  void _flushTable() {
    if (_tableRows.isEmpty) return;
    final html = StringBuffer('<table>');
    final text = StringBuffer();
    for (final row in _tableRows) {
      html.write('<tr>');
      final rowText = <String>[];
      for (final cell in row) {
        html
          ..write('<td>')
          ..write(cell.html)
          ..write('</td>');
        rowText.add(cell.text);
      }
      html.write('</tr>');
      text.writeln(rowText.join('\t'));
    }
    html.write('</table>');
    blocks.add(
      ReflowBlock(text: text.toString().trim(), html: html.toString()),
    );
    _tableRows.clear();
  }
}

class _RtfFrame {
  _RtfFrame({this.style = const _RtfStyle()});

  _RtfStyle style;
  bool ignored = false;
}

class _RtfStyle {
  const _RtfStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.superScript = false,
    this.subScript = false,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool superScript;
  final bool subScript;

  _RtfStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    bool? superScript,
    bool? subScript,
  }) {
    return _RtfStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
      superScript: superScript ?? this.superScript,
      subScript: subScript ?? this.subScript,
    );
  }
}

class _RtfCell {
  const _RtfCell({required this.text, required this.html});

  final String text;
  final String html;
}

String _wrapStyle(String html, _RtfStyle style) {
  var output = html;
  if (style.bold) output = '<strong>$output</strong>';
  if (style.italic) output = '<em>$output</em>';
  if (style.underline) output = '<u>$output</u>';
  if (style.strike) output = '<s>$output</s>';
  if (style.superScript) output = '<sup>$output</sup>';
  if (style.subScript) output = '<sub>$output</sub>';
  return output;
}

String _decodeBytes(List<int> bytes, int codePage) {
  if (codePage == 65001) {
    return utf8.decode(bytes, allowMalformed: true);
  }
  if (codePage == 936 || codePage == 54936) {
    return gbk.decode(bytes);
  }
  return latin1.decode(bytes, allowInvalid: true);
}

String? _infoValue(List<int> bytes, String controlWord) {
  final source = latin1.decode(bytes, allowInvalid: true);
  final infoAt = source.indexOf(r'\info');
  if (infoAt < 0) return null;
  final end = _matchingBrace(source, source.lastIndexOf('{', infoAt));
  if (end < 0) return null;
  final info = source.substring(infoAt, end);
  final match = RegExp(
    '\\\\$controlWord(?:\\s+)([^\\\\{}]*)',
    caseSensitive: false,
  ).firstMatch(info);
  final value = match?.group(1)?.trim() ?? '';
  return value.isEmpty ? null : _decodeInfo(value);
}

String _decodeInfo(String value) {
  var output = value;
  output = output.replaceAllMapped(
    RegExp(r"\\'([0-9a-fA-F]{2})"),
    (match) => latin1.decode([
      int.parse(match.group(1)!, radix: 16),
    ], allowInvalid: true),
  );
  output = output.replaceAllMapped(RegExp(r'\\u(-?\d+)\??'), (match) {
    final code = int.parse(match.group(1)!);
    return String.fromCharCode(code < 0 ? code + 65536 : code);
  });
  return output.trim();
}

int _matchingBrace(String source, int openAt) {
  if (openAt < 0) return -1;
  var depth = 0;
  for (var index = openAt; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') {
      depth--;
      if (depth == 0) return index;
    }
  }
  return -1;
}

bool _looksLikeRtf(List<int> bytes) {
  var offset = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    offset = 3;
  }
  while (offset < bytes.length &&
      (bytes[offset] == 0x20 ||
          bytes[offset] == 0x09 ||
          bytes[offset] == 0x0A ||
          bytes[offset] == 0x0D)) {
    offset++;
  }
  const header = [0x7B, 0x5C, 0x72, 0x74, 0x66];
  if (bytes.length - offset < header.length) return false;
  for (var index = 0; index < header.length; index++) {
    if (bytes[offset + index] != header[index]) return false;
  }
  return true;
}

int? _parseHex(int high, int low) {
  final highValue = _hexValue(high);
  final lowValue = _hexValue(low);
  if (highValue == null || lowValue == null) return null;
  return highValue * 16 + lowValue;
}

int? _hexValue(int byte) {
  if (byte >= 0x30 && byte <= 0x39) return byte - 0x30;
  if (byte >= 0x41 && byte <= 0x46) return byte - 0x41 + 10;
  if (byte >= 0x61 && byte <= 0x66) return byte - 0x61 + 10;
  return null;
}

bool _isAsciiLetter(int byte) =>
    (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A);

bool _isDigit(int byte) => byte >= 0x30 && byte <= 0x39;

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
