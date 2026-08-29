enum ReflowTapAction { next, previous, chrome }

sealed class ReflowTurn {
  const ReflowTurn();
}

class ReflowTurnStay extends ReflowTurn {
  const ReflowTurnStay();

  @override
  bool operator ==(Object other) => other is ReflowTurnStay;

  @override
  int get hashCode => 0;
}

class ReflowTurnPage extends ReflowTurn {
  const ReflowTurnPage(this.pageIndex);

  final int pageIndex;

  @override
  bool operator ==(Object other) =>
      other is ReflowTurnPage && other.pageIndex == pageIndex;

  @override
  int get hashCode => pageIndex.hashCode;
}

class ReflowTurnChapter extends ReflowTurn {
  const ReflowTurnChapter(this.chapterIndex, {this.lastPage = false});

  final int chapterIndex;
  final bool lastPage;

  @override
  bool operator ==(Object other) =>
      other is ReflowTurnChapter &&
      other.chapterIndex == chapterIndex &&
      other.lastPage == lastPage;

  @override
  int get hashCode => Object.hash(chapterIndex, lastPage);
}

ReflowTurn reflowNext({
  required int pageIndex,
  required int pageCount,
  required int chapterIndex,
  required int chapterCount,
}) {
  if (pageCount > 0 && pageIndex < pageCount - 1) {
    return ReflowTurnPage(pageIndex + 1);
  }
  if (chapterIndex < chapterCount - 1) {
    return ReflowTurnChapter(chapterIndex + 1);
  }
  return const ReflowTurnStay();
}

ReflowTurn reflowPrevious({
  required int pageIndex,
  required int pageCount,
  required int chapterIndex,
  required int chapterCount,
}) {
  if (pageIndex > 0) {
    return ReflowTurnPage(pageIndex - 1);
  }
  if (chapterIndex > 0) {
    return ReflowTurnChapter(chapterIndex - 1, lastPage: true);
  }
  return const ReflowTurnStay();
}

ReflowTapAction reflowTapAction(double x, double width) {
  if (width <= 0) return ReflowTapAction.chrome;
  final t = x / width;
  if (t < 1 / 3) return ReflowTapAction.previous;
  if (t > 2 / 3) return ReflowTapAction.next;
  return ReflowTapAction.chrome;
}

int reflowChapterIndexForProgress(double progress, int chapterCount) {
  if (chapterCount <= 0) return 0;
  return (progress.clamp(0.0, 0.999) * chapterCount).floor().clamp(
    0,
    chapterCount - 1,
  );
}

int reflowPageIndexForProgress({
  required double progress,
  required int chapterCount,
  required int chapterIndex,
  required int pageCount,
}) {
  if (pageCount <= 0 || chapterCount <= 0) return 0;
  final local = (progress.clamp(0.0, 0.999) * chapterCount) - chapterIndex;
  return (local * pageCount).floor().clamp(0, pageCount - 1);
}
