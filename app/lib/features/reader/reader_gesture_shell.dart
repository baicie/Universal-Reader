import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hosts the page-level input wiring for `ReaderPage`:
///
/// * Keyboard arrow/page shortcuts that turn reflow (EPUB/HTML) pages.
/// * A focusable tap target that toggles chrome visibility, suppressed while a
///   text selection is pending so the selection-confirm bar can dismiss itself
///   without fighting the gesture.
///
/// Extracted so `ReaderPage.build` does not need to inline 50+ lines of
/// shortcut plumbing and the behaviour can be unit-tested in isolation.
class ReaderGestureShell extends StatelessWidget {
  const ReaderGestureShell({
    super.key,
    required this.child,
    required this.isReflowOpened,
    required this.hasPendingQuote,
    required this.onToggleChrome,
    required this.onTurnNext,
    required this.onTurnPrevious,
  });

  final Widget child;

  /// True when the currently-open document responds to keyboard page-turn
  /// shortcuts (HTML/EPUB). Other formats (PDF, comic) expose their own
  /// navigation controls and ignore these keys.
  final bool isReflowOpened;

  /// True while a text selection is being confirmed. Suppresses chrome toggle
  /// so the tap does not flicker the overlay while the user reads their
  /// highlight.
  final bool hasPendingQuote;

  final VoidCallback onToggleChrome;
  final VoidCallback onTurnNext;
  final VoidCallback onTurnPrevious;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (isReflowOpened) ...{
          const SingleActivator(LogicalKeyboardKey.arrowRight): onTurnNext,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): onTurnPrevious,
          const SingleActivator(LogicalKeyboardKey.pageDown): onTurnNext,
          const SingleActivator(LogicalKeyboardKey.pageUp): onTurnPrevious,
        },
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          onTap: () {
            if (hasPendingQuote) return;
            onToggleChrome();
          },
          child: child,
        ),
      ),
    );
  }
}
