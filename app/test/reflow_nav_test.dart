import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/reflow_nav.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('next page stays in the chapter until the last page', () {
    expect(
      reflowNext(pageIndex: 0, pageCount: 3, chapterIndex: 0, chapterCount: 2),
      const ReflowTurnPage(1),
    );
    expect(
      reflowNext(pageIndex: 2, pageCount: 3, chapterIndex: 0, chapterCount: 2),
      const ReflowTurnChapter(1),
    );
  });

  test('next at the last page of the last chapter stays put', () {
    expect(
      reflowNext(pageIndex: 1, pageCount: 2, chapterIndex: 1, chapterCount: 2),
      const ReflowTurnStay(),
    );
  });

  test('previous page then previous chapter last page', () {
    expect(
      reflowPrevious(
        pageIndex: 2,
        pageCount: 3,
        chapterIndex: 1,
        chapterCount: 2,
      ),
      const ReflowTurnPage(1),
    );
    expect(
      reflowPrevious(
        pageIndex: 0,
        pageCount: 3,
        chapterIndex: 1,
        chapterCount: 2,
      ),
      const ReflowTurnChapter(0, lastPage: true),
    );
  });

  test('previous at the first page of the first chapter stays put', () {
    expect(
      reflowPrevious(
        pageIndex: 0,
        pageCount: 2,
        chapterIndex: 0,
        chapterCount: 2,
      ),
      const ReflowTurnStay(),
    );
  });

  test('tap right third is next and left third is previous', () {
    expect(reflowTapAction(10, 300), ReflowTapAction.previous);
    expect(reflowTapAction(290, 300), ReflowTapAction.next);
    expect(reflowTapAction(150, 300), ReflowTapAction.chrome);
  });

  test('progress maps to a chapter and a page inside it', () {
    expect(reflowChapterIndexForProgress(0, 2), 0);
    expect(reflowChapterIndexForProgress(0.49, 2), 0);
    expect(reflowChapterIndexForProgress(0.5, 2), 1);
    expect(reflowChapterIndexForProgress(1, 2), 1);
    expect(
      reflowPageIndexForProgress(
        progress: 0,
        chapterCount: 2,
        chapterIndex: 0,
        pageCount: 2,
      ),
      0,
    );
    expect(
      reflowPageIndexForProgress(
        progress: 0.25,
        chapterCount: 2,
        chapterIndex: 0,
        pageCount: 2,
      ),
      1,
    );
  });

  test('internal chapter href resolves against the current chapter', () {
    expect(
      reflowInternalHref(currentHref: 'OEBPS/ch1.xhtml', raw: 'ch2.xhtml'),
      'oebps/ch2.xhtml',
    );
    expect(
      reflowInternalHref(currentHref: 'OEBPS/ch1.xhtml', raw: '#note'),
      'OEBPS/ch1.xhtml',
    );
    expect(
      reflowInternalHref(
        currentHref: 'OEBPS/ch1.xhtml',
        raw: 'https://example.invalid/x',
      ),
      isNull,
    );
    expect(
      reflowInternalHref(currentHref: 'OEBPS/ch1.xhtml', raw: 'mailto:a@b.c'),
      isNull,
    );
  });

  test('href fragment is the id after hash and stays missing when absent', () {
    expect(reflowHrefFragment('#note'), 'note');
    expect(reflowHrefFragment('ch2.xhtml#fn-1'), 'fn-1');
    expect(reflowHrefFragment('ch2.xhtml'), isNull);
    expect(reflowHrefFragment('ch2.xhtml#'), isNull);
    expect(reflowSameHref('OEBPS/ch1.xhtml', 'oebps/ch1.xhtml'), isTrue);
    expect(reflowSameHref('OEBPS/ch1.xhtml', 'oebps/ch2.xhtml'), isFalse);
  });

  test('scroll quote is the trimmed query and stays missing when empty', () {
    expect(reflowScrollQuote('  hello  '), 'hello');
    expect(reflowScrollQuote(''), isNull);
    expect(reflowScrollQuote('   '), isNull);
  });

  test('chrome pages are one-based and stay missing without a page count', () {
    expect(
      reflowChromePages(pageIndex: 0, pageCount: 3),
      const ReflowChromePages(current: 1, total: 3),
    );
    expect(
      reflowChromePages(pageIndex: 2, pageCount: 3),
      const ReflowChromePages(current: 3, total: 3),
    );
    expect(reflowChromePages(pageIndex: 0, pageCount: 0), isNull);
    expect(reflowChromePages(pageIndex: null, pageCount: null), isNull);
  });

  test('toc current follows href and fragment not the top-level index', () {
    const parent = TocItem(
      title: 'Part I',
      locator: EpubLocator(href: 'section-0'),
      children: [
        TocItem(
          title: 'Chapter One',
          locator: EpubLocator(href: 'section-1'),
        ),
      ],
    );
    expect(reflowTocItemCurrent(parent, href: 'section-0'), isTrue);
    expect(
      reflowTocItemCurrent(parent.children.single, href: 'section-0'),
      isFalse,
    );
    expect(reflowTocItemCurrent(parent, href: 'section-1'), isFalse);
    expect(
      reflowTocItemCurrent(parent.children.single, href: 'section-1'),
      isTrue,
    );
  });

  test('toc current on a shared href prefers the fragment', () {
    const chapter = TocItem(
      title: '第一章',
      locator: EpubLocator(href: 'OEBPS/ch1.xhtml'),
      children: [
        TocItem(
          title: '注释',
          locator: EpubLocator(href: 'OEBPS/ch1.xhtml', fragment: 'note'),
        ),
      ],
    );
    expect(reflowTocItemCurrent(chapter, href: 'OEBPS/ch1.xhtml'), isTrue);
    expect(
      reflowTocItemCurrent(chapter.children.single, href: 'OEBPS/ch1.xhtml'),
      isFalse,
    );
    expect(
      reflowTocItemCurrent(chapter, href: 'OEBPS/ch1.xhtml', fragment: 'note'),
      isFalse,
    );
    expect(
      reflowTocItemCurrent(
        chapter.children.single,
        href: 'OEBPS/ch1.xhtml',
        fragment: 'note',
      ),
      isTrue,
    );
  });
}
