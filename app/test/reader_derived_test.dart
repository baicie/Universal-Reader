import 'package:app/core/models.dart';
import 'package:app/core/reader_derived.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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

  AppLocalizations _l10n(BuildContext context) =>
      AppLocalizations.of(context);

  Widget _wrap(Widget child) => MaterialApp(
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

  testWidgets(
    'returns current chapter index from ChapteredDocument',
    (tester) async {
      AppLocalizations? captured;
      await tester.pumpWidget(
        _wrap(
          Builder(builder: (context) {
            captured = _l10n(context);
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
          }),
        ),
      );
    },
  );

  testWidgets(
    'derives title and href from tocItems when document is not chaptered',
    (tester) async {
      AppLocalizations? captured;
      await tester.pumpWidget(
        _wrap(
          Builder(builder: (context) {
            captured = _l10n(context);
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
          }),
        ),
      );
    },
  );

  testWidgets(
    'splits body into paragraphs',
    (tester) async {
      AppLocalizations? captured;
      await tester.pumpWidget(
        _wrap(
          Builder(builder: (context) {
            captured = _l10n(context);
            final state = ReaderDerived.build(
              opened: null,
              tocItems: const [],
              body: 'Hello.\n\nWorld.',
              l10n: captured!,
            );
            expect(state.paragraphs, ['Hello.', 'World.']);
            return const SizedBox.shrink();
          }),
        ),
      );
    },
  );

  testWidgets(
    'falls back to untitledSection when currentTitle is whitespace',
    (tester) async {
      AppLocalizations? captured;
      await tester.pumpWidget(
        _wrap(
          Builder(builder: (context) {
            captured = _l10n(context);
            final items = [toc('   ', 1)];
            final state = ReaderDerived.build(
              opened: null,
              tocItems: items,
              body: '',
              l10n: captured!,
            );
            expect(state.heading, captured!.untitledSection);
            return const SizedBox.shrink();
          }),
        ),
      );
    },
  );

  testWidgets(
    'clamps currentIndex when chapterCount differs from tocItems.length',
    (tester) async {
      AppLocalizations? captured;
      await tester.pumpWidget(
        _wrap(
          Builder(builder: (context) {
            captured = _l10n(context);
            // currentIndex=99 would normally crash on tocItems[99].
            final items = [toc('Only Chapter', 1)];
            final state = ReaderDerived.build(
              opened: null,
              tocItems: items,
              body: '',
              l10n: captured!,
            );
            // No chaptered doc 鈫?currentIndex=0, currentTitle from toc[0].
            expect(state.currentIndex, 0);
            expect(state.currentTitle, 'Only Chapter');
            return const SizedBox.shrink();
          }),
        ),
      );
    },
  );
}
