import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/comic_document.dart';

class IsolatedComicView extends StatelessWidget {
  const IsolatedComicView({required this.document, super.key});

  final ComicReaderDocument document;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      Uint8List.fromList(document.currentPage.bytes),
      key: const Key('comic-page'),
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}
