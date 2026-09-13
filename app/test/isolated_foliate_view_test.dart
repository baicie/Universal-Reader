import 'package:app/core/epub_document.dart';
import 'package:app/core/foliate_session.dart';
import 'package:app/core/models.dart';
import 'package:app/core/reading_surface.dart';
import 'package:app/features/reader/renderers/isolated_foliate_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/epub_fixture.dart';

void main() {
  const metadata = DocumentMetadata(
    id: 'epub-1',
    title: 'Fixture',
    author: 'A',
    format: DocumentFormat.epub,
    type: DocumentType.reflow,
  );

  const boundedFallback = SizedBox(
    width: 200,
    height: 200,
    child: Text('bounded fallback'),
  );

  EpubReaderDocument buildDocument() {
    return EpubReaderDocument.parse(
      metadata: metadata,
      bytes: minimalEpubBytes(firstBody: 'hello from epub'),
    );
  }

  Widget host(IsolatedFoliateView view) {
    return MaterialApp(home: Scaffold(body: view));
  }

  // ── fallback branch (native renderer off in tests) ─────────────────────

  testWidgets(
    'renders the fallback content when the native renderer is unavailable',
    (tester) async {
      final document = buildDocument();
      const fallback = Text('fallback content');

      await tester.pumpWidget(
        host(IsolatedFoliateView(document: document, fallback: fallback)),
      );

      expect(find.byKey(const Key('foliate-surface')), findsOneWidget);
      expect(find.text('fallback content'), findsOneWidget);
    },
  );

  testWidgets('tap on the left strip fires onPrevious callback', (
    tester,
  ) async {
    final document = buildDocument();
    var previousTaps = 0;

    await tester.pumpWidget(
      host(
        IsolatedFoliateView(
          document: document,
          fallback: boundedFallback,
          onPrevious: () => previousTaps += 1,
        ),
      ),
    );

    // The left strip is the left third of the surface width.
    final size = tester.view.physicalSize;
    final dpr = tester.view.devicePixelRatio;
    final width = size.width / dpr;
    final height = size.height / dpr;
    await tester.tapAt(Offset(width / 6, height / 2));
    await tester.pumpAndSettle();

    expect(previousTaps, 1);
  });

  testWidgets('tap on the right strip fires onNext callback', (tester) async {
    final document = buildDocument();
    var nextTaps = 0;

    await tester.pumpWidget(
      host(
        IsolatedFoliateView(
          document: document,
          fallback: boundedFallback,
          onNext: () => nextTaps += 1,
        ),
      ),
    );

    final size = tester.view.physicalSize;
    final dpr = tester.view.devicePixelRatio;
    final width = size.width / dpr;
    final height = size.height / dpr;
    await tester.tapAt(Offset(width * 5 / 6, height / 2));
    await tester.pumpAndSettle();

    expect(nextTaps, 1);
  });

  testWidgets(
    'uses ReadingSurface to seed the bridge typography on fallback path',
    (tester) async {
      final document = buildDocument();
      const fallback = Text('surface fallback');
      final darkSurface = ReadingSurface.resolve(
        fontSize: 22,
        lineHeight: 1.6,
        fontFamily: ReaderFontFamily.sans,
        paper: ReaderPaper.dark,
        brightness: Brightness.light,
      );

      await tester.pumpWidget(
        host(
          IsolatedFoliateView(
            document: document,
            fallback: fallback,
            surface: darkSurface,
          ),
        ),
      );

      // Verifies that the surface is forwarded without crashing in fallback.
      expect(find.text('surface fallback'), findsOneWidget);
      expect(find.byKey(const Key('foliate-surface')), findsOneWidget);
    },
  );

  testWidgets('forwarding quotes does not crash in the fallback path', (
    tester,
  ) async {
    final document = buildDocument();

    await tester.pumpWidget(
      host(
        IsolatedFoliateView(
          document: document,
          fallback: boundedFallback,
          quotes: const ['quote-1', 'quote-2'],
        ),
      ),
    );

    expect(find.byKey(const Key('foliate-surface')), findsOneWidget);
  });

  testWidgets('forwarding a session does not crash in the fallback path', (
    tester,
  ) async {
    final document = buildDocument();
    final session = FoliateSession.open(document, pageCharLimit: 200);

    await tester.pumpWidget(
      host(
        IsolatedFoliateView(
          document: document,
          session: session,
          fallback: boundedFallback,
        ),
      ),
    );

    expect(find.byKey(const Key('foliate-surface')), findsOneWidget);
  });

  testWidgets(
    'updating fragmentEpoch without a fragment is a no-op in fallback',
    (tester) async {
      final document = buildDocument();

      Widget build(int epoch) => host(
        IsolatedFoliateView(
          document: document,
          fallback: boundedFallback,
          fragmentEpoch: epoch,
        ),
      );

      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('foliate-surface')), findsOneWidget);
    },
  );

  testWidgets(
    'updating scrollQuoteEpoch without a quote is a no-op in fallback',
    (tester) async {
      final document = buildDocument();

      Widget build(int epoch) => host(
        IsolatedFoliateView(
          document: document,
          fallback: boundedFallback,
          scrollQuoteEpoch: epoch,
        ),
      );

      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('foliate-surface')), findsOneWidget);
    },
  );

  testWidgets('updating pageIndex without a session is a no-op in fallback', (
    tester,
  ) async {
    final document = buildDocument();

    Widget build(int index) => host(
      IsolatedFoliateView(
        document: document,
        fallback: boundedFallback,
        pageIndex: index,
      ),
    );

    await tester.pumpWidget(build(0));
    await tester.pumpWidget(build(3));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foliate-surface')), findsOneWidget);
  });

  testWidgets('updating quotes triggers a didUpdateWidget without crashing', (
    tester,
  ) async {
    final document = buildDocument();

    Widget build(List<String> quotes) => host(
      IsolatedFoliateView(
        document: document,
        fallback: boundedFallback,
        quotes: quotes,
      ),
    );

    await tester.pumpWidget(build(const ['q1']));
    await tester.pumpWidget(build(const ['q1', 'q2']));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foliate-surface')), findsOneWidget);
  });

  testWidgets('updating surface triggers a didUpdateWidget without crashing', (
    tester,
  ) async {
    final document = buildDocument();

    Widget build(ReadingSurface surface) => host(
      IsolatedFoliateView(
        document: document,
        fallback: boundedFallback,
        surface: surface,
      ),
    );

    await tester.pumpWidget(build(ReadingSurface.light));
    await tester.pumpWidget(
      build(
        ReadingSurface.resolve(
          fontSize: 20,
          lineHeight: 1.5,
          fontFamily: ReaderFontFamily.sans,
          paper: ReaderPaper.dark,
          brightness: Brightness.light,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foliate-surface')), findsOneWidget);
  });
}
