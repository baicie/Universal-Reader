import 'comic_document.dart';

enum ComicLayout { single, double, vertical }

enum ComicReadDirection { ltr, rtl }

enum ComicTapAction { next, previous, chrome }

class ComicSpread {
  const ComicSpread({this.left, this.right});

  final ComicPage? left;
  final ComicPage? right;

  List<String> get pageNames => [
    if (left != null) left!.name,
    if (right != null) right!.name,
  ];
}

ComicLayout parseComicLayout(String? raw) {
  return switch (raw) {
    'double' => ComicLayout.double,
    'vertical' => ComicLayout.vertical,
    _ => ComicLayout.single,
  };
}

ComicReadDirection parseComicReadDirection(String? raw) {
  return raw == 'rtl' ? ComicReadDirection.rtl : ComicReadDirection.ltr;
}

int comicSpreadCount(int pageCount, ComicLayout layout) {
  if (pageCount <= 0) return 0;
  if (layout == ComicLayout.double) return (pageCount + 1) ~/ 2;
  return pageCount;
}

ComicSpread comicSpread({
  required List<ComicPage> pages,
  required int pageIndex,
  required ComicLayout layout,
  required ComicReadDirection direction,
}) {
  if (pages.isEmpty) return const ComicSpread();
  final index = pageIndex.clamp(0, pages.length - 1);
  if (layout != ComicLayout.double) {
    return ComicSpread(left: pages[index]);
  }
  final start = (index ~/ 2) * 2;
  final first = pages[start];
  final second = start + 1 < pages.length ? pages[start + 1] : null;
  if (direction == ComicReadDirection.ltr) {
    return ComicSpread(left: first, right: second);
  }
  return ComicSpread(left: second, right: first);
}

int comicNextPageIndex({
  required int pageIndex,
  required int pageCount,
  required ComicLayout layout,
}) {
  if (pageCount <= 0) return 0;
  if (layout == ComicLayout.double) {
    final next = ((pageIndex ~/ 2) + 1) * 2;
    if (next >= pageCount) return pageCount - 1;
    return next;
  }
  if (pageIndex >= pageCount - 1) return pageCount - 1;
  return pageIndex + 1;
}

int comicPreviousPageIndex({
  required int pageIndex,
  required int pageCount,
  required ComicLayout layout,
}) {
  if (pageCount <= 0) return 0;
  if (layout == ComicLayout.double) {
    final prev = ((pageIndex ~/ 2) - 1) * 2;
    return prev < 0 ? 0 : prev;
  }
  return pageIndex <= 0 ? 0 : pageIndex - 1;
}

ComicTapAction comicTapAction(
  double x,
  double width,
  ComicReadDirection direction,
) {
  if (width <= 0) return ComicTapAction.chrome;
  final t = x / width;
  if (t < 1 / 3) {
    return direction == ComicReadDirection.rtl
        ? ComicTapAction.next
        : ComicTapAction.previous;
  }
  if (t > 2 / 3) {
    return direction == ComicReadDirection.rtl
        ? ComicTapAction.previous
        : ComicTapAction.next;
  }
  return ComicTapAction.chrome;
}
