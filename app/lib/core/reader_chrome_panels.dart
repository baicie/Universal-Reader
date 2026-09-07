/// Side-panel toggles shared between the reader AppBar buttons and the side
/// panel visibility logic. Stored as an immutable value so a single
/// `setState` flips every panel that needs to change at once and prevents
/// one panel's flag from drifting out of sync with the others.
class ReaderChromePanels {
  const ReaderChromePanels({
    this.toc = false,
    this.bookmarks = false,
    this.showNotes = false,
    this.showSearch = false,
  });

  final bool toc;
  final bool bookmarks;
  final bool showNotes;
  final bool showSearch;

  bool get anyOpen => toc || bookmarks || showNotes || showSearch;

  ReaderChromePanels toggle(PanelKind kind) {
    switch (kind) {
      case PanelKind.toc:
        return ReaderChromePanels(
          toc: !toc,
          bookmarks: bookmarks,
          showNotes: showNotes,
          showSearch: showSearch,
        );
      case PanelKind.bookmarks:
        return ReaderChromePanels(
          toc: toc,
          bookmarks: !bookmarks,
          showNotes: showNotes,
          showSearch: showSearch,
        );
      case PanelKind.notes:
        return ReaderChromePanels(
          toc: toc,
          bookmarks: bookmarks,
          showNotes: !showNotes,
          showSearch: showSearch,
        );
      case PanelKind.search:
        return ReaderChromePanels(
          toc: toc,
          bookmarks: bookmarks,
          showNotes: showNotes,
          showSearch: !showSearch,
        );
    }
  }

  ReaderChromePanels closeAll() => const ReaderChromePanels();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderChromePanels &&
          other.toc == toc &&
          other.bookmarks == bookmarks &&
          other.showNotes == showNotes &&
          other.showSearch == showSearch;

  @override
  int get hashCode => Object.hash(toc, bookmarks, showNotes, showSearch);
}

enum PanelKind { toc, bookmarks, notes, search }
