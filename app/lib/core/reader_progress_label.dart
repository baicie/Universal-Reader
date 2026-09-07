import 'reader_runtime.dart';
import 'reader_state.dart';
import 'reflow_nav.dart';
import '../l10n/l10n.dart';

/// Pure helper that formats the bottom progress strip for `ReaderBottomOverlay`.
///
/// Extracted so the rendering branches can be unit tested without spinning up
/// a widget tree. Reads only from the immutable [runtime] snapshot.
String readerProgressLabel({
  required ReaderRuntime runtime,
  required AppLocalizations l10n,
  required String formatLabel,
  required int currentIndex,
}) {
  final chaptered = runtime.opened is ChapteredDocument
      ? runtime.opened as ChapteredDocument
      : null;
  final chapterCount = chaptered?.chapterCount ?? runtime.tocItems.length;
  if (runtime.tocItems.isNotEmpty &&
      chapterCount > 0 &&
      runtime.tocItems.length != chapterCount) {
    final index = (chaptered?.chapterIndex ?? currentIndex).clamp(
      0,
      chapterCount - 1,
    );
    return l10n.readerSection(index + 1, chapterCount);
  }
  final pages = reflowChromePages(
    pageIndex: runtime.foliateSession?.pageIndex,
    pageCount: runtime.foliateSession?.pageCount,
  );
  if (pages != null) {
    return l10n.readerSection(pages.current, pages.total);
  }
  if (runtime.tocItems.isEmpty) return formatLabel;
  return l10n.readerSection(currentIndex + 1, runtime.tocItems.length);
}
