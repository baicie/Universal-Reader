import 'package:archive/archive.dart';

import 'cover_extract.dart';
import 'models.dart';
import 'reader_runtime.dart';

class ComicPage {
  const ComicPage({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

class ComicReaderDocument implements ChapteredDocument {
  ComicReaderDocument._({required this.metadata, required this.pages});

  factory ComicReaderDocument.parse({
    required DocumentMetadata metadata,
    required List<int> bytes,
  }) {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('corrupt comic');
    }
    final pages = <ComicPage>[];
    for (final file in archive) {
      if (!file.isFile || !looksLikeImageName(file.name)) continue;
      pages.add(
        ComicPage(
          name: file.name.replaceAll('\\', '/').split('/').last,
          bytes: List<int>.from(file.content as List<int>),
        ),
      );
    }
    pages.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (pages.isEmpty) {
      throw const FormatException('corrupt comic');
    }
    return ComicReaderDocument._(metadata: metadata, pages: pages);
  }

  @override
  final DocumentMetadata metadata;
  final List<ComicPage> pages;
  int pageIndex = 0;

  ComicPage get currentPage => pages[pageIndex.clamp(0, pages.length - 1)];

  @override
  int get chapterIndex => pageIndex;

  @override
  int get chapterCount => pages.length;

  @override
  String get currentChapterText => currentPage.name;

  @override
  bool get truncated => false;

  @override
  Locator locatorForProgress(double progress) {
    final index = (progress.clamp(0, 0.999) * pages.length).floor();
    return ComicLocator(page: index + 1);
  }

  @override
  Future<Locator> currentLocator() async => ComicLocator(page: pageIndex + 1);

  @override
  Future<String?> extractText(DocumentRange range) async => currentPage.name;

  @override
  Future<void> goTo(Locator locator) async {
    switch (locator) {
      case ComicLocator(:final page):
        pageIndex = (page - 1).clamp(0, pages.length - 1);
      case TextLocator(:final offset):
        pageIndex = offset.clamp(0, pages.length - 1);
      default:
        break;
    }
  }

  @override
  Stream<double> get progress => Stream<double>.value(
    pages.length <= 1 ? 0 : pageIndex / (pages.length - 1),
  );

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) return const [];
    return [
      for (final page in pages)
        if (page.name.toLowerCase().contains(query.toLowerCase()))
          SearchResult(
            title: page.name,
            excerpt: page.name,
            locator: ComicLocator(page: pages.indexOf(page) + 1),
          ),
    ];
  }

  @override
  Future<List<TocItem>> getToc() async {
    return [
      for (var i = 0; i < pages.length; i++)
        TocItem(
          title: pages[i].name,
          locator: ComicLocator(page: i + 1),
        ),
    ];
  }
}
