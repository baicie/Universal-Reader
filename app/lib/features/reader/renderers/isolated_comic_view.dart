import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/comic_document.dart';
import '../../../core/comic_layout.dart';

class IsolatedComicView extends StatefulWidget {
  const IsolatedComicView({
    required this.document,
    required this.layout,
    required this.direction,
    this.onTurn,
    this.onToggleChrome,
    super.key,
  });

  final ComicReaderDocument document;
  final ComicLayout layout;
  final ComicReadDirection direction;
  final ValueChanged<int>? onTurn;
  final VoidCallback? onToggleChrome;

  @override
  State<IsolatedComicView> createState() => _IsolatedComicViewState();
}

class _IsolatedComicViewState extends State<IsolatedComicView> {
  Offset? _tap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('comic-surface'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _tap = details.localPosition,
      onTap: _handleTap,
      child: SizedBox.expand(
        child: widget.layout == ComicLayout.vertical
            ? _verticalPages()
            : _pagedSpread(),
      ),
    );
  }

  void _handleTap() {
    final tap = _tap;
    final box = context.findRenderObject();
    if (tap == null || box is! RenderBox) return;
    final action = comicTapAction(tap.dx, box.size.width, widget.direction);
    switch (action) {
      case ComicTapAction.next:
        final next = comicNextPageIndex(
          pageIndex: widget.document.pageIndex,
          pageCount: widget.document.pages.length,
          layout: widget.layout,
        );
        if (next != widget.document.pageIndex) widget.onTurn?.call(next);
      case ComicTapAction.previous:
        final previous = comicPreviousPageIndex(
          pageIndex: widget.document.pageIndex,
          pageCount: widget.document.pages.length,
          layout: widget.layout,
        );
        if (previous != widget.document.pageIndex) {
          widget.onTurn?.call(previous);
        }
      case ComicTapAction.chrome:
        widget.onToggleChrome?.call();
    }
  }

  Widget _pagedSpread() {
    final spread = comicSpread(
      pages: widget.document.pages,
      pageIndex: widget.document.pageIndex,
      layout: widget.layout,
      direction: widget.direction,
    );
    if (widget.layout == ComicLayout.double &&
        spread.left != null &&
        spread.right != null) {
      return Row(
        children: [
          Expanded(
            child: _pageImage(spread.left!, const Key('comic-page-left')),
          ),
          Expanded(
            child: _pageImage(spread.right!, const Key('comic-page-right')),
          ),
        ],
      );
    }
    if (widget.layout == ComicLayout.double) {
      if (spread.left != null) {
        return _pageImage(spread.left!, const Key('comic-page-left'));
      }
      if (spread.right != null) {
        return _pageImage(spread.right!, const Key('comic-page-right'));
      }
      return const SizedBox.expand();
    }
    return _pageImage(widget.document.currentPage, const Key('comic-page'));
  }

  Widget _verticalPages() {
    return SingleChildScrollView(
      key: const Key('comic-vertical'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          for (final page in widget.document.pages)
            _pageImage(page, Key('comic-page-${page.name}')),
        ],
      ),
    );
  }

  Widget _pageImage(ComicPage page, Key key) {
    return Image.memory(
      Uint8List.fromList(page.bytes),
      key: key,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      width: double.infinity,
    );
  }
}
