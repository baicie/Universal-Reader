import '../../core/models.dart';
import '../../core/reader_runtime.dart';

class SampleReaderDocument implements ReaderDocument {
  SampleReaderDocument({
    required this.metadata,
    this.body = defaultBody,
    this.chapterHref = 'chapter-4',
    this.chapterProgress = 0.37,
  });

  static const defaultBody =
      '白是一种包容所有颜色的颜色。它没有自己的主张，却能让其他事物显现出清晰的轮廓。在设计中，空白从来不是缺席，而是一种主动的表达。\n'
      '我们习惯于把信息填满，把空间占据，把每一个空隙都看作需要解决的问题。但真正成熟的设计，知道什么时候应该停下来，让事物自己说话。\n'
      '阅读是一种与留白相处的方式。文字之间的距离、章节之间的停顿，以及读者暂时离开页面的片刻，共同构成了完整的体验。';

  @override
  final DocumentMetadata metadata;
  final String body;
  final String chapterHref;
  final double chapterProgress;

  @override
  Future<Locator> currentLocator() async {
    return EpubLocator(href: chapterHref, progression: chapterProgress);
  }

  @override
  Future<String?> extractText(DocumentRange range) async => body;

  @override
  Future<void> goTo(Locator locator) async {}

  @override
  Stream<double> get progress => Stream<double>.value(chapterProgress);

  @override
  Future<List<SearchResult>> search(String query) async {
    if (!body.contains(query)) return const [];
    return [
      SearchResult(
        title: metadata.title,
        excerpt: body,
        locator: await currentLocator(),
      ),
    ];
  }

  @override
  Future<List<TocItem>> getToc() async {
    return [
      TocItem(
        title: '第 4 章 白',
        locator: EpubLocator(href: chapterHref, progression: chapterProgress),
      ),
    ];
  }
}
