import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/reader_state.dart';
import '../../l10n/l10n.dart';
import '../tools/reader_ai_panel.dart';
import 'reader_bottom_overlay.dart';

/// Hosts the AI panel and the bottom selection/progress bar that sit on top of
/// the reading surface. Extracted from `ReaderPage` to keep that widget focused
/// on reading state and layout primitives; both children here are pure chrome.
class ReaderChromeOverlay extends ConsumerWidget {
  const ReaderChromeOverlay({
    super.key,
    required this.runtime,
    required this.chrome,
    required this.ask,
    required this.wide,
    required this.paper,
    required this.muted,
    required this.ink,
    required this.sideOpen,
    required this.progress,
    required this.progressLabel,
    required this.formatLabel,
    required this.currentIndex,
    required this.onJump,
    required this.onSaveSelection,
    required this.onDismissSelection,
    required this.onSeekProgress,
  });

  final ReaderRuntime runtime;
  final bool chrome;
  final bool ask;
  final bool wide;
  final Color paper;
  final Color muted;
  final Color ink;
  final bool sideOpen;
  final double progress;
  final String progressLabel;
  final String formatLabel;
  final int currentIndex;
  final Future<void> Function(Locator)? onJump;
  final VoidCallback onSaveSelection;
  final VoidCallback onDismissSelection;
  final ValueChanged<double> onSeekProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ask && runtime.opened != null)
          Positioned(
            top: wide ? 0 : null,
            left: wide ? null : 0,
            right: 0,
            bottom: chrome ? 72 : 0,
            width: wide ? 320 : null,
            height: wide ? null : MediaQuery.sizeOf(context).height * 0.45,
            child: ReaderAiPanel(
              document: runtime.opened!,
              settings: ref.watch(aiSettingsProvider).settings,
              onJump: onJump,
            ),
          ),
        ReaderBottomOverlay(
          pendingQuote: runtime.pendingQuote,
          saveLabel: l10n.saveSelection,
          chrome: chrome,
          sideOpen: sideOpen,
          askAndWide: ask && wide,
          paper: paper,
          muted: muted,
          ink: ink,
          progress: progress,
          progressLabel: progressLabel,
          onSaveSelection: onSaveSelection,
          onDismissSelection: onDismissSelection,
          onSeekProgress: onSeekProgress,
        ),
      ],
    );
  }
}
