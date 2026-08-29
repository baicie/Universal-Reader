import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

class LibraryCover extends ConsumerWidget {
  const LibraryCover({
    required this.metadata,
    required this.fallback,
    this.width,
    this.height,
    super.key,
  });

  final DocumentMetadata metadata;
  final Widget fallback;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<int>?>(
      future: ref.read(libraryProvider).readCover(metadata.id),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            Uint8List.fromList(bytes),
            width: width,
            height: height,
            fit: BoxFit.cover,
          );
        }
        return fallback;
      },
    );
  }
}
