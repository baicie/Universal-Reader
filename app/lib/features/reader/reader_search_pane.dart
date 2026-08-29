import 'package:flutter/material.dart';

import '../../core/reader_runtime.dart';
import '../../widgets/eyebrow.dart';

const searchPanelKey = Key('search-panel');
const readerSearchFieldKey = Key('reader-search-field');

class ReaderSearchPane extends StatefulWidget {
  const ReaderSearchPane({
    required this.title,
    required this.hint,
    required this.emptyLabel,
    required this.query,
    required this.hits,
    required this.onQuery,
    required this.onOpen,
    super.key,
  });

  final String title;
  final String hint;
  final String emptyLabel;
  final String query;
  final List<SearchResult> hits;
  final ValueChanged<String> onQuery;
  final ValueChanged<SearchResult> onOpen;

  @override
  State<ReaderSearchPane> createState() => _ReaderSearchPaneState();
}

class _ReaderSearchPaneState extends State<ReaderSearchPane> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(ReaderSearchPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final trimmed = widget.query.trim();
    return Column(
      key: searchPanelKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(widget.title),
        const SizedBox(height: 12),
        TextField(
          key: readerSearchFieldKey,
          controller: _controller,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            hintStyle: TextStyle(color: muted),
            border: const OutlineInputBorder(),
          ),
          onChanged: widget.onQuery,
        ),
        const SizedBox(height: 12),
        if (trimmed.isNotEmpty && widget.hits.isEmpty)
          Text(widget.emptyLabel, style: TextStyle(color: muted, height: 1.4)),
        for (var i = 0; i < widget.hits.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: InkWell(
              key: Key('search-hit-$i'),
              onTap: () => widget.onOpen(widget.hits[i]),
              child: Text(
                widget.hits[i].excerpt,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: ink, height: 1.4),
              ),
            ),
          ),
      ],
    );
  }
}
