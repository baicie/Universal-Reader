import 'models.dart';
import 'reader_runtime.dart';
import 'text_document.dart';

/// State of the reader's main text body. Drives which copy / icon the
/// plain-text fallback renders and which locator data is needed.
class ReaderChapterState {
  const ReaderChapterState._(this.kind, this.truncated, this.missingFile,
      this.formatLabel);

  const ReaderChapterState.loading()
      : this._(ReaderChapterKind.loading, false, false, '');

  const ReaderChapterState.corrupt()
      : this._(ReaderChapterKind.corrupt, false, false, '');

  const ReaderChapterState.unavailable({
    required bool missingFile,
    required String formatLabel,
  }) : this._(
            ReaderChapterKind.unavailable,
            false,
            missingFile,
            formatLabel,
          );

  const ReaderChapterState.ready({required bool truncated})
      : this._(ReaderChapterKind.ready, truncated, false, '');

  final ReaderChapterKind kind;
  final bool truncated;
  final bool missingFile;
  final String formatLabel;
}

enum ReaderChapterKind { loading, corrupt, unavailable, ready }

/// Resolve which chapter-state to render, in priority order:
/// loading → corrupt → unavailable → ready.
///
/// [loading] short-circuits the other signals — the reader always shows the
/// spinner while work is in-flight, even if an earlier opener produced a
/// corrupt / unavailable result.
///
/// [isTruncated] is the only signal that reaches the [ReaderChapterKind.ready]
/// branch; the other branches ignore it because they show their own copy.
ReaderChapterState resolveReaderChapterState({
  required bool loading,
  required ReaderDocument? opened,
  required LibraryDocument? document,
  required bool isTruncated,
}) {
  if (loading) {
    return const ReaderChapterState.loading();
  }
  if (opened is CorruptReaderDocument) {
    return const ReaderChapterState.corrupt();
  }
  if (opened is UnavailableReaderDocument) {
    final format = document?.metadata.format;
    final missingFile =
        document == null || (format?.isReaderEngineFormat ?? false);
    return ReaderChapterState.unavailable(
      missingFile: missingFile,
      formatLabel: document?.metadata.format.label ?? '',
    );
  }
  return ReaderChapterState.ready(truncated: isTruncated);
}
