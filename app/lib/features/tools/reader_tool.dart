import '../../core/models.dart';
import '../../core/reader_runtime.dart';

enum ReaderToolKind { summarize, explain, translate, ask }

class ReaderToolRequest {
  const ReaderToolRequest({
    required this.kind,
    this.question,
    this.range,
    this.locator,
  });

  final ReaderToolKind kind;
  final String? question;
  final DocumentRange? range;
  final Locator? locator;
}

class ReaderToolResult {
  const ReaderToolResult({
    required this.text,
    this.locatorLabel,
    this.unavailable = false,
  });

  const ReaderToolResult.unavailable(String message)
    : text = message,
      locatorLabel = null,
      unavailable = true;

  final String text;
  final String? locatorLabel;
  final bool unavailable;
}

abstract interface class ReaderTool {
  String get id;
  String get label;
  bool get enabled;

  Future<ReaderToolResult> run({
    required ReaderDocument document,
    required ReaderToolRequest request,
  });
}
