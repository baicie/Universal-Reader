import 'package:app/core/annotated_text.dart';
import 'package:app/features/reader/reader_bottom_overlay.dart';
import 'package:app/features/reader/reader_progress_bar.dart';
import 'package:app/features/reader/selection_confirm_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const paper = Color(0xFFFFFFFF);
  const muted = Color(0xFF777777);
  const ink = Color(0xFF000000);

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Stack(children: [child])),
  );

  Finder positionedWithKey(Key key) =>
      find.ancestor(of: find.byKey(key), matching: find.byType(Positioned));

  Future<Rect> bounds(WidgetTester tester, Finder finder) async {
    final renderObject = tester.renderObject<RenderBox>(finder);
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  testWidgets('shows progress bar when chrome is on and nothing is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderBottomOverlay(
          pendingQuote: null,
          saveLabel: 'Save',
          chrome: true,
          sideOpen: false,
          askAndWide: false,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: 0.42,
          progressLabel: 'p 1/10',
          onSaveSelection: () {},
          onDismissSelection: () {},
          onSeekProgress: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReaderProgressBar), findsOneWidget);
    expect(find.byType(SelectionConfirmBar), findsNothing);
  });

  testWidgets('renders nothing when chrome is off and nothing is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderBottomOverlay(
          pendingQuote: null,
          saveLabel: 'Save',
          chrome: false,
          sideOpen: false,
          askAndWide: false,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: 0.42,
          progressLabel: 'p 1/10',
          onSaveSelection: () {},
          onDismissSelection: () {},
          onSeekProgress: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReaderProgressBar), findsNothing);
    expect(find.byType(SelectionConfirmBar), findsNothing);
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets(
    'shows selection confirm above the chrome strip when both visible',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          ReaderBottomOverlay(
            pendingQuote: '一段选取',
            saveLabel: 'Save',
            chrome: true,
            sideOpen: false,
            askAndWide: false,
            paper: paper,
            muted: muted,
            ink: ink,
            progress: 0.42,
            progressLabel: 'p 1/10',
            onSaveSelection: () {},
            onDismissSelection: () {},
            onSeekProgress: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectionConfirmBar), findsOneWidget);
      expect(find.byType(ReaderProgressBar), findsNothing);

      final positioned = positionedWithKey(selectionConfirmKey);
      final rect = await bounds(tester, positioned);
      expect(
        rect.bottom,
        600 - 72,
        reason: 'Selection bar should sit 72px above the bottom when chrome is visible',
      );
    },
  );

  testWidgets('selection confirm sits at the bottom when chrome is hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderBottomOverlay(
          pendingQuote: 'hi',
          saveLabel: 'Save',
          chrome: false,
          sideOpen: false,
          askAndWide: false,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: 0.42,
          progressLabel: 'p 1/10',
          onSaveSelection: () {},
          onDismissSelection: () {},
          onSeekProgress: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final positioned = positionedWithKey(selectionConfirmKey);
    final rect = await bounds(tester, positioned);
    expect(rect.bottom, 600);
  });

  testWidgets('progress bar hugs the bottom edge when chrome is visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderBottomOverlay(
          pendingQuote: null,
          saveLabel: 'Save',
          chrome: true,
          sideOpen: false,
          askAndWide: false,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: 0.42,
          progressLabel: 'p 1/10',
          onSaveSelection: () {},
          onDismissSelection: () {},
          onSeekProgress: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Use the key to locate the Positioned wrapping the progress bar.
    final positioned = find.ancestor(
      of: find.byType(ReaderProgressBar),
      matching: find.byType(Positioned),
    );
    final rect = await bounds(tester, positioned);
    expect(rect.bottom, 600);
  });

  testWidgets('applies left offset when the side panel is open', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderBottomOverlay(
          pendingQuote: 'hi',
          saveLabel: 'Save',
          chrome: false,
          sideOpen: true,
          askAndWide: false,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: 0.42,
          progressLabel: 'p 1/10',
          onSaveSelection: () {},
          onDismissSelection: () {},
          onSeekProgress: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final positioned = positionedWithKey(selectionConfirmKey);
    final rect = await bounds(tester, positioned);
    expect(rect.left, 240);
  });

  testWidgets('applies right offset when the AI panel is wide-open', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderBottomOverlay(
          pendingQuote: 'hi',
          saveLabel: 'Save',
          chrome: false,
          sideOpen: false,
          askAndWide: true,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: 0.42,
          progressLabel: 'p 1/10',
          onSaveSelection: () {},
          onDismissSelection: () {},
          onSeekProgress: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final positioned = positionedWithKey(selectionConfirmKey);
    final rect = await bounds(tester, positioned);
    expect(rect.right, 800 - 320);
  });

  testWidgets('whitespace-only quote does not surface the selection bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReaderBottomOverlay(
          pendingQuote: '   \n  ',
          saveLabel: 'Save',
          chrome: true,
          sideOpen: false,
          askAndWide: false,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: 0.42,
          progressLabel: 'p 1/10',
          onSaveSelection: () {},
          onDismissSelection: () {},
          onSeekProgress: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectionConfirmBar), findsNothing);
    expect(find.byType(ReaderProgressBar), findsOneWidget);
  });

  testWidgets('forwards save and dismiss callbacks', (tester) async {
    var saved = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      wrap(
        ReaderBottomOverlay(
          pendingQuote: 'hi',
          saveLabel: 'Save',
          chrome: false,
          sideOpen: false,
          askAndWide: false,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: 0.42,
          progressLabel: 'p 1/10',
          onSaveSelection: () => saved++,
          onDismissSelection: () => dismissed++,
          onSeekProgress: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.widget<SelectionConfirmBar>(
      find.byType(SelectionConfirmBar),
    );
    bar.onSave();
    bar.onDismiss();
    expect(saved, 1);
    expect(dismissed, 1);
  });

  testWidgets('forwards progress label and seek callbacks', (tester) async {
    var seek = -1.0;
    await tester.pumpWidget(
      wrap(
        ReaderBottomOverlay(
          pendingQuote: null,
          saveLabel: 'Save',
          chrome: true,
          sideOpen: false,
          askAndWide: false,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: 0.5,
          progressLabel: 'Section 3 / 12',
          onSaveSelection: () {},
          onDismissSelection: () {},
          onSeekProgress: (v) => seek = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Section 3 / 12'), findsOneWidget);
    final bar = tester.widget<ReaderProgressBar>(
      find.byType(ReaderProgressBar),
    );
    bar.onSeek(0.7);
    expect(seek, closeTo(0.7, 1e-9));
  });
}

// ignore: unused_element
const _annotatedQuoteKey =
    annotatedQuoteKey; // keep import alive if structure shifts
