import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/annotated_text.dart';
import 'package:app/features/library/annotation_store.dart';
import 'package:app/features/reader/reader_annotated_body.dart';

void main() {
  const style = TextStyle(fontSize: 16);

  DateTime _at(int seconds) => DateTime.utc(2024, 1, 1).add(Duration(seconds: seconds));

  ReaderAnnotation _note(String quote) => ReaderAnnotation(
        id: 'a',
        note: '',
        quote: quote,
        source: userNoteSource,
        createdAt: _at(0),
      );

  Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders paragraphs with the given style', (tester) async {
    await tester.pumpWidget(_wrap(ReaderAnnotatedBody(
      paragraphs: const ['第一段', '第二段'],
      style: style,
      notes: const [],
      highlightKey: null,
      onSelectionChanged: _noopSelection,
    )));
    await tester.pumpAndSettle();
    expect(find.text('第一段'), findsOneWidget);
    expect(find.text('第二段'), findsOneWidget);
  });

  testWidgets('omits spacer before the first paragraph', (tester) async {
    await tester.pumpWidget(_wrap(ReaderAnnotatedBody(
      paragraphs: const ['仅一段'],
      style: style,
      notes: const [],
      highlightKey: null,
      onSelectionChanged: _noopSelection,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('emits onSelectionChanged for non-empty selection',
      (tester) async {
    String? captured;
    await tester.pumpWidget(_wrap(ReaderAnnotatedBody(
      paragraphs: const ['一段可供选取的文字'],
      style: style,
      notes: const [],
      highlightKey: null,
      onSelectionChanged: (quote) => captured = quote,
    )));
    await tester.pumpAndSettle();
    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    selectable.onSelectionChanged!(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      null,
    );
    await tester.pump();
    expect(captured, '一段');
  });

  testWidgets('ignores collapsed and whitespace-only selections',
      (tester) async {
    var calls = 0;
    void onSelection(String _) => calls++;
    await tester.pumpWidget(_wrap(ReaderAnnotatedBody(
      paragraphs: const ['一段文字'],
      style: style,
      notes: const [],
      highlightKey: null,
      onSelectionChanged: onSelection,
    )));
    await tester.pumpAndSettle();
    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
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

  testWidgets('localizes a known highlighted quote onto annotatedQuoteKey',
      (tester) async {
    final keyFinder = find.byKey(annotatedQuoteKey);
    expect(keyFinder, findsNothing);
    await tester.pumpWidget(_wrap(ReaderAnnotatedBody(
      paragraphs: const ['一些普通文字', '重要的是这一句'],
      style: style,
      notes: [_note('重要的是这一句')],
      highlightKey: annotatedQuoteKey,
      onSelectionChanged: _noopSelection,
    )));
    await tester.pumpAndSettle();
    expect(keyFinder, findsOneWidget);
  });

  testWidgets('uses the provided highlightKey when a highlight is present',
      (tester) async {
    final customKey = const ValueKey('custom-highlight');
    await tester.pumpWidget(_wrap(ReaderAnnotatedBody(
      paragraphs: const ['some text with needle'],
      style: style,
      notes: [_note('needle')],
      highlightKey: customKey,
      onSelectionChanged: _noopSelection,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(customKey), findsOneWidget);
    expect(find.byKey(annotatedQuoteKey), findsNothing);
  });
}

void _noopSelection(String _) {}
