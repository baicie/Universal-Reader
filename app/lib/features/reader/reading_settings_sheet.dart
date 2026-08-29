import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/reader_prefs.dart';
import '../../l10n/l10n.dart';

class ReadingSettingsSheet extends ConsumerWidget {
  const ReadingSettingsSheet({
    this.showComicLayout = false,
    this.showPdfZoom = false,
    super.key,
  });

  final bool showComicLayout;
  final bool showPdfZoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(readerPrefsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.readingSettings,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.bodyFontSize),
            Slider(
              min: ReaderPrefsController.minFontSize,
              max: ReaderPrefsController.maxFontSize,
              divisions:
                  (ReaderPrefsController.maxFontSize -
                          ReaderPrefsController.minFontSize)
                      .round(),
              value: prefs.fontSize,
              label: prefs.fontSize.round().toString(),
              onChanged: (value) {
                ref.read(readerPrefsProvider).setFontSize(value);
              },
            ),
            Text(l10n.bodyLineHeight),
            Slider(
              min: ReaderPrefsController.minLineHeight,
              max: ReaderPrefsController.maxLineHeight,
              divisions:
                  ((ReaderPrefsController.maxLineHeight -
                              ReaderPrefsController.minLineHeight) *
                          10)
                      .round(),
              value: prefs.lineHeight,
              label: prefs.lineHeight.toStringAsFixed(1),
              onChanged: (value) {
                ref.read(readerPrefsProvider).setLineHeight(value);
              },
            ),
            Text(l10n.bodyFontFamily),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in [
                  (ReaderFontFamily.serif, l10n.fontSerif),
                  (ReaderFontFamily.sans, l10n.fontSans),
                  (ReaderFontFamily.mono, l10n.fontMono),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: prefs.fontFamily == option.$1,
                    onSelected: (_) {
                      ref.read(readerPrefsProvider).setFontFamily(option.$1);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.readingPaper),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in [
                  (ReaderPaper.followApp, l10n.readingPaperFollow),
                  (ReaderPaper.light, l10n.themeLight),
                  (ReaderPaper.dark, l10n.themeDark),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: prefs.paper == option.$1,
                    onSelected: (_) {
                      ref.read(readerPrefsProvider).setPaper(option.$1);
                    },
                  ),
              ],
            ),
            if (showPdfZoom) ...[
              const SizedBox(height: 16),
              Text(l10n.pdfZoom),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final zoom in ReaderPrefsController.pdfZoomStops)
                    ChoiceChip(
                      label: Text('${(zoom * 100).round()}%'),
                      selected: prefs.pdfZoom == zoom,
                      onSelected: (_) {
                        ref.read(readerPrefsProvider).setPdfZoom(zoom);
                      },
                    ),
                ],
              ),
            ],
            if (showComicLayout) ...[
              const SizedBox(height: 16),
              Text(l10n.comicLayout),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in [
                    (ComicLayout.single, l10n.comicLayoutSingle),
                    (ComicLayout.double, l10n.comicLayoutDouble),
                    (ComicLayout.vertical, l10n.comicLayoutVertical),
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: prefs.comicLayout == option.$1,
                      onSelected: (_) {
                        ref.read(readerPrefsProvider).setComicLayout(option.$1);
                      },
                    ),
                  FilterChip(
                    label: Text(l10n.comicReadRtl),
                    selected: prefs.comicDirection == ComicReadDirection.rtl,
                    onSelected: (selected) {
                      ref
                          .read(readerPrefsProvider)
                          .setComicDirection(
                            selected
                                ? ComicReadDirection.rtl
                                : ComicReadDirection.ltr,
                          );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
