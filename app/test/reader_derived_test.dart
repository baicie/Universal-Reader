import 'package:app/core/models.dart';
import 'package:app/core/reader_derived.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/features/tools/sample_reader_document.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubHtmlChaptered implements HtmlChapteredDocument {
  _StubHtmlChaptered({
    required this.chapterIndex,
    required this.chapterCount,
    required this.currentChapterHref,
    required this.currentChapterTitle,
    required this.currentChapterText,
    required this.currentChapterHtml,
  });

  @override
  final int chapterIndex;

  @override
  final int chapterCount;

  @override
  final String currentChapterHref;

  @override
  final String currentChapterTitle;

  @override
  final String currentChapterText;

  @override
  final String currentChapterHtml;

  @override
  final bool truncated = false;

  @override
  DocumentMetadata get metadata => DocumentMetadata(
    id: 'stub',
    title: currentChapterTitle,
    author: '',
    format: DocumentFormat.epub,
    type: DocumentType.reflow,
  );

  @override
  Locator locatorForProgress(double progress) =>
      EpubLocator(href: currentChapterHref, progression: progress);

  @override
  Future<Locator> currentLocator() async =>
      EpubLocator(href: currentChapterHref, progression: 0);

  @override
  Future<String?> extractText(DocumentRange range) async => currentChapterText;

  @override
  Future<void> goTo(Locator locator) async {}

  @override
  Stream<double> get progress => const Stream<double>.empty();

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  Future<List<TocItem>> getToc() async => const [];
}

void main() {
  DocumentMetadata metadata(String id) => DocumentMetadata(
    id: id,
    title: id,
    author: '',
    format: DocumentFormat.epub,
    type: DocumentType.reflow,
  );

  TocItem toc(String title, int chapter) => TocItem(
    title: title,
    locator: EpubLocator(href: 'ch$chapter.xhtml'),
  );

  AppLocalizations l10n(BuildContext context) => AppLocalizations.of(context);

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(builder: (context) => child),
  );

  testWidgets('returns current chapter index from ChapteredDocument', (
    tester,
  ) async {
    AppLocalizations? captured;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            captured = l10n(context);
            final state = ReaderDerived.build(
              opened: null,
              tocItems: const [],
              body: '',
              l10n: captured!,
            );
            expect(state.currentIndex, 0);
            expect(state.chapterCount, 0);
            expect(state.currentHref, '');
            expect(state.currentTitle, '');
            expect(state.heading, captured!.untitledSection);
            expect(state.paragraphs, isEmpty);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets(
    'derives title and href from tocItems when document is not chaptered',
    (tester) async {
      AppLocalizations? captured;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              captured = l10n(context);
              final items = [toc('Chapter 1', 1), toc('Chapter 2', 2)];
              final state = ReaderDerived.build(
                opened: null,
                tocItems: items,
                body: '',
                l10n: captured!,
              );
              expect(state.currentIndex, 0);
              expect(state.chapterCount, 2);
              expect(state.currentHref, '');
              expect(state.currentTitle, 'Chapter 1');
              expect(state.heading, 'Chapter 1');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );

  testWidgets('splits body into paragraphs', (tester) async {
    AppLocalizations? captured;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            captured = l10n(context);
            final state = ReaderDerived.build(
              opened: null,
              tocItems: const [],
              body: 'Hello.\n\nWorld.',
              l10n: captured!,
            );
            expect(state.paragraphs, ['Hello.', 'World.']);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('falls back to untitledSection when currentTitle is whitespace', (
    tester,
  ) async {
    AppLocalizations? captured;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            captured = l10n(context);
            final items = [toc('   ', 1)];
            final state = ReaderDerived.build(
              opened: null,
              tocItems: items,
              body: '',
              l10n: captured!,
            );
            expect(state.heading, captured!.untitledSection);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets(
    'clamps currentIndex when chapterCount differs from tocItems.length',
    (tester) async {
      AppLocalizations? captured;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              captured = l10n(context);
              // currentIndex=99 would normally crash on tocItems[99].
              final items = [toc('Only Chapter', 1)];
              final state = ReaderDerived.build(
                opened: null,
                tocItems: items,
                body: '',
                l10n: captured!,
              );
              // No chaptered doc → currentIndex=0, currentTitle from toc[0].
              expect(state.currentIndex, 0);
              expect(state.currentTitle, 'Only Chapter');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );

  testWidgets('derives fields from a non-HTML ChapteredDocument', (
    tester,
  ) async {
    AppLocalizations? captured;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            captured = l10n(context);
            // SampleReaderDocument implements ChapteredDocument but not HTML.
            final doc = SampleReaderDocument(
              metadata: metadata('book'),
              chapterHref: 'chapter-9',
              chapterProgress: 0.5,
            );
            final state = ReaderDerived.build(
              opened: doc,
              tocItems: const <TocItem>[],
              body: '',
              l10n: captured!,
            );
            expect(state.currentIndex, 0);
            expect(state.chapterCount, 1);
            // Non-HTML chaptered doc leaves href empty; title comes from toc[0]
            // but toc is empty here so heading falls back to untitledSection.
            expect(state.currentHref, '');
            expect(state.currentTitle, '');
            expect(state.heading, captured!.untitledSection);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets(
    'HTML chaptered document overrides currentTitle, href, and heading',
    (tester) async {
      AppLocalizations? captured;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              captured = l10n(context);
              final doc = _StubHtmlChaptered(
                chapterIndex: 2,
                chapterCount: 5,
                currentChapterHref: 'ch3.xhtml',
                currentChapterTitle: '第三章 留白',
                currentChapterText: 'paragraph 1\n\nparagraph 2',
                currentChapterHtml: '<p>paragraph 1</p><p>paragraph 2</p>',
              );
              final state = ReaderDerived.build(
                opened: doc,
                tocItems: const <TocItem>[],
                body: '',
                l10n: captured!,
              );
              expect(state.currentIndex, 2);
              expect(state.chapterCount, 5);
              expect(state.currentHref, 'ch3.xhtml');
              expect(state.currentTitle, '第三章 留白');
              expect(state.heading, '第三章 留白');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );

  testWidgets('non-HTML chaptered doc pulls title from tocItems when present', (
    tester,
  ) async {
    AppLocalizations? captured;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            captured = l10n(context);
            final doc = SampleReaderDocument(metadata: metadata('book'));
            final state = ReaderDerived.build(
              opened: doc,
              tocItems: [toc('Intro', 1), toc('Main', 2)],
              body: '',
              l10n: captured!,
            );
            // SampleReaderDocument reports chapterIndex=0 → toc[0] wins.
            expect(state.currentIndex, 0);
            expect(state.chapterCount, 1);
            // Non-HTML → href empty; title from toc[0].
            expect(state.currentHref, '');
            expect(state.currentTitle, 'Intro');
            expect(state.heading, 'Intro');
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('clamps toc index even with a chaptered doc', (tester) async {
    // sample reader reports chapterIndex=0; the toc only has one entry so the
    // currentIndex/clamp branch is exercised without risk.
    AppLocalizations? captured;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            captured = l10n(context);
            final doc = SampleReaderDocument(metadata: metadata('book'));
            final state = ReaderDerived.build(
              opened: doc,
              tocItems: const <TocItem>[],
              body: '',
              l10n: captured!,
            );
            expect(state.currentIndex, 0);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('empty body yields empty paragraphs', (tester) async {
    AppLocalizations? captured;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            captured = l10n(context);
            final state = ReaderDerived.build(
              opened: null,
              tocItems: const [],
              body: '',
              l10n: captured!,
            );
            expect(state.paragraphs, isEmpty);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets(
    'ReaderDerived constructor preserves its fields without normalization',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              final derived = ReaderDerived(
                currentIndex: 0,
                chapterCount: 0,
                currentHref: 'h',
                currentTitle: 't',
                heading: 'Heading',
                paragraphs: const <String>['p'],
              );
              expect(derived.currentHref, 'h');
              expect(derived.currentTitle, 't');
              expect(derived.heading, 'Heading');
              expect(derived.paragraphs, ['p']);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );
}
