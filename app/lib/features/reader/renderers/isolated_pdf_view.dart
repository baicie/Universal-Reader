import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/pdf_document.dart';
import 'renderer_binding.dart';

class IsolatedPdfView extends StatefulWidget {
  const IsolatedPdfView({
    required this.document,
    required this.bytes,
    required this.fallback,
    required this.zoom,
    super.key,
  });

  final PdfReaderDocument document;
  final List<int>? bytes;
  final Widget fallback;
  final double zoom;

  @override
  State<IsolatedPdfView> createState() => _IsolatedPdfViewState();
}

class _IsolatedPdfViewState extends State<IsolatedPdfView> {
  final PdfViewerController _controller = PdfViewerController();

  @override
  void didUpdateWidget(IsolatedPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom != widget.zoom) {
      _applyNativeZoom();
    }
  }

  void _applyNativeZoom() {
    if (!_controller.isReady) return;
    _controller.setZoom(
      _controller.centerPosition,
      widget.zoom,
      duration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.bytes;
    if (!useNativeVisualRenderer() || data == null || data.isEmpty) {
      return SizedBox.expand(
        key: const Key('pdf-surface'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
          child: Transform.scale(
            key: const Key('pdf-zoom'),
            alignment: Alignment.topCenter,
            scale: widget.zoom,
            child: widget.fallback,
          ),
        ),
      );
    }
    return SizedBox.expand(
      key: const Key('pdf-surface'),
      child: PdfViewer.data(
        Uint8List.fromList(data),
        sourceName: widget.document.metadata.id,
        initialPageNumber: widget.document.chapterIndex + 1,
        controller: _controller,
        params: PdfViewerParams(
          onViewerReady: (_, controller) {
            controller.setZoom(
              controller.centerPosition,
              widget.zoom,
              duration: Duration.zero,
            );
          },
        ),
      ),
    );
  }
}
