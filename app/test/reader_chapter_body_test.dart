import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/reading_surface.dart';
import 'package:app/features/reader/reader_chapter_body.dart';
import 'package:app/l10n/generated/app_localizations.dart';

void main() {
  ReadingSurface surface({Brightness brightness = Brightness.light}) {
    return ReadingSurface.resolve(
      fontSize: 18,
      lineHeight: 1.5,
      fontFamily: ReaderFontFamily.serif,
      paper: ReaderPaper.light,
      brightness: brightness,
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('loading state shows spinner and copy', (tester) async {
    await tester.pumpWidget(
      wrap(
        ReaderChapterBody(
          state: const ReaderChapterState.loading(),
          surface: surface(),
          surfaceColor: Colors.black,
          mutedColor: Colors.grey,
          heading: '',
          showHeading: false,
          hasToc: false,
          currentIndex: 0,
          chapterCount: 0,
          formatLabel: 'EPUB',
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.readerLoading), findsOneWidget);
  });

  testWidgets('corrupt state shows the corrupt-file copy', (tester) async {
    await tester.pumpWidget(
      wrap(
        ReaderChapterBody(
          state: const ReaderChapterState.corrupt(),
          surface: surface(),
          surfaceColor: Colors.black,
          mutedColor: Colors.grey,
          heading: '',
          showHeading: false,
          hasToc: false,
          currentIndex: 0,
          chapterCount: 0,
          formatLabel: 'EPUB',
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.readerCorruptFile), findsOneWidget);
  });

  testWidgets('unavailable with missing file shows readerMissingFile', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderChapterBody(
          state: const ReaderChapterState.unavailable(
            missingFile: true,
            formatLabel: 'EPUB',
          ),
          surface: surface(),
          surfaceColor: Colors.black,
          mutedColor: Colors.grey,
          heading: '',
          showHeading: false,
          hasToc: false,
          currentIndex: 0,
          chapterCount: 0,
          formatLabel: 'EPUB',
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.readerMissingFile), findsOneWidget);
  });

  testWidgets('unavailable known format shows readerUnavailable with format', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderChapterBody(
          state: const ReaderChapterState.unavailable(
            missingFile: false,
            formatLabel: 'EPUB',
          ),
          surface: surface(),
          surfaceColor: Colors.black,
          mutedColor: Colors.grey,
          heading: '',
          showHeading: false,
          hasToc: false,
          currentIndex: 0,
          chapterCount: 0,
          formatLabel: 'EPUB',
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('EPUB 阅读器尚未接入'), findsOneWidget);
  });

  testWidgets('ready state with truncation renders truncated notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderChapterBody(
          state: const ReaderChapterState.ready(truncated: true),
          surface: surface(),
          surfaceColor: Colors.black,
          mutedColor: Colors.grey,
          heading: '第 1 章',
          showHeading: true,
          hasToc: true,
          currentIndex: 0,
          chapterCount: 1,
          formatLabel: 'EPUB',
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.readerTruncated), findsOneWidget);
    expect(find.text('第 1 章'), findsOneWidget);
  });

  testWidgets('ready state without heading still renders child', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderChapterBody(
          state: const ReaderChapterState.ready(truncated: false),
          surface: surface(),
          surfaceColor: Colors.black,
          mutedColor: Colors.grey,
          heading: '',
          showHeading: false,
          hasToc: false,
          currentIndex: 0,
          chapterCount: 0,
          formatLabel: 'EPUB',
          child: const Text('Only body'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Only body'), findsOneWidget);
  });

  testWidgets('ready state shows section label when toc is present', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await tester.pumpWidget(
      wrap(
        ReaderChapterBody(
          state: const ReaderChapterState.ready(truncated: false),
          surface: surface(),
          surfaceColor: Colors.black,
          mutedColor: Colors.grey,
          heading: 'Chapter 1',
          showHeading: true,
          hasToc: true,
          currentIndex: 0,
          chapterCount: 5,
          formatLabel: 'EPUB',
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(l10n.readerSection(1, 5)), findsOneWidget);
  });

  testWidgets(
    'ready state without toc shows formatLabel instead of section label',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          ReaderChapterBody(
            state: const ReaderChapterState.ready(truncated: false),
            surface: surface(),
            surfaceColor: Colors.black,
            mutedColor: Colors.grey,
            heading: 'Chapter 1',
            showHeading: false,
            hasToc: false,
            currentIndex: 0,
            chapterCount: 0,
            formatLabel: 'TXT',
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('TXT'), findsOneWidget);
    },
  );

  testWidgets(
    'ready state with toc but chapterCount<=0 falls back to chapter 1',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await tester.pumpWidget(
        wrap(
          ReaderChapterBody(
            state: const ReaderChapterState.ready(truncated: false),
            surface: surface(),
            surfaceColor: Colors.black,
            mutedColor: Colors.grey,
            heading: 'Chapter 1',
            showHeading: false,
            hasToc: true,
            currentIndex: 0,
            chapterCount: 0,
            formatLabel: 'EPUB',
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(l10n.readerSection(1, 1)), findsOneWidget);
    },
  );

  testWidgets('ready state with showHeading=false omits the heading text', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderChapterBody(
          state: const ReaderChapterState.ready(truncated: false),
          surface: surface(),
          surfaceColor: Colors.black,
          mutedColor: Colors.grey,
          heading: 'Hidden heading',
          showHeading: false,
          hasToc: false,
          currentIndex: 0,
          chapterCount: 0,
          formatLabel: 'EPUB',
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Hidden heading'), findsNothing);
  });

  testWidgets('ready state omits the truncated notice when truncated=false', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await tester.pumpWidget(
      wrap(
        ReaderChapterBody(
          state: const ReaderChapterState.ready(truncated: false),
          surface: surface(),
          surfaceColor: Colors.black,
          mutedColor: Colors.grey,
          heading: 'Chapter 1',
          showHeading: false,
          hasToc: false,
          currentIndex: 0,
          chapterCount: 0,
          formatLabel: 'EPUB',
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(l10n.readerTruncated), findsNothing);
  });
}
