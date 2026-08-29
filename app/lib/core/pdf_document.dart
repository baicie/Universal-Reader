import 'dart:convert';

import 'models.dart';
import 'reader_runtime.dart';

class PdfPageText {
  const PdfPageText({required this.page, required this.text});

  final int page;
  final String text;
}

class ParsedPdf {
  const ParsedPdf({required this.pages, required this.fullText});

  final List<PdfPageText> pages;
  final String fullText;
}

ParsedPdf parsePdf(List<int> bytes) {
  if (!_looksLikePdf(bytes)) {
    throw const FormatException('corrupt pdf');
  }
  final source = latin1.decode(bytes, allowInvalid: true);
  final pageCount = RegExp(r'/Type\s*/Page(?![s\w])').allMatches(source).length;
  final strings = [
    for (final match in RegExp(r'\((?:\\.|[^\\)])*\)\s*Tj').allMatches(source))
      _unescapePdfString(match.group(0)!),
  ].where((text) => text.trim().isNotEmpty).toList();
  if (pageCount == 0 || strings.isEmpty) {
    throw const FormatException('corrupt pdf');
  }
  final pages = <PdfPageText>[];
  if (strings.length == pageCount) {
    for (var i = 0; i < pageCount; i++) {
      pages.add(PdfPageText(page: i + 1, text: strings[i]));
    }
  } else {
    final perPage = (strings.length / pageCount).ceil();
    for (var i = 0; i < pageCount; i++) {
      final start = i * perPage;
      if (start >= strings.length) break;
      final end = (start + perPage).clamp(0, strings.length);
      pages.add(
        PdfPageText(page: i + 1, text: strings.sublist(start, end).join(' ')),
      );
    }
  }
  if (pages.isEmpty) {
    throw const FormatException('corrupt pdf');
  }
  return ParsedPdf(
    pages: pages,
    fullText: pages.map((page) => page.text).join('\n\n'),
  );
}

class PdfReaderDocument implements ChapteredDocument {
  PdfReaderDocument._({required this.metadata, required this.parsed});

  factory PdfReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    return PdfReaderDocument._(metadata: metadata, parsed: parsePdf(bytes));
  }

  @override
  final DocumentMetadata metadata;
  final ParsedPdf parsed;
  int pageIndex = 0;

  PdfPageText get currentPage =>
      parsed.pages[pageIndex.clamp(0, parsed.pages.length - 1)];

  @override
  int get chapterIndex => pageIndex;

  @override
  int get chapterCount => parsed.pages.length;

  @override
  String get currentChapterText => currentPage.text;

  @override
  bool get truncated => false;

  @override
  Locator locatorForProgress(double progress) {
    final index = (progress.clamp(0, 0.999) * parsed.pages.length).floor();
    return PdfLocator(page: parsed.pages[index].page);
  }

  @override
  Future<Locator> currentLocator() async => PdfLocator(page: currentPage.page);

  @override
  Future<String?> extractText(DocumentRange range) async {
    if (range.start is PdfLocator || range.end is PdfLocator) {
      final startPage = range.start is PdfLocator
          ? (range.start as PdfLocator).page
          : parsed.pages.first.page;
      final endPage = range.end is PdfLocator
          ? (range.end as PdfLocator).page
          : parsed.pages.last.page;
      return parsed.pages
          .where((page) => page.page >= startPage && page.page <= endPage)
          .map((page) => page.text)
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
      case PdfLocator(:final page):
        final index = parsed.pages.indexWhere((item) => item.page == page);
        if (index >= 0) pageIndex = index;
      case TextLocator(:final offset):
        var cursor = 0;
        for (var i = 0; i < parsed.pages.length; i++) {
          final next = cursor + parsed.pages[i].text.length + 2;
          if (offset < next || i == parsed.pages.length - 1) {
            pageIndex = i;
            break;
          }
          cursor = next;
        }
      default:
        break;
    }
  }

  @override
  Stream<double> get progress {
    return Stream<double>.value(
      parsed.pages.length <= 1 ? 0 : pageIndex / (parsed.pages.length - 1),
    );
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) return const [];
    return [
      for (final page in parsed.pages)
        if (page.text.contains(query))
          SearchResult(
            title: metadata.title,
            excerpt: query,
            locator: PdfLocator(page: page.page),
          ),
    ];
  }

  @override
  Future<List<TocItem>> getToc() async {
    return [
      for (final page in parsed.pages)
        TocItem(
          title: '${page.page}',
          locator: PdfLocator(page: page.page),
        ),
    ];
  }
}

bool _looksLikePdf(List<int> bytes) {
  var i = 0;
  while (i < bytes.length && bytes[i] <= 32) {
    i += 1;
  }
  const marker = [0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-
  if (i + marker.length > bytes.length) return false;
  for (var n = 0; n < marker.length; n++) {
    if (bytes[i + n] != marker[n]) return false;
  }
  return true;
}

String _unescapePdfString(String match) {
  final start = match.indexOf('(');
  final end = match.lastIndexOf(')');
  if (start < 0 || end <= start) return '';
  return match
      .substring(start + 1, end)
      .replaceAll('\\(', '(')
      .replaceAll('\\)', ')')
      .replaceAll('\\n', '\n')
      .replaceAll('\\r', '\r')
      .replaceAll('\\t', '\t')
      .replaceAll('\\\\', '\\');
}
