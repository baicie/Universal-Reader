import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/reader_prefs.dart';
import '../../core/reader_runtime.dart';
import '../../core/text_document.dart';
import '../../l10n/l10n.dart';
import '../../widgets/eyebrow.dart';
import '../tools/reader_ai_panel.dart';
import '../tools/sample_reader_document.dart';
import 'open_reader.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  bool chrome = true;
  bool toc = false;
  bool ask = false;
  late double progress;
  bool loading = true;
  ReaderDocument? opened;
  List<TocItem> tocItems = const [];
  String body = '';

  @override
  void initState() {
    super.initState();
    progress =
        ref
            .read(libraryProvider)
            .documentById(widget.id)
            ?.readingState
            .progress ??
        0;
    Future.microtask(_open);
  }

  Future<void> _open() async {
    final library = ref.read(libraryProvider);
    await library.waitUntilReady();
    if (!mounted) return;
    final document = library.documentById(widget.id);
    if (document == null) {
      setState(() {
        opened = UnavailableReaderDocument(
          metadata: DocumentMetadata(
            id: widget.id,
            title: widget.id,
            author: '',
            format: DocumentFormat.unknown,
            type: DocumentType.reflow,
          ),
        );
        loading = false;
      });
      return;
    }
    final bytes = await library.readFile(widget.id);
    if (!mounted) return;
    final reader = openReaderDocument(
      metadata: document.metadata,
      bytes: bytes,
    );
    if (reader is TextReaderDocument && progress > 0) {
      await reader.goTo(
        TextLocator(offset: (progress * reader.parsed.fullText.length).round()),
      );
    }
    final items = await reader.getToc();
    if (!mounted) return;
    setState(() {
      opened = reader;
      tocItems = items;
      body = _bodyFor(reader);
      loading = false;
    });
  }

  String _bodyFor(ReaderDocument reader) {
    if (reader is TextReaderDocument) return reader.currentSection.body;
    if (reader is SampleReaderDocument) return reader.body;
    return '';
  }

  Future<void> _goTo(TocItem item) async {
    final reader = opened;
    if (reader == null) return;
    await reader.goTo(item.locator);
    if (!mounted) return;
    setState(() {
      body = _bodyFor(reader);
      if (reader is TextReaderDocument) {
        final length = reader.parsed.fullText.isEmpty
            ? 1
            : reader.parsed.fullText.length;
        progress = reader.currentSection.startOffset / length;
        ref.read(libraryProvider).updateProgress(widget.id, progress);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final fontSize = ref.watch(readerPrefsProvider).fontSize;
    final document = ref.watch(libraryProvider).documentById(widget.id);
    final dark = theme.brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF1C1B18) : const Color(0xFFF5F0E8);
    final ink = dark ? const Color(0xFFE8E2D6) : const Color(0xFF2A2620);
    final muted = dark ? const Color(0xFFB7A894) : const Color(0xFF8A7358);
    final tocBg = dark ? const Color(0xFF24231F) : const Color(0xFFF0EADF);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final currentIndex = opened is TextReaderDocument
        ? (opened as TextReaderDocument).sectionIndex
        : 0;
    final currentTitle = tocItems.isEmpty
        ? ''
        : tocItems[currentIndex.clamp(0, tocItems.length - 1)].title;
    final heading = currentTitle.trim().isEmpty
        ? l10n.untitledSection
        : currentTitle;
    final paragraphs = body
        .split(RegExp(r'\n+'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
    final title = document?.metadata.title ?? widget.id;
    final formatLabel = document?.metadata.format.label ?? '';

    return Scaffold(
      backgroundColor: paper,
      appBar: chrome
          ? AppBar(
              backgroundColor: paper,
              foregroundColor: ink,
              leading: IconButton(
                tooltip: l10n.backToLibrary,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: l10n.askThisPage,
                  icon: Icon(
                    ask ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    color: ask ? accent : ink,
                  ),
                  onPressed: () => setState(() {
                    ask = !ask;
                    chrome = true;
                  }),
                ),
                IconButton(
                  tooltip: l10n.tableOfContents,
                  icon: Icon(
                    toc ? Icons.menu_book : Icons.menu_book_outlined,
                    color: toc ? accent : ink,
                  ),
                  onPressed: () => setState(() => toc = !toc),
                ),
                IconButton(
                  tooltip: l10n.readingSettings,
                  icon: const Icon(Icons.text_fields),
                  onPressed: _openReadingSettings,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => chrome = !chrome),
        child: Stack(
          children: [
            Row(
              children: [
                if (toc)
                  Material(
                    color: tocBg,
                    child: GestureDetector(
                      onTap: () {},
                      child: SizedBox(
                        width: 240,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 16, 24),
                          children: [
                            Eyebrow(l10n.tableOfContents),
                            const SizedBox(height: 12),
                            if (tocItems.isEmpty)
                              Text(
                                l10n.untitledSection,
                                style: TextStyle(color: muted, height: 1.4),
                              ),
                            for (var i = 0; i < tocItems.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: InkWell(
                                  onTap: () => _goTo(tocItems[i]),
                                  child: Text(
                                    tocItems[i].title.trim().isEmpty
                                        ? l10n.untitledSection
                                        : tocItems[i].title,
                                    style: TextStyle(
                                      fontWeight: i == currentIndex
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: i == currentIndex ? accent : ink,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          chrome ? 32 : 48,
                          28,
                          chrome ? 112 : 48,
                        ),
                        child: _readerBody(
                          l10n: l10n,
                          document: document,
                          ink: ink,
                          muted: muted,
                          heading: heading,
                          showHeading: currentTitle.trim().isNotEmpty,
                          paragraphs: paragraphs,
                          currentIndex: currentIndex,
                          fontSize: fontSize,
                          formatLabel: formatLabel,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (ask && opened != null)
              Positioned(
                top: wide ? 0 : null,
                left: wide ? null : 0,
                right: 0,
                bottom: chrome ? 72 : 0,
                width: wide ? 320 : null,
                height: wide ? null : MediaQuery.sizeOf(context).height * 0.45,
                child: ReaderAiPanel(
                  document: opened!,
                  settings: ref.watch(aiSettingsProvider).settings,
                ),
              ),
            if (chrome)
              Positioned(
                left: toc ? 240 : 0,
                right: ask && wide ? 320 : 0,
                bottom: 0,
                child: Material(
                  color: paper,
                  child: SafeArea(
                    top: false,
                    child: GestureDetector(
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: progress.clamp(0, 1),
                              onChanged: (value) {
                                setState(() => progress = value);
                                ref
                                    .read(libraryProvider)
                                    .updateProgress(widget.id, value);
                                final reader = opened;
                                if (reader is TextReaderDocument) {
                                  final length = reader.parsed.fullText.isEmpty
                                      ? 1
                                      : reader.parsed.fullText.length;
                                  reader.goTo(
                                    TextLocator(
                                      offset: (value * length).round(),
                                    ),
                                  );
                                  body = _bodyFor(reader);
                                }
                              },
                            ),
                            Row(
                              children: [
                                Text(
                                  tocItems.isEmpty
                                      ? formatLabel
                                      : l10n.readerSection(
                                          currentIndex + 1,
                                          tocItems.length,
                                        ),
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReadingSettings() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final prefs = ref.watch(readerPrefsProvider);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _readerBody({
    required AppLocalizations l10n,
    required LibraryDocument? document,
    required Color ink,
    required Color muted,
    required String heading,
    required bool showHeading,
    required List<String> paragraphs,
    required int currentIndex,
    required double fontSize,
    required String formatLabel,
  }) {
    if (loading) {
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
    }
    if (opened is UnavailableReaderDocument) {
      final missingFile =
          document == null || document.metadata.format.isPlainText;
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Text(
          missingFile
              ? l10n.readerMissingFile
              : l10n.readerUnavailable(document.metadata.format.label),
          style: TextStyle(color: ink, fontSize: fontSize, height: 1.7),
        ),
      );
    }
    final truncated =
        opened is TextReaderDocument &&
        (opened as TextReaderDocument).parsed.truncated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tocItems.isEmpty
              ? formatLabel
              : l10n.readerSection(currentIndex + 1, tocItems.length),
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
            ),
          ),
          const SizedBox(height: 28),
        ],
        if (truncated) ...[
          Text(
            l10n.readerTruncated,
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 22),
        ],
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 22),
          Text(
            paragraphs[i],
            style: TextStyle(color: ink, fontSize: fontSize, height: 1.85),
          ),
        ],
      ],
    );
  }
}
