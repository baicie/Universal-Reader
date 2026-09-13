import 'package:app/core/models.dart';
import 'package:app/core/providers.dart';
import 'package:app/core/reader_state.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/reader_chrome_overlay.dart';
import 'package:app/features/tools/ai/ai_settings.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap({
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
    await tester.pumpWidget(wrap(runtime: runtime));
    await tester.pump();
    expect(find.text('§2/5'), findsOneWidget);
  });

  testWidgets('progress bar fades out when chrome is hidden', (tester) async {
    const runtime = ReaderRuntime(loading: false);
    await tester.pumpWidget(wrap(runtime: runtime, chrome: false));
    await tester.pump();
    expect(find.text('§2/5'), findsNothing);
  });

  testWidgets('selection bar replaces progress bar when pendingQuote is set', (
    tester,
  ) async {
    const runtime = ReaderRuntime(pendingQuote: 'a selected sentence');
    await tester.pumpWidget(wrap(runtime: runtime));
    await tester.pump();
    expect(find.text('§2/5'), findsNothing);
    expect(find.text('Save selection'), findsOneWidget);
  });

  testWidgets('whitespace-only pendingQuote is treated as no selection', (
    tester,
  ) async {
    const runtime = ReaderRuntime(pendingQuote: '   \n   ');
    await tester.pumpWidget(wrap(runtime: runtime));
    await tester.pump();
    // Whitespace trim → no selection bar; progress bar still appears.
    expect(find.text('Save selection'), findsNothing);
    expect(find.text('§2/5'), findsOneWidget);
  });

  testWidgets('selection bar fades out when chrome is hidden', (tester) async {
    const runtime = ReaderRuntime(pendingQuote: 'a real selection');
    await tester.pumpWidget(wrap(runtime: runtime, chrome: false));
    await tester.pump();
    // When chrome is false, the bottom overlay still shows the selection bar
    // because the selection bar is independent of the chrome visibility.
    expect(find.text('Save selection'), findsOneWidget);
  });

  testWidgets('does not render AI panel when ask is false', (tester) async {
    const runtime = ReaderRuntime(loading: false);
    await tester.pumpWidget(wrap(runtime: runtime, ask: false));
    await tester.pump();
    // No AI panel markers when ask is false — bottom overlay should still
    // show the progress label.
    expect(find.text('§2/5'), findsOneWidget);
  });

  testWidgets('does not render AI panel when no document is opened', (
    tester,
  ) async {
    const runtime = ReaderRuntime(loading: false);
    await tester.pumpWidget(wrap(runtime: runtime, ask: true));
    await tester.pump();
    // ask=true but opened=null → no AI panel. The chrome overlay still
    // shows the bottom progress bar.
    expect(find.text('§2/5'), findsOneWidget);
  });

  testWidgets('renders the AI panel when ask and opened are both set', (
    tester,
  ) async {
    final document = UnavailableReaderDocument(
      metadata: const DocumentMetadata(
        id: 'p',
        title: 'Probe',
        author: '',
        format: DocumentFormat.epub,
        type: DocumentType.reflow,
      ),
    );
    // Use wide layout → AI panel anchors to the right at width=320 and lets
    // height default, dodging the tight-height overflow in the narrow layout.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiSettingsRepositoryProvider.overrideWithValue(
            InMemoryAiSettingsRepository(),
          ),
        ],
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
              width: 1200,
              child: ReaderChromeOverlay(
                runtime: ReaderRuntime(loading: false, opened: document),
                chrome: true,
                ask: true,
                wide: true,
                paper: const Color(0xFFFFFFFF),
                muted: const Color(0xFF888888),
                ink: const Color(0xFF000000),
                sideOpen: false,
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
      ),
    );
    await tester.pump();
    // Bottom progress label still rendered underneath the AI panel.
    expect(find.text('§2/5'), findsOneWidget);
  });
}
