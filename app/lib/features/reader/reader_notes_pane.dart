import 'package:flutter/material.dart';

import '../../widgets/eyebrow.dart';
import '../library/annotation_store.dart';
import 'reader_notes.dart';

const notesPanelKey = Key('notes-panel');

class ReaderNotesPane extends StatelessWidget {
  const ReaderNotesPane({
    required this.title,
    required this.emptyLabel,
    required this.deleteLabel,
    required this.notes,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final String title;
  final String emptyLabel;
  final String deleteLabel;
  final List<ReaderAnnotation> notes;
  final ValueChanged<ReaderAnnotation> onOpen;
  final ValueChanged<ReaderAnnotation> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      key: notesPanelKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(title),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          Text(emptyLabel, style: TextStyle(color: muted, height: 1.4)),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onOpen(note),
                    child: Text(
                      noteListLabel(note),
                      style: TextStyle(color: ink, height: 1.4),
                    ),
                  ),
                ),
                IconButton(
                  key: Key('delete-note-${note.id}'),
                  tooltip: deleteLabel,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onDelete(note),
                  icon: Icon(Icons.close, size: 18, color: muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
