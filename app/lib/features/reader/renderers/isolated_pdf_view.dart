import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/pdf_document.dart';
import 'renderer_binding.dart';

class IsolatedPdfView extends StatelessWidget {
  const IsolatedPdfView({
    required this.document,
    required this.bytes,
    required this.fallback,
    super.key,
  });

  final PdfReaderDocument document;
  final List<int>? bytes;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (!useNativeVisualRenderer() || data == null || data.isEmpty) {
      return fallback;
    }
    return PdfViewer.data(
      Uint8List.fromList(data),
      sourceName: document.metadata.id,
      initialPageNumber: document.chapterIndex + 1,
    );
  }
}
