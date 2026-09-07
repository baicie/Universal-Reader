import 'package:app/core/reader_state.dart';
import 'package:app/features/reader/reader_chrome_overlay.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget _wrap({
    required ReaderRuntime runtime,
    bool ask = false,
    bool chrome = true,
    bool sideOpen = false,
  }) {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: SizedBox(
            height: 800,
            width: 400,
            child: ReaderChromeOverlay(
              runtime: runtime,
              chrome: chrome,
              ask: ask,
              wide: false,
              paper: const Color(0xFFFFFFFF),
              muted: const Color(0xFF888888),
              ink: const Color(0xFF000000),
              sideOpen: sideOpen,
              progress: 0.4,
              progressLabel: '§2/5',
              formatLabel: 'EPUB',
              currentIndex: 1,
              onJump: (_) async {},
              onSaveSelection: () {},
              onDismissSelection: () {},
              onSeekProgress: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the progress bar when nothing is pending', (tester) async {
    const runtime = ReaderRuntime(loading: false);
    await tester.pumpWidget(_wrap(runtime: runtime));
    await tester.pump();
    expect(find.text('§2/5'), findsOneWidget);
  });

  testWidgets('progress bar fades out when chrome is hidden', (tester) async {
    const runtime = ReaderRuntime(loading: false);
    await tester.pumpWidget(_wrap(runtime: runtime, chrome: false));
    await tester.pump();
    expect(find.text('§2/5'), findsNothing);
  });

  testWidgets('selection bar replaces progress bar when pendingQuote is set',
      (tester) async {
    const runtime = ReaderRuntime(pendingQuote: 'a selected sentence');
    await tester.pumpWidget(_wrap(runtime: runtime));
    await tester.pump();
    expect(find.text('§2/5'), findsNothing);
    expect(find.text('Save selection'), findsOneWidget);
  });
}
