import 'package:flutter/material.dart';

import '../../core/annotated_text.dart';
import '../library/annotation_store.dart';

typedef ReaderSelectionCallback = void Function(String quote);

/// Renders a vertical list of plain-text paragraphs with note highlights
/// and a single selection sink.
class ReaderAnnotatedBody extends StatelessWidget {
  const ReaderAnnotatedBody({
    super.key,
    required this.paragraphs,
    required this.style,
    required this.notes,
    required this.highlightKey,
    required this.onSelectionChanged,
    this.gap = const SizedBox(height: 22),
  });

  final List<String> paragraphs;
  final TextStyle style;
  final List<ReaderAnnotation> notes;
  final Key? highlightKey;
  final ReaderSelectionCallback onSelectionChanged;
  final Widget gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) gap,
          _AnnotatedParagraph(
            text: paragraphs[i],
            style: style,
            notes: notes,
            highlightKey: highlightKey,
            onSelectionChanged: onSelectionChanged,
          ),
        ],
      ],
    );
  }
}

class _AnnotatedParagraph extends StatelessWidget {
  const _AnnotatedParagraph({
    required this.text,
    required this.style,
    required this.notes,
    required this.highlightKey,
    required this.onSelectionChanged,
  });

  final String text;
  final TextStyle style;
  final List<ReaderAnnotation> notes;
  final Key? highlightKey;
  final ReaderSelectionCallback onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final spans = annotatePlainText(text, notes, style: style);
    final highlighted = spans.any(
      (span) => span is TextSpan && span.style?.backgroundColor != null,
    );
    return SelectableText.rich(
      TextSpan(children: spans, style: style),
      key: highlighted ? highlightKey : null,
      onSelectionChanged: (selection, _) {
        if (!selection.isValid || selection.isCollapsed) return;
        final start = selection.start;
        final end = selection.end;
        if (start < 0 || end > text.length || start >= end) return;
        final quote = text.substring(start, end);
        if (quote.trim().isEmpty) return;
        onSelectionChanged(quote);
      },
    );
  }
}
