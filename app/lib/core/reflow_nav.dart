import 'models.dart';
import 'reader_runtime.dart';

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

const _externalSchemes = {
  'http',
  'https',
  'mailto',
  'javascript',
  'file',
  'data',
  'blob',
};

String? reflowInternalHref({required String currentHref, required String raw}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.startsWith('//')) return null;
  final colon = trimmed.indexOf(':');
  if (colon > 0) {
    final scheme = trimmed.substring(0, colon).toLowerCase();
    if (_externalSchemes.contains(scheme)) return null;
  }
  if (trimmed.startsWith('#')) return currentHref;
  return _resolveReflowHref(currentHref, trimmed);
}

String? reflowHrefFragment(String raw) {
  final trimmed = raw.trim();
  final hash = trimmed.indexOf('#');
  if (hash < 0 || hash == trimmed.length - 1) return null;
  final fragment = trimmed.substring(hash + 1);
  if (fragment.isEmpty) return null;
  try {
    return Uri.decodeFull(fragment);
  } on FormatException {
    return fragment;
  }
}

bool reflowSameHref(String left, String right) {
  return _normalizeReflowPath(left) == _normalizeReflowPath(right);
}

bool reflowTocItemCurrent(
  TocItem item, {
  required String href,
  String? fragment,
}) {
  final locator = item.locator;
  if (locator is! EpubLocator) return false;
  if (!reflowSameHref(href, locator.href)) return false;
  final itemFragment = locator.fragment ?? '';
  final currentFragment = fragment ?? '';
  if (currentFragment.isEmpty) return itemFragment.isEmpty;
  return itemFragment == currentFragment;
}

String? reflowScrollQuote(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class ReflowChromePages {
  const ReflowChromePages({required this.current, required this.total});

  final int current;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is ReflowChromePages &&
      other.current == current &&
      other.total == total;

  @override
  int get hashCode => Object.hash(current, total);
}

ReflowChromePages? reflowChromePages({int? pageIndex, int? pageCount}) {
  final count = pageCount ?? 0;
  if (count <= 0) return null;
  final index = (pageIndex ?? 0).clamp(0, count - 1);
  return ReflowChromePages(current: index + 1, total: count);
}

String _resolveReflowHref(String basePath, String href) {
  final cleaned = href.split('#').first.replaceAll('\\', '/');
  var decoded = cleaned;
  try {
    decoded = Uri.decodeFull(cleaned);
  } on FormatException {
    decoded = cleaned;
  }
  final slash = basePath.replaceAll('\\', '/').lastIndexOf('/');
  final dir = slash < 0 ? '' : basePath.substring(0, slash + 1);
  return _normalizeReflowPath(
    decoded.startsWith('/') ? decoded : '$dir$decoded',
  );
}

String _normalizeReflowPath(String path) {
  final parts = <String>[];
  for (final part in path.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(part);
  }
  return parts.join('/').toLowerCase();
}
