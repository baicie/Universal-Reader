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
}
