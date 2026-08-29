import 'foliate_session.dart';
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
    return openSession(FoliateSession.open(document));
  }

  static Map<String, Object?> openSession(FoliateSession session) {
    return {
      'type': 'open',
      'href': session.href,
      'html': session.currentPageHtml,
      'title': session.title,
      'cfi': session.currentCfi,
      'progression': session.progression,
      'pageIndex': session.pageIndex,
      'pageCount': session.pageCount,
    };
  }
}
