import 'reader_runtime.dart';

class FoliateBridge {
  const FoliateBridge._();

  static const hostAsset = 'assets/reader/foliate/host.html';

  static Map<String, Object?> openChapter({
    required String href,
    required String html,
    required String title,
  }) {
    return {'type': 'openChapter', 'href': href, 'html': html, 'title': title};
  }

  static Map<String, Object?> openCurrent(HtmlChapteredDocument document) {
    return openChapter(
      href: document.currentChapterHref,
      html: document.currentChapterHtml,
      title: document.currentChapterTitle,
    );
  }
}
