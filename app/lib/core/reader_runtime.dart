import 'package:flutter/widgets.dart';

import 'models.dart';

class DocumentRange {
  const DocumentRange({required this.start, required this.end});

  final Locator start;
  final Locator end;
}

abstract interface class ReaderDocument {
  DocumentMetadata get metadata;
  Future<List<TocItem>> getToc();
  Future<Locator> currentLocator();
  Future<void> goTo(Locator locator);
  Future<List<SearchResult>> search(String query);
  Future<String?> extractText(DocumentRange range);
  Stream<double> get progress;
}

abstract interface class ChapteredDocument implements ReaderDocument {
  int get chapterIndex;
  int get chapterCount;
  String get currentChapterText;
  bool get truncated;
  Locator locatorForProgress(double progress);
}

abstract interface class HtmlChapteredDocument implements ChapteredDocument {
  String get currentChapterHtml;
  String get currentChapterHref;
  String get currentChapterTitle;
}

abstract interface class DocumentRenderer {
  Widget build(BuildContext context);
  Future<void> open(ReaderDocument document);
  Future<void> goTo(Locator locator);
  Future<void> next();
  Future<void> previous();
  Future<void> dispose();
}

abstract interface class DocumentAdapter {
  String get id;
  Future<double> sniff(DocumentSource source);
  Future<ReaderDocument> open(DocumentSource source);
}

class TocItem {
  const TocItem({
    required this.title,
    required this.locator,
    this.children = const [],
  });
  final String title;
  final Locator locator;
  final List<TocItem> children;
}

class SearchResult {
  const SearchResult({
    required this.title,
    required this.excerpt,
    required this.locator,
  });
  final String title;
  final String excerpt;
  final Locator locator;
}

abstract interface class WebRendererBackend {
  Future<void> loadReader();
  Future<Object?> evaluate(String script);
  Stream<Object> get events;
  Future<void> dispose();
}
