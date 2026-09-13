import 'reader_runtime.dart';
import 'reader_text.dart';
import '../l10n/l10n.dart';

/// Derived read-only values that the reader page computes from its state +
/// library on every build. Pulling these out of the build method keeps
/// build focused on layout and avoids nested ternaries.
class ReaderDerived {
  const ReaderDerived({
    required this.currentIndex,
    required this.chapterCount,
    required this.currentHref,
    required this.currentTitle,
    required this.heading,
    required this.paragraphs,
  });

  final int currentIndex;
  final int chapterCount;
  final String currentHref;
  final String currentTitle;
  final String heading;
  final List<String> paragraphs;

  static ReaderDerived build({
    required ReaderDocument? opened,
    required List<TocItem> tocItems,
    required String body,
    required AppLocalizations l10n,
  }) {
    final currentIndex = opened is ChapteredDocument ? opened.chapterIndex : 0;
    final chapterCount = opened is ChapteredDocument
        ? opened.chapterCount
        : tocItems.length;
    final currentHref = opened is HtmlChapteredDocument
        ? opened.currentChapterHref
        : '';
    final currentTitle = opened is HtmlChapteredDocument
        ? opened.currentChapterTitle
        : tocItems.isEmpty
        ? ''
        : tocItems[currentIndex.clamp(0, tocItems.length - 1)].title;
    final heading = currentTitle.trim().isEmpty
        ? l10n.untitledSection
        : currentTitle;
    final paragraphs = splitTextParagraphs(body);
    return ReaderDerived(
      currentIndex: currentIndex,
      chapterCount: chapterCount,
      currentHref: currentHref,
      currentTitle: currentTitle,
      heading: heading,
      paragraphs: paragraphs,
    );
  }
}
