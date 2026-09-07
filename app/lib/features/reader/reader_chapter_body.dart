import 'package:flutter/material.dart';

import '../../core/reader_chapter_state.dart';
import '../../core/reading_surface.dart';
import '../../l10n/l10n.dart';

export '../../core/reader_chapter_state.dart' show
    ReaderChapterState,
    ReaderChapterKind;

/// Renders the body of a plain-text reader chapter, switching between
/// loading / corrupt / unavailable / ready states.
///
/// When [state] is ready, [child] owns the body content; this widget still
/// draws the section label, optional heading and truncated notice.
class ReaderChapterBody extends StatelessWidget {
  const ReaderChapterBody({
    super.key,
    required this.state,
    required this.surface,
    required this.surfaceColor,
    required this.mutedColor,
    required this.heading,
    required this.showHeading,
    required this.hasToc,
    required this.currentIndex,
    required this.chapterCount,
    required this.formatLabel,
    required this.child,
  });

  final ReaderChapterState state;
  final ReadingSurface surface;
  final Color surfaceColor;
  final Color mutedColor;
  final String heading;
  final bool showHeading;
  final bool hasToc;
  final int currentIndex;
  final int chapterCount;
  final String formatLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ink = surfaceColor;
    final muted = mutedColor;
    final fontSize = surface.fontSize;
    final bodyStyle = TextStyle(
      color: ink,
      fontSize: fontSize,
      height: surface.lineHeight,
      fontFamily: surface.flutterFontFamily,
    );
    switch (state.kind) {
      case ReaderChapterKind.loading:
        return Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.readerLoading, style: TextStyle(color: muted)),
            ],
          ),
        );
      case ReaderChapterKind.corrupt:
        return Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(l10n.readerCorruptFile, style: bodyStyle),
        );
      case ReaderChapterKind.unavailable:
        return Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            state.missingFile
                ? l10n.readerMissingFile
                : l10n.readerUnavailable(state.formatLabel),
            style: bodyStyle,
          ),
        );
      case ReaderChapterKind.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasToc
                  ? l10n.readerSection(
                      currentIndex + 1,
                      chapterCount <= 0 ? 1 : chapterCount,
                    )
                  : formatLabel,
              style: TextStyle(
                color: muted,
                letterSpacing: 2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (showHeading) ...[
              Text(
                heading,
                style: TextStyle(
                  color: ink,
                  fontSize: fontSize * 2,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  fontFamily: surface.flutterFontFamily,
                ),
              ),
              const SizedBox(height: 28),
            ],
            if (state.truncated) ...[
              Text(
                l10n.readerTruncated,
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 22),
            ],
            child,
          ],
        );
    }
  }
}
