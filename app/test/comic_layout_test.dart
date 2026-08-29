import 'package:app/core/comic_document.dart';
import 'package:app/core/comic_layout.dart';
import 'package:app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';
import 'support/image_fixture.dart';

void main() {
  List<ComicPage> threePages() {
    final document = ComicReaderDocument.parse(
      metadata: const DocumentMetadata(
        id: 'comic-1',
        title: 'Pages',
        author: 'A',
        format: DocumentFormat.cbz,
        type: DocumentType.comic,
      ),
      bytes: zipNamedFiles({
        'page-01.png': tinyPngBytes(),
        'page-02.png': tinyPngBytes(),
        'page-03.png': tinyPngBytes(),
      }),
    );
    return document.pages;
  }

  test('double page pairs two images and leaves the last page alone', () {
    final pages = threePages();
    final first = comicSpread(
      pages: pages,
      pageIndex: 0,
      layout: ComicLayout.double,
      direction: ComicReadDirection.ltr,
    );
    expect(first.left?.name, 'page-01.png');
    expect(first.right?.name, 'page-02.png');

    final last = comicSpread(
      pages: pages,
      pageIndex: 2,
      layout: ComicLayout.double,
      direction: ComicReadDirection.ltr,
    );
    expect(last.left?.name, 'page-03.png');
    expect(last.right, isNull);
    expect(last.pageNames, ['page-03.png']);
  });

  test('rtl double puts the earlier page on the right', () {
    final pages = threePages();
    final first = comicSpread(
      pages: pages,
      pageIndex: 1,
      layout: ComicLayout.double,
      direction: ComicReadDirection.rtl,
    );
    expect(first.left?.name, 'page-02.png');
    expect(first.right?.name, 'page-01.png');

    final last = comicSpread(
      pages: pages,
      pageIndex: 2,
      layout: ComicLayout.double,
      direction: ComicReadDirection.rtl,
    );
    expect(last.left, isNull);
    expect(last.right?.name, 'page-03.png');
  });

  test('double page turn skips a spread and does not wrap to another book', () {
    expect(
      comicNextPageIndex(
        pageIndex: 0,
        pageCount: 3,
        layout: ComicLayout.double,
      ),
      2,
    );
    expect(
      comicNextPageIndex(
        pageIndex: 2,
        pageCount: 3,
        layout: ComicLayout.double,
      ),
      2,
    );
    expect(
      comicPreviousPageIndex(
        pageIndex: 2,
        pageCount: 3,
        layout: ComicLayout.double,
      ),
      0,
    );
  });

  test('vertical layout keeps one page per slot in file order', () {
    final pages = threePages();
    expect(comicSpreadCount(3, ComicLayout.vertical), 3);
    final middle = comicSpread(
      pages: pages,
      pageIndex: 1,
      layout: ComicLayout.vertical,
      direction: ComicReadDirection.rtl,
    );
    expect(middle.pageNames, ['page-02.png']);
  });

  test('ltr tap on the right advances; rtl tap on the left advances', () {
    expect(
      comicTapAction(90, 100, ComicReadDirection.ltr),
      ComicTapAction.next,
    );
    expect(
      comicTapAction(10, 100, ComicReadDirection.ltr),
      ComicTapAction.previous,
    );
    expect(
      comicTapAction(10, 100, ComicReadDirection.rtl),
      ComicTapAction.next,
    );
    expect(
      comicTapAction(50, 100, ComicReadDirection.ltr),
      ComicTapAction.chrome,
    );
  });

  test('unknown layout and direction fall back to single ltr', () {
    expect(parseComicLayout('wide'), ComicLayout.single);
    expect(parseComicReadDirection('vertical'), ComicReadDirection.ltr);
  });
}
