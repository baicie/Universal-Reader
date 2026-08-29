import 'package:flutter/material.dart';

import '../../widgets/eyebrow.dart';
import '../library/annotation_store.dart';

const bookmarksPanelKey = Key('bookmarks-panel');
const addBookmarkButtonKey = Key('add-bookmark');

class ReaderBookmarksPane extends StatelessWidget {
  const ReaderBookmarksPane({
    required this.title,
    required this.emptyLabel,
    required this.bookmarks,
    required this.onOpen,
    super.key,
  });

  final String title;
  final String emptyLabel;
  final List<ReaderAnnotation> bookmarks;
  final ValueChanged<ReaderAnnotation> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      key: bookmarksPanelKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(title),
        const SizedBox(height: 12),
        if (bookmarks.isEmpty)
          Text(emptyLabel, style: TextStyle(color: muted, height: 1.4)),
        for (final mark in bookmarks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: InkWell(
              onTap: () => onOpen(mark),
              child: Text(
                mark.locatorLabel,
                style: TextStyle(color: ink, height: 1.4),
              ),
            ),
          ),
      ],
    );
  }
}
