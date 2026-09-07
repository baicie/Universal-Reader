import 'foliate_session.dart';
import 'reader_runtime.dart';
import '../features/library/annotation_store.dart';

/// Immutable snapshot of the document + foliate bridge state in `ReaderPage`.
///
/// Kept as a value object so the page can rebuild a single field with
/// `runtime = runtime.copyWith(...)` and so unit tests can drive lifecycle
/// transitions (`loading` → `loaded` → `failed`) without spinning up a widget.
class ReaderRuntime {
  const ReaderRuntime({
    this.loading = true,
    this.opened,
    this.tocItems = const [],
    this.body = '',
    this.fileBytes,
    this.progress = 0,
    this.notes = const [],
    this.pendingQuote,
    this.foliateSession,
    this.foliateFragment,
    this.foliateFragmentEpoch = 0,
    this.foliateScrollQuote,
    this.foliateScrollQuoteEpoch = 0,
    this.searchQuery = '',
    this.searchHits = const [],
  });

  final bool loading;
  final ReaderDocument? opened;
  final List<TocItem> tocItems;
  final String body;
  final List<int>? fileBytes;
  final double progress;
  final List<ReaderAnnotation> notes;
  final String? pendingQuote;
  final FoliateSession? foliateSession;
  final String? foliateFragment;
  final int foliateFragmentEpoch;
  final String? foliateScrollQuote;
  final int foliateScrollQuoteEpoch;
  final String searchQuery;
  final List<SearchResult> searchHits;

  ReaderRuntime copyWith({
    bool? loading,
    ReaderDocument? opened,
    List<TocItem>? tocItems,
    String? body,
    List<int>? fileBytes,
    double? progress,
    List<ReaderAnnotation>? notes,
    Object? pendingQuote = _sentinel,
    Object? foliateSession = _sentinel,
    Object? foliateFragment = _sentinel,
    int? foliateFragmentEpoch,
    Object? foliateScrollQuote = _sentinel,
    int? foliateScrollQuoteEpoch,
    String? searchQuery,
    List<SearchResult>? searchHits,
  }) {
    return ReaderRuntime(
      loading: loading ?? this.loading,
      opened: opened ?? this.opened,
      tocItems: tocItems ?? this.tocItems,
      body: body ?? this.body,
      fileBytes: fileBytes ?? this.fileBytes,
      progress: progress ?? this.progress,
      notes: notes ?? this.notes,
      pendingQuote: identical(pendingQuote, _sentinel)
          ? this.pendingQuote
          : pendingQuote as String?,
      foliateSession: identical(foliateSession, _sentinel)
          ? this.foliateSession
          : foliateSession as FoliateSession?,
      foliateFragment: identical(foliateFragment, _sentinel)
          ? this.foliateFragment
          : foliateFragment as String?,
      foliateFragmentEpoch: foliateFragmentEpoch ?? this.foliateFragmentEpoch,
      foliateScrollQuote: identical(foliateScrollQuote, _sentinel)
          ? this.foliateScrollQuote
          : foliateScrollQuote as String?,
      foliateScrollQuoteEpoch:
          foliateScrollQuoteEpoch ?? this.foliateScrollQuoteEpoch,
      searchQuery: searchQuery ?? this.searchQuery,
      searchHits: searchHits ?? this.searchHits,
    );
  }

  /// Transition into the loaded state with a freshly opened document.
  ReaderRuntime loaded({
    required ReaderDocument document,
    required String body,
    required List<TocItem> toc,
    required double progress,
    List<int>? fileBytes,
  }) {
    return ReaderRuntime(
      loading: false,
      opened: document,
      tocItems: toc,
      body: body,
      fileBytes: fileBytes,
      progress: progress,
      notes: notes,
      pendingQuote: pendingQuote,
      foliateSession: foliateSession,
      foliateFragment: foliateFragment,
      foliateFragmentEpoch: foliateFragmentEpoch,
      foliateScrollQuote: foliateScrollQuote,
      foliateScrollQuoteEpoch: foliateScrollQuoteEpoch,
      searchQuery: searchQuery,
      searchHits: searchHits,
    );
  }

  /// Transition out of loading into the empty/error state.
  ReaderRuntime failed() => ReaderRuntime(
        loading: false,
        notes: notes,
        pendingQuote: pendingQuote,
        foliateSession: foliateSession,
        foliateFragment: foliateFragment,
        foliateFragmentEpoch: foliateFragmentEpoch,
        foliateScrollQuote: foliateScrollQuote,
        foliateScrollQuoteEpoch: foliateScrollQuoteEpoch,
      );

  ReaderRuntime withNote(ReaderAnnotation note) =>
      copyWith(notes: [...notes, note]);

  ReaderRuntime withSearchHits(List<SearchResult> hits) =>
      copyWith(searchHits: hits);

  ReaderRuntime closeAllFoliate() => copyWith(
        foliateSession: null,
        foliateFragment: null,
        foliateFragmentEpoch: 0,
        foliateScrollQuote: null,
        foliateScrollQuoteEpoch: 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderRuntime &&
          other.loading == loading &&
          other.opened == opened &&
          other.tocItems == tocItems &&
          other.body == body &&
          other.fileBytes == fileBytes &&
          other.progress == progress &&
          other.notes == notes &&
          other.pendingQuote == pendingQuote &&
          other.foliateSession == foliateSession &&
          other.foliateFragment == foliateFragment &&
          other.foliateFragmentEpoch == foliateFragmentEpoch &&
          other.foliateScrollQuote == foliateScrollQuote &&
          other.foliateScrollQuoteEpoch == foliateScrollQuoteEpoch &&
          other.searchQuery == searchQuery &&
          other.searchHits == searchHits;

  @override
  int get hashCode => Object.hash(
        loading,
        opened,
        tocItems,
        body,
        fileBytes,
        progress,
        notes,
        pendingQuote,
        foliateSession,
        foliateFragment,
        foliateFragmentEpoch,
        foliateScrollQuote,
        foliateScrollQuoteEpoch,
        searchQuery,
        searchHits,
      );
}

const Object _sentinel = Object();
