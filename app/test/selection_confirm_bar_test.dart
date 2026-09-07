import 'package:app/features/reader/selection_confirm_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  required String quote,
  required String saveLabel,
  int saveTaps = 0,
  int dismissTaps = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SelectionConfirmBar(
          quote: quote,
          saveLabel: saveLabel,
          onSave: () {
            saveCalls++;
          },
          onDismiss: () {
            dismissCalls++;
          },
        ),
      ),
    ),
  );
}

int saveCalls = 0;
int dismissCalls = 0;

void main() {
  setUp(() {
    saveCalls = 0;
    dismissCalls = 0;
  });

  group('SelectionConfirmBar', () {
    testWidgets('exposes the bar via selectionConfirmKey', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionConfirmBar(
              quote: 'hello',
              saveLabel: 'Save',
              onSave: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(selectionConfirmKey), findsOneWidget);
    });

    testWidgets('renders the trimmed quote', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionConfirmBar(
              quote: '  hello world  ',
              saveLabel: 'Save',
              onSave: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(find.text('hello world'), findsOneWidget);
    });

    testWidgets('renders the saveLabel on the TextButton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionConfirmBar(
              quote: 'hello',
              saveLabel: '保存',
              onSave: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(find.widgetWithText(TextButton, '保存'), findsOneWidget);
    });

    testWidgets('an empty quote renders as empty without padding the UI', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionConfirmBar(
              quote: '   ',
              saveLabel: 'Save',
              onSave: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      // The bar still renders (presence key), with an empty visible quote.
      expect(find.byKey(selectionConfirmKey), findsOneWidget);
      expect(find.text(''), findsWidgets);
    });

    testWidgets('tapping the save button calls onSave', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionConfirmBar(
              quote: 'hello',
              saveLabel: 'Save',
              onSave: () {
                saveCalls += 1;
              },
              onDismiss: () {
                dismissCalls += 1;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      expect(saveCalls, 1);
      expect(dismissCalls, 0);
    });

    testWidgets('tapping the close button calls onDismiss', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionConfirmBar(
              quote: 'hello',
              saveLabel: 'Save',
              onSave: () {
                saveCalls += 1;
              },
              onDismiss: () {
                dismissCalls += 1;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close));
      expect(dismissCalls, 1);
      expect(saveCalls, 0);
    });

    testWidgets('close button uses MaterialLocalizations tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          home: Scaffold(
            body: SelectionConfirmBar(
              quote: 'hello',
              saveLabel: 'Save',
              onSave: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      final tooltip = MaterialLocalizations.of(
        tester.element(find.byType(SelectionConfirmBar)),
      ).closeButtonTooltip;
      expect(find.byTooltip(tooltip), findsOneWidget);
    });
  });
}
