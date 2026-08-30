import '../../core/locator_codec.dart';
import '../../core/models.dart';
import '../../core/reflow_nav.dart';
import '../library/annotation_store.dart';

class NoteJump {
  const NoteJump({this.locator, this.scrollQuote});

  final Locator? locator;
  final String? scrollQuote;
}

String noteListLabel(ReaderAnnotation note) {
  final quote = note.quote.trim();
  if (quote.isNotEmpty) return quote;
  final body = note.note.trim();
  if (body.isNotEmpty) return body;
  return note.locatorLabel;
}

NoteJump noteJump(ReaderAnnotation note) {
  return NoteJump(
    locator: decodeLocator(note.locatorLabel),
    scrollQuote: reflowScrollQuote(note.quote),
  );
}
