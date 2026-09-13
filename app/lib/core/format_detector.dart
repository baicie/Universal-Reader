import 'dart:convert';

import 'package:archive/archive.dart';

import 'models.dart';

class FormatDetector {
  const FormatDetector();

  DocumentFormat detect(DocumentSource source) {
    final bytes = source.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      final byContent = _detectBytes(bytes, source.name);
      if (byContent != null) return byContent;
    }
    return _detectName(source.name);
  }

  DocumentFormat _detectName(String sourceName) {
    final name = sourceName.toLowerCase();
    if (name.endsWith('.epub')) return DocumentFormat.epub;
    if (name.endsWith('.pdf')) return DocumentFormat.pdf;
    if (name.endsWith('.mobi')) return DocumentFormat.mobi;
    if (name.endsWith('.azw3')) return DocumentFormat.azw3;
    if (name.endsWith('.fb2')) return DocumentFormat.fb2;
    if (name.endsWith('.txt')) return DocumentFormat.txt;
    if (name.endsWith('.md') || name.endsWith('.markdown')) {
      return DocumentFormat.markdown;
    }
    if (name.endsWith('.html') || name.endsWith('.htm')) {
      return DocumentFormat.html;
    }
    if (name.endsWith('.docx')) return DocumentFormat.docx;
    if (name.endsWith('.odt')) return DocumentFormat.odt;
    if (name.endsWith('.cbz')) return DocumentFormat.cbz;
    if (name.endsWith('.cbr')) return DocumentFormat.cbr;
    return DocumentFormat.unknown;
  }

  DocumentFormat? _detectBytes(List<int> bytes, String sourceName) {
    if (_startsWith(bytes, const [0x25, 0x50, 0x44, 0x46, 0x2D])) {
      return DocumentFormat.pdf;
    }
    if (_isRar(bytes)) return DocumentFormat.cbr;
    if (_startsWith(bytes, const [0x50, 0x4B])) return _detectZip(bytes);

    final header = _textHeader(bytes);
    if (header != null) {
      if (_looksLikeFb2(header)) return DocumentFormat.fb2;
      if (_looksLikeHtml(header)) return DocumentFormat.html;
      if (_looksLikeMarkdown(header)) return DocumentFormat.markdown;
    }
    final mobi = _detectMobi(bytes, sourceName);
    if (mobi != null) return mobi;
    if (header != null && _looksLikeText(bytes)) {
      final byName = _detectName(sourceName);
      return switch (byName) {
        DocumentFormat.txt ||
        DocumentFormat.markdown ||
        DocumentFormat.html ||
        DocumentFormat.fb2 => byName,
        DocumentFormat.unknown => DocumentFormat.txt,
        _ => null,
      };
    }
    return null;
  }

  DocumentFormat? _detectZip(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = <String>{};
      var hasWordDocument = false;
      var hasImage = false;
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/').toLowerCase();
        names.add(name);
        hasWordDocument |= name == 'word/document.xml';
        if (_hasImageExtension(name)) hasImage = true;
        if (name == 'mimetype') {
          final content = utf8.decode(
            file.content as List<int>,
            allowMalformed: true,
          );
          if (content.trim() == 'application/epub+zip') {
            return DocumentFormat.epub;
          }
          if (content.trim() == 'application/vnd.oasis.opendocument.text') {
            return DocumentFormat.odt;
          }
        }
      }
      if (names.contains('meta-inf/container.xml') ||
          names.any((name) => name.endsWith('.opf'))) {
        return DocumentFormat.epub;
      }
      if (hasWordDocument) return DocumentFormat.docx;
      if (hasImage) return DocumentFormat.cbz;
    } on Exception {
      return null;
    }
    return null;
  }

  DocumentFormat? _detectMobi(List<int> bytes, String sourceName) {
    if (bytes.length < 68) return null;
    final type = ascii.decode(bytes.sublist(60, 64), allowInvalid: true);
    final creator = ascii.decode(bytes.sublist(64, 68), allowInvalid: true);
    if (type != 'BOOK' || creator != 'MOBI') return null;
    final lowerName = sourceName.toLowerCase();
    if (lowerName.endsWith('.azw3')) return DocumentFormat.azw3;
    final headerEnd = bytes.length > 4096 ? 4096 : bytes.length;
    final header = ascii.decode(
      bytes.sublist(0, headerEnd),
      allowInvalid: true,
    );
    if (header.contains('AZW3') || header.contains('KF8')) {
      return DocumentFormat.azw3;
    }
    return DocumentFormat.mobi;
  }

  String? _textHeader(List<int> bytes) {
    final sample = bytes.length > 16384 ? bytes.sublist(0, 16384) : bytes;
    final decoded = _decodeText(sample);
    if (decoded == null) return null;
    final trimmed = decoded
        .replaceFirst('\uFEFF', '')
        .replaceFirst(RegExp(r'^\s+'), '');
    if (trimmed.isEmpty) return null;
    return trimmed.length > 16384 ? trimmed.substring(0, 16384) : trimmed;
  }

  String? _decodeText(List<int> bytes) {
    try {
      if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
        return _decodeUtf16(bytes.sublist(2), littleEndian: true);
      }
      if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return _decodeUtf16(bytes.sublist(2), littleEndian: false);
      }
      return utf8.decode(
        bytes.length >= 3 &&
                bytes[0] == 0xEF &&
                bytes[1] == 0xBB &&
                bytes[2] == 0xBF
            ? bytes.sublist(3)
            : bytes,
        allowMalformed: true,
      );
    } on FormatException {
      return null;
    }
  }

  String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      codeUnits.add(
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(codeUnits);
  }

  bool _looksLikeFb2(String header) {
    final lower = header.toLowerCase();
    return lower.contains('<fictionbook') &&
        (lower.startsWith('<?xml') ||
            lower.startsWith('<fictionbook') ||
            lower.startsWith('<!--'));
  }

  bool _looksLikeHtml(String header) {
    final lower = header.toLowerCase();
    return lower.startsWith('<!doctype html') ||
        lower.startsWith('<html') ||
        lower.contains('<html ') ||
        lower.contains('<body') ||
        lower.contains('<head');
  }

  bool _looksLikeMarkdown(String header) {
    return RegExp(r'^#{1,6}\s+\S', multiLine: true).hasMatch(header) ||
        RegExp(r'^```', multiLine: true).hasMatch(header) ||
        RegExp(r'\[[^\]]+\]\([^)]+\)').hasMatch(header);
  }

  bool _looksLikeText(List<int> bytes) {
    final sample = bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes;
    var controls = 0;
    for (final byte in sample) {
      if (byte == 0) return false;
      if (byte < 0x09 || (byte > 0x0D && byte < 0x20)) controls++;
    }
    return controls * 20 <= sample.length;
  }

  bool _isRar(List<int> bytes) {
    if (bytes.length < 7) return false;
    const signature = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07];
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return bytes[6] == 0x00 || bytes[6] == 0x01;
  }

  bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  bool _hasImageExtension(String name) {
    return name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif');
  }
}
