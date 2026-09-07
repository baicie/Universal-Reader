import 'package:flutter/material.dart';

import 'reader_progress_bar.dart';
import 'selection_confirm_bar.dart';

/// Stacks the selection-confirm and progress-bar widgets at the bottom of the
/// reader page. The two are mutually exclusive — selection wins while a
/// selection is pending; otherwise the progress bar shows when [chrome] is
/// visible.
class ReaderBottomOverlay extends StatelessWidget {
  const ReaderBottomOverlay({
    super.key,
    required this.pendingQuote,
    required this.saveLabel,
    required this.chrome,
    required this.sideOpen,
    required this.askAndWide,
    required this.paper,
    required this.muted,
    required this.ink,
    required this.progress,
    required this.progressLabel,
    required this.onSaveSelection,
    required this.onDismissSelection,
    required this.onSeekProgress,
  });

  /// The text the user has highlighted, or `null` if no selection is pending.
  /// Whitespace-only values are treated as no selection.
  final String? pendingQuote;
  final String saveLabel;

  /// Whether the reader chrome (top app bar / progress bar) is visible.
  final bool chrome;

  /// Whether the side panel (TOC / bookmarks / notes / search) is open.
  final bool sideOpen;

  /// Whether the AI panel is docked to the right side on a wide layout.
  final bool askAndWide;
  final Color paper;
  final Color muted;
  final Color ink;
  final double progress;
  final String progressLabel;
  final VoidCallback onSaveSelection;
  final VoidCallback onDismissSelection;
  final ValueChanged<double> onSeekProgress;

  static const double _chromeHeight = 72;
  static const double _sidePanelWidth = 240;
  static const double _aiPanelWidth = 320;

  @override
  Widget build(BuildContext context) {
    final trimmed = pendingQuote?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return Positioned(
        left: sideOpen ? _sidePanelWidth : 0,
        right: askAndWide ? _aiPanelWidth : 0,
        bottom: chrome ? _chromeHeight : 0,
        child: GestureDetector(
          onTap: () {},
          child: SelectionConfirmBar(
            quote: pendingQuote!,
            saveLabel: saveLabel,
            onSave: onSaveSelection,
            onDismiss: onDismissSelection,
          ),
        ),
      );
    }
    if (!chrome) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: sideOpen ? _sidePanelWidth : 0,
      right: askAndWide ? _aiPanelWidth : 0,
      bottom: 0,
      child: ReaderProgressBar(
        progress: progress,
        label: progressLabel,
        paper: paper,
        muted: muted,
        ink: ink,
        onSeek: onSeekProgress,
      ),
    );
  }
}
