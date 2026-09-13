import 'package:app/features/reader/reader_gesture_shell.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap({
    bool isReflowOpened = false,
    bool hasPendingQuote = false,
    VoidCallback? onToggleChrome,
    VoidCallback? onTurnNext,
    VoidCallback? onTurnPrevious,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: ReaderGestureShell(
          isReflowOpened: isReflowOpened,
          hasPendingQuote: hasPendingQuote,
          onToggleChrome: onToggleChrome ?? () {},
          onTurnNext: onTurnNext ?? () {},
          onTurnPrevious: onTurnPrevious ?? () {},
          child: const SizedBox(
            width: 200,
            height: 200,
            child: ColoredBox(color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
  }

  testWidgets('routes arrowRight to onTurnNext when reflow is opened', (
    tester,
  ) async {
    var next = 0;
    await tester.pumpWidget(
      wrap(isReflowOpened: true, onTurnNext: () => next++),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(next, 1);
  });

  testWidgets('routes pageDown to onTurnNext when reflow is opened', (
    tester,
  ) async {
    var next = 0;
    await tester.pumpWidget(
      wrap(isReflowOpened: true, onTurnNext: () => next++),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    expect(next, 1);
  });

  testWidgets('routes arrowLeft to onTurnPrevious when reflow is opened', (
    tester,
  ) async {
    var prev = 0;
    await tester.pumpWidget(
      wrap(isReflowOpened: true, onTurnPrevious: () => prev++),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(prev, 1);
  });

  testWidgets('does not bind keys when reflow is closed', (tester) async {
    var next = 0;
    await tester.pumpWidget(wrap(onTurnNext: () => next++));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(next, 0);
  });

  testWidgets('tap toggles chrome when no selection is pending', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(wrap(onToggleChrome: () => toggles++));
    await tester.tap(find.byType(ReaderGestureShell));
    expect(toggles, 1);
  });

  testWidgets('tap is suppressed while a selection is pending', (tester) async {
    var toggles = 0;
    await tester.pumpWidget(
      wrap(hasPendingQuote: true, onToggleChrome: () => toggles++),
    );
    await tester.tap(find.byType(ReaderGestureShell));
    expect(toggles, 0);
  });
}
