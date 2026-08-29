import 'reader_runtime.dart';

class FoliatePage {
  const FoliatePage({
    required this.html,
    required this.startOffset,
    required this.endOffset,
  });

  final String html;
  final int startOffset;
  final int endOffset;
}

class FoliateSelection {
  const FoliateSelection({required this.quote, required this.cfi});

  final String quote;
  final String cfi;
}

class FoliateSession {
  FoliateSession._({
    required this.href,
    required this.title,
    required this.pages,
    required this.chapterHtml,
  });

  factory FoliateSession.open(
    HtmlChapteredDocument document, {
    int pageCharLimit = 1800,
  }) {
    final pages = paginateReflow(
      text: document.currentChapterText,
      html: document.currentChapterHtml,
      pageCharLimit: pageCharLimit,
    );
    return FoliateSession._(
      href: document.currentChapterHref,
      title: document.currentChapterTitle,
      pages: pages,
      chapterHtml: document.currentChapterHtml,
    );
  }

  final String href;
  final String title;
  final List<FoliatePage> pages;
  final String chapterHtml;
  int pageIndex = 0;

  int get pageCount => pages.length;

  FoliatePage get currentPage => pages[pageIndex.clamp(0, pages.length - 1)];

  String get currentPageHtml => currentPage.html;

  String get visualHtml =>
      chapterHtml.isNotEmpty ? chapterHtml : currentPageHtml;

  String get currentCfi => 'epubcfi($href:${currentPage.startOffset})';

  double get progression => pageCount <= 1 ? 0 : pageIndex / (pageCount - 1);

  bool next() {
    if (pageIndex >= pageCount - 1) return false;
    pageIndex += 1;
    return true;
  }

  bool previous() {
    if (pageIndex <= 0) return false;
    pageIndex -= 1;
    return true;
  }

  bool goToCfi(String cfi) {
    final offset = _offsetFromCfi(cfi);
    if (offset == null) return false;
    final index = pages.lastIndexWhere((page) => page.startOffset <= offset);
    pageIndex = index < 0 ? 0 : index;
    return true;
  }

  void goToPage(int index) {
    if (pages.isEmpty) {
      pageIndex = 0;
      return;
    }
    pageIndex = index.clamp(0, pages.length - 1);
  }

  void goToLastPage() {
    goToPage(pageCount - 1);
  }

  FoliateSelection? selectionFromEvent(Object? raw) {
    if (raw is! Map) return null;
    if (raw['type'] != 'selection') return null;
    final quote = (raw['text'] as String?)?.trim() ?? '';
    if (quote.isEmpty) return null;
    final cfi = raw['cfi'] as String? ?? currentCfi;
    return FoliateSelection(quote: quote, cfi: cfi);
  }
}

List<FoliatePage> paginateReflow({
  required String text,
  required String html,
  required int pageCharLimit,
}) {
  if (text.isEmpty) {
    return [
      FoliatePage(
        html: html.isEmpty ? '<p></p>' : html,
        startOffset: 0,
        endOffset: 0,
      ),
    ];
  }
  if (text.length <= pageCharLimit) {
    return [
      FoliatePage(
        html: html.isEmpty ? _paragraph(text) : html,
        startOffset: 0,
        endOffset: text.length,
      ),
    ];
  }
  final pages = <FoliatePage>[];
  var start = 0;
  while (start < text.length) {
    var end = start + pageCharLimit;
    if (end >= text.length) {
      end = text.length;
    } else {
      var breakAt = end;
      while (breakAt > start) {
        final code = text.codeUnitAt(breakAt - 1);
        if (code == 0x20 || code == 0x0a || code == 0x09 || code == 0x0d) {
          break;
        }
        breakAt -= 1;
      }
      if (breakAt > start) end = breakAt;
    }
    final slice = text.substring(start, end).trim();
    pages.add(
      FoliatePage(html: _paragraph(slice), startOffset: start, endOffset: end),
    );
    start = end;
  }
  return pages.isEmpty
      ? [
          FoliatePage(
            html: _paragraph(text),
            startOffset: 0,
            endOffset: text.length,
          ),
        ]
      : pages;
}

String _paragraph(String text) {
  final escaped = text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return '<p>$escaped</p>';
}

int? _offsetFromCfi(String cfi) {
  final match = RegExp(r':(\d+)\)?$').firstMatch(cfi);
  return match == null ? null : int.tryParse(match.group(1)!);
}
