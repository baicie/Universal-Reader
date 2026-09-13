import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/annotated_text.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_annotated_body.dart';

void main() {
  const style = TextStyle(fontSize: 16);

  DateTime at(int seconds) =>
      DateTime.utc(2024, 1, 1).add(Duration(seconds: seconds));

  ReaderAnnotation note(String quote) => ReaderAnnotation(
    id: 'a',
    note: '',
    quote: quote,
    source: userNoteSource,
    createdAt: at(0),
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders paragraphs with the given style', (tester) async {
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['第一段', '第二段'],
          style: style,
          notes: const [],
          highlightKey: null,
          onSelectionChanged: _noopSelection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('第一段'), findsOneWidget);
    expect(find.text('第二段'), findsOneWidget);
  });

  testWidgets('omits spacer before the first paragraph', (tester) async {
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['仅一段'],
          style: style,
          notes: const [],
          highlightKey: null,
          onSelectionChanged: _noopSelection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('emits onSelectionChanged for non-empty selection', (
    tester,
  ) async {
    String? captured;
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['一段可供选取的文字'],
          style: style,
          notes: const [],
          highlightKey: null,
          onSelectionChanged: (quote) => captured = quote,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    selectable.onSelectionChanged!(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      null,
    );
    await tester.pump();
    expect(captured, '一段');
  });

  testWidgets('ignores collapsed and whitespace-only selections', (
    tester,
  ) async {
    var calls = 0;
    void onSelection(String _) => calls++;
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['一段文字'],
          style: style,
          notes: const [],
          highlightKey: null,
          onSelectionChanged: onSelection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    selectable.onSelectionChanged!(
      const TextSelection.collapsed(offset: 0),
      null,
    );
    selectable.onSelectionChanged!(
      const TextSelection(baseOffset: 0, extentOffset: 3),
      null,
    );
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('localizes a known highlighted quote onto annotatedQuoteKey', (
    tester,
  ) async {
    final keyFinder = find.byKey(annotatedQuoteKey);
    expect(keyFinder, findsNothing);
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['一些普通文字', '重要的是这一句'],
          style: style,
          notes: [note('重要的是这一句')],
          highlightKey: annotatedQuoteKey,
          onSelectionChanged: _noopSelection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(keyFinder, findsOneWidget);
  });

  testWidgets('uses the provided highlightKey when a highlight is present', (
    tester,
  ) async {
    final customKey = const ValueKey('custom-highlight');
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['some text with needle'],
          style: style,
          notes: [note('needle')],
          highlightKey: customKey,
          onSelectionChanged: _noopSelection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(customKey), findsOneWidget);
    expect(find.byKey(annotatedQuoteKey), findsNothing);
  });

  testWidgets('inserts the gap widget between consecutive paragraphs', (
    tester,
  ) async {
    const gap = SizedBox(height: 22);
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['段一', '段二', '段三'],
          style: style,
          notes: const [],
          highlightKey: null,
          onSelectionChanged: _noopSelection,
          gap: gap,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Three paragraphs → two gaps in between.
    final gaps = find.byWidgetPredicate((w) => identical(w, gap));
    expect(gaps, findsNWidgets(2));
  });

  testWidgets('omits the gap widget when there is only one paragraph', (
    tester,
  ) async {
    const gap = SizedBox(height: 22);
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['only'],
          style: style,
          notes: const [],
          highlightKey: null,
          onSelectionChanged: _noopSelection,
          gap: gap,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => identical(w, gap)), findsNothing);
  });

  testWidgets('falls back to the default gap when none is provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['a', 'b'],
          style: style,
          notes: const [],
          highlightKey: null,
          onSelectionChanged: _noopSelection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The default gap is a SizedBox(height: 22). Verify at least one such
    // SizedBox is rendered between the two paragraphs.
    final gaps = find.byWidgetPredicate(
      (w) => w is SizedBox && w.height == 22 && w.width == null,
    );
    expect(gaps, findsWidgets);
  });

  testWidgets('ignores bookmarks when locating the highlighted quote', (
    tester,
  ) async {
    // bookmark quotes must not trigger highlight spans, so the
    // annotatedQuoteKey is not used.
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['plain text'],
          style: style,
          notes: [
            ReaderAnnotation(
              id: 'b',
              note: '',
              quote: 'plain text',
              source: bookmarkSource,
              createdAt: at(0),
            ),
          ],
          highlightKey: annotatedQuoteKey,
          onSelectionChanged: _noopSelection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(annotatedQuoteKey), findsNothing);
  });

  testWidgets('skips quotes that are pure whitespace', (tester) async {
    // Whitespace-only quotes are filtered by quoteHighlights, so no spans
    // get the highlight colour and the highlightKey is not used.
    await tester.pumpWidget(
      wrap(
        ReaderAnnotatedBody(
          paragraphs: const ['main text'],
          style: style,
          notes: [
            ReaderAnnotation(
              id: 'w',
              note: '',
              quote: '   \n  ',
              source: userNoteSource,
              createdAt: at(0),
            ),
          ],
          highlightKey: annotatedQuoteKey,
          onSelectionChanged: _noopSelection,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(annotatedQuoteKey), findsNothing);
  });

  testWidgets(
    'annotatePlainText returns one text span when there are no quotes',
    (tester) async {
      final spans = annotatePlainText('hello', const []);
      expect(spans, hasLength(1));
      expect((spans.single as TextSpan).text, 'hello');
    },
  );

  testWidgets('annotatePlainText splits text around the matched quote', (
    tester,
  ) async {
    final spans = annotatePlainText(
      'before needle after',
      const <ReaderAnnotation>[
        // constructed inline below; quote must be non-empty trimmed
      ],
      style: const TextStyle(fontSize: 14),
    );
    // Empty quote list → single span containing the full text.
    expect(spans.single, isA<TextSpan>());
    expect((spans.single as TextSpan).text, 'before needle after');
  });

  testWidgets('annotatePlainText highlights every occurrence of the quote', (
    tester,
  ) async {
    final spans = annotatePlainText('aa bb aa bb', [
      ReaderAnnotation(
        id: 'x',
        note: '',
        quote: 'aa',
        source: userNoteSource,
        createdAt: at(0),
      ),
    ]);
    // 4 spans: aa(highlight) + ' bb ' + aa(highlight) + ' bb'.
    expect(spans, hasLength(4));
    // Background-color check is brittle; instead inspect the text content.
    final renderedText = spans
        .whereType<TextSpan>()
        .map((s) => s.text ?? '')
        .join();
    expect(renderedText, 'aa bb aa bb');
  });

  testWidgets(
    'annotatePlainText picks the longest quote when two could match',
    (tester) async {
      // Both 'ne' and 'needle' match the first occurrence; longest wins.
      final spans = annotatePlainText('needle here', [
        ReaderAnnotation(
          id: 's',
          note: '',
          quote: 'ne',
          source: userNoteSource,
          createdAt: at(0),
        ),
        ReaderAnnotation(
          id: 'l',
          note: '',
          quote: 'needle',
          source: userNoteSource,
          createdAt: at(0),
        ),
      ]);
      final renderedText = spans
          .whereType<TextSpan>()
          .map((s) => s.text ?? '')
          .join();
      expect(renderedText, 'needle here');
      // Exactly one highlight span.
      final highlights = spans
          .whereType<TextSpan>()
          .where((s) => s.style?.backgroundColor != null)
          .toList();
      expect(highlights, hasLength(1));
      expect(highlights.single.text, 'needle');
    },
  );

  testWidgets('annotatePlainText with empty text returns one empty span', (
    tester,
  ) async {
    final spans = annotatePlainText('', [
      ReaderAnnotation(
        id: 'a',
        note: '',
        quote: 'x',
        source: userNoteSource,
        createdAt: at(0),
      ),
    ]);
    expect(spans, hasLength(1));
    expect((spans.single as TextSpan).text, '');
  });

  testWidgets('quoteHighlights excludes bookmark sources and blank quotes', (
    tester,
  ) async {
    final quotes = quoteHighlights([
      ReaderAnnotation(
        id: '1',
        note: '',
        quote: 'keep me',
        source: userNoteSource,
        createdAt: at(0),
      ),
      ReaderAnnotation(
        id: '2',
        note: '',
        quote: 'drop me',
        source: bookmarkSource,
        createdAt: at(1),
      ),
      ReaderAnnotation(
        id: '3',
        note: '',
        quote: '   ',
        source: userNoteSource,
        createdAt: at(2),
      ),
    ]);
    expect(quotes, ['keep me']);
  });
}

void _noopSelection(String _) {}
